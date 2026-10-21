package com.gathin.tvhome;

import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;

/**
 * The theme's own colours (accent_color, tile_color, dock_color in config.json). The single place
 * that decides them: views ask the palette instead of hard-coding their own. A colour left at 0
 * keeps the built-in look, so a theme without these keys looks exactly as before. A festive skin
 * keeps priority over the accent (see MainActivity).
 */
final class ThemePalette {
    static final ThemePalette DEFAULT = new ThemePalette(0, 0, 0, false, false);

    /** Pill text turns this dark on a focused pill (pill_text.xml), so the accent must stay light enough to read on. */
    private static final int PILL_IDLE_TOP = 0x2EFFFFFF, PILL_IDLE_BOTTOM = 0x14FFFFFF, PILL_IDLE_STROKE = 0x38FFFFFF;
    /** Reorder mode keeps its own blue, as in pill_bg.xml, so it never looks like plain focus. */
    private static final int PILL_ACTIVATED_FILL = 0x596EC1FF, PILL_ACTIVATED_STROKE = 0xFF6EC1FF;

    /** Focus glow, focused pills, greeting and home message; 0 for the built-in white. */
    final int accent;
    /** Tile background behind apps without a banner; 0 for the built-in dark grey. */
    final int tile;
    /** The dock row's band; 0 for the built-in dark band. */
    final int dock;
    /** cinematic_tint "theme": the shelf glows in the dock colour, over greyscale artwork, instead of each app's colour. */
    final boolean themeTint;
    /** dock_stripe: a full-width accent stripe across the dock row, like the band on a football shirt. */
    final boolean dockStripe;

    ThemePalette(int accent, int tile, int dock, boolean themeTint, boolean dockStripe) {
        this.accent = accent;
        this.tile = tile;
        this.dock = dock;
        this.themeTint = themeTint && dock != 0;
        this.dockStripe = dockStripe && accent != 0;
    }

    /**
     * The colour the cinematic shelf and the glow use for an app: its own colour normally, the dock
     * colour lifted a little towards white with cinematic_tint "theme" (a dark navy glow would barely show).
     */
    int shelfColor(int appColor) {
        return themeTint ? lift(dock) : appColor;
    }

    /** Saturation for the shelf's artwork: none with the theme tint, so app colours never fight the theme. */
    float artworkSaturation() {
        return themeTint ? 0f : HeroArt.SATURATION;
    }

    /**
     * The clock screensaver's glow colours, in turn: the dock colour (lifted like the shelf's) and the
     * accent. Null when the theme sets neither, so ClockScene keeps its own palette.
     */
    int[] clockGlow() {
        if (dock == 0 && accent == 0) return null;
        if (dock == 0) return new int[]{accent};
        int blue = lift(dock);
        return accent == 0 ? new int[]{blue} : new int[]{blue, accent};
    }

    /** A colour a quarter of the way to white: a dark theme colour would barely glow on a dark screen. */
    private static int lift(int color) {
        int r = (color >> 16) & 0xFF, g = (color >> 8) & 0xFF, b = color & 0xFF;
        r += (255 - r) / 4;
        g += (255 - g) / 4;
        b += (255 - b) / 4;
        return 0xFF000000 | (r << 16) | (g << 8) | b;
    }

    /** The dock stripe's colour: the accent, nearly opaque. */
    int stripeColor() {
        return accentWithAlpha(0xF2, 0);
    }

    boolean hasAccent() {
        return accent != 0;
    }

    /** The accent at the given alpha (0-255), or {@code fallback} when the theme sets no accent. */
    int accentWithAlpha(int alpha, int fallback) {
        return accent == 0 ? fallback : (alpha << 24) | (accent & 0xFFFFFF);
    }

    /** The dock band colour at the alpha the band uses, or {@code fallback} when the theme sets none. */
    int dockBand(boolean translucent, int fallback) {
        if (dock == 0) return fallback;
        return (translucent ? 0x8C000000 : 0xFF000000) | (dock & 0xFFFFFF);
    }

    /**
     * A top-bar pill background like pill_bg.xml, with the focused state in the accent. A new instance
     * per view: drawables built here are not shared, so one pill's state never shows on another.
     */
    Drawable pillBackground(float density) {
        float radius = 21f * density;
        StateListDrawable states = new StateListDrawable();
        states.addState(new int[]{android.R.attr.state_focused}, rounded(radius, accentWithAlpha(0xF5, 0xF5FFFFFF), 0, 0));
        states.addState(new int[]{android.R.attr.state_activated},
                rounded(radius, PILL_ACTIVATED_FILL, PILL_ACTIVATED_STROKE, Math.round(1.5f * density)));
        GradientDrawable idle = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{PILL_IDLE_TOP, PILL_IDLE_BOTTOM});
        idle.setCornerRadius(radius);
        idle.setStroke(Math.max(1, Math.round(density)), PILL_IDLE_STROKE);
        states.addState(new int[0], idle);
        return states;
    }

    private static GradientDrawable rounded(float radius, int fill, int stroke, int strokeWidth) {
        GradientDrawable d = new GradientDrawable();
        d.setShape(GradientDrawable.RECTANGLE);
        d.setCornerRadius(radius);
        d.setColor(fill);
        if (strokeWidth > 0) d.setStroke(strokeWidth, stroke);
        return d;
    }
}
