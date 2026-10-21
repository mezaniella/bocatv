"""Turn your own photos into launcher wallpapers.

Crops each picture to 16:9, scales it to the launcher's wallpaper size, darkens the area behind the
greeting, clock and home message (top left) just as much as that picture needs so white and gold text
stays readable, and saves a JPEG under 300 KB with a file name the launcher accepts. Pictures smaller
than the target size are skipped instead of being blown up.

    python tools/prepare_wallpapers.py <source folder> <wallpapers folder> [--size 1280x720]

Needs Pillow (pip install pillow). Run it again after adding photos: existing outputs are rewritten.
"""
import argparse
import re
import sys
import unicodedata
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps

MAX_BYTES = 300_000
TEXT_LUMA = 0.16          # target brightness (0-1) of the bright parts behind the text
TEXT_PERCENTILE = 0.85    # measure the bright parts, not the average: half-blue, half-gold flags fool a mean
EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")


def slug(name):
    """'Bombonera de noche' -> 'bombonera_de_noche': letters, digits, _ . - only."""
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9._-]+", "_", s).strip("_") or "wallpaper"


def crop_16_9(img, width, height):
    w, h = img.size
    target = width / height
    if w / h > target:
        nw = round(h * target)
        left = (w - nw) // 2
        return img.crop((left, 0, left + nw, h))
    nh = round(w / target)
    top = (h - nh) // 2
    return img.crop((0, top, w, top + nh))


def text_area_mask(width, height):
    """Darker at the top left (greeting, clock, message) and along the bottom edge; centre and right untouched."""
    mask = Image.new("L", (width, height))
    px = mask.load()
    for y in range(height):
        ty = y / height
        top = max(0.0, 1 - ty / 0.40)
        bottom = max(0.0, (ty - 0.85) / 0.15)
        for x in range(width):
            left = max(0.0, 1 - (x / width) / 0.55)
            px[x, y] = int(255 * min(1.0, max(top * (0.55 + 0.45 * left), bottom * 0.6)))
    return mask


def bright_level(img, width, height):
    """Brightness (0-1) of the brighter parts of the text area."""
    region = img.crop((0, 0, int(width * 0.55), int(height * 0.45))).convert("L")
    hist = region.histogram()
    total, acc = sum(hist), 0
    for level, count in enumerate(hist):
        acc += count
        if acc >= total * TEXT_PERCENTILE:
            return level / 255
    return 1.0


def process(src, dst, width, height, mask):
    img = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
    img = crop_16_9(img, width, height).resize((width, height), Image.LANCZOS)
    level = bright_level(img, width, height)
    strength = min(0.92, max(0.35, 1 - TEXT_LUMA / max(level, 0.01)))
    img = Image.composite(Image.new("RGB", (width, height)), img, mask.point(lambda v: int(v * strength)))
    for quality in (84, 80, 76, 72, 68):
        img.save(dst, "JPEG", quality=quality, optimize=True, progressive=True)
        if dst.stat().st_size <= MAX_BYTES:
            break
    return strength, dst.stat().st_size


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("source", type=Path)
    parser.add_argument("wallpapers", type=Path)
    parser.add_argument("--size", default="1280x720",
                        help="wallpaper size, WIDTHxHEIGHT; 1280x720 matches most 1 GB TVs' UI (default)")
    args = parser.parse_args()
    width, height = (int(v) for v in args.size.lower().split("x"))
    if not args.source.is_dir():
        sys.exit(f"no such folder: {args.source}")
    args.wallpapers.mkdir(parents=True, exist_ok=True)
    mask = text_area_mask(width, height)
    done = 0
    for src in sorted(p for p in args.source.iterdir() if p.suffix.lower() in EXTENSIONS):
        with Image.open(src) as probe:
            w, h = ImageOps.exif_transpose(probe).size
        if w < width or h < height:
            print(f"skip   {src.name}: {w}x{h}, smaller than {width}x{height}")
            continue
        dst = args.wallpapers / f"{slug(src.stem)}.jpg"
        strength, size = process(src, dst, width, height, mask)
        print(f"ok     {src.name} -> {dst.name}  text area darkened {strength:.0%}, {size // 1024} KB")
        done += 1
    print(f"{done} wallpaper(s) in {args.wallpapers}")


if __name__ == "__main__":
    main()
