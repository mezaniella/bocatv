<h1 align="center">BocaTV 💙💛</h1>

<p align="center"><b>CleanYourTV con el tema de Boca.</b><br>
Tu Android TV sin publicidad, más rápida con 1 GB de RAM y vestida de azul y oro.</p>

<p align="center">
  <img src="themes/boca/screenshot.jpg" alt="El tema de Boca en una Android TV: inicio azul con la Bombonera de fondo, saludo y frase en amarillo, dock azul cruzado por una franja amarilla" width="800">
</p>

<p align="center">
  <a href="README.md"><b>English</b></a> ·
  <a href="themes/boca/README.md">El tema de Boca</a> ·
  <a href="tools/windows/README.md">Herramientas de Windows</a> ·
  <a href="https://github.com/Gathin23/cleanyourtv">Proyecto original</a>
</p>

## Por qué este fork

Empezó con una tele Android lenta en casa: publicidad antes de llegar a Netflix, apps que nadie pidió,
telemetría y 1 GB de RAM que nunca alcanzaba. [CleanYourTV](https://github.com/Gathin23/cleanyourtv)
resolvió la publicidad y las apps de más; este fork es lo que vino después:

- **Hacer todo desde Windows**, con scripts que muestran qué van a cambiar antes de cambiarlo y dejan
  la vuelta atrás de cada paso.
- **Que una tele de 1 GB ande rápido**, no solo que esté limpia: apps de streaming que dejan de correr
  en segundo plano y un inicio que vuelve al instante.
- **Que se vea de Boca**: azul y oro, la franja amarilla cruzando el dock como la de la camiseta, la
  Bombonera detrás de las apps y una frase en castellano rioplatense debajo del reloj.

Todo quedó genérico: las herramientas sirven para cualquier Android TV, las opciones de los temas para
cualquier color, y el tema de Boca es un tema más, que podés usar o no.

Este fork mantiene todo lo del [proyecto original](https://github.com/Gathin23/cleanyourtv): limpiar
cualquier Android TV o Google TV por Wi-Fi, sin root ni cables, y reemplazar el inicio lleno de
publicidad por un launcher liviano estilo Apple TV.

## Cómo funciona

Las teles con Android TV tienen el mismo puente de depuración (ADB) que los celulares. Activás la
depuración en las opciones de desarrollador, autorizás tu computadora una vez, y el resto son
herramientas estándar de Android:

1. **Respaldo** de la lista de apps y los ajustes.
2. **Desactivación** de la telemetría, la publicidad, las filas de contenido y las apps de fábrica con
   `pm disable-user`. No se desinstala nada, así que todo se puede revertir.
3. **Instalación** de un launcher chico y nativo como pantalla de inicio.

**Sin root, sin cable, sin desinstalar nada y con reversión de cada paso.**

## Qué agrega este fork

| Qué | Dónde |
|---|---|
| Herramientas para Windows: diagnóstico, optimización con simulación y script de reversión, apps de streaming sin segundo plano, chequeos antes y después del launcher, inspector de apps que se reactivan solas | [`tools/windows/`](tools/windows/README.md) |
| Paleta de colores por tema: acento, tarjetas, dock, franja en el dock, brillo cinemático del color del tema | [`themes/README.md`](themes/README.md) |
| Frases debajo del reloj, que rotan por día, en cada vuelta al inicio o cada N minutos | [`themes/README.md`](themes/README.md) |
| Dock más bajo, sin la fila de abajo asomando (`dock_bottom_room`) | [`themes/README.md`](themes/README.md) |
| Tema azul y amarillo con fondos de ejemplo | [`themes/boca/`](themes/boca/README.md) |
| Herramienta para adaptar tus fotos como fondo | [`tools/prepare_wallpapers.py`](tools/prepare_wallpapers.py) |
| Launcher en español rioplatense (voseo) y 45 textos que no tenían traducción | `launcher/app/src/main/res/values-es-rAR/` |
| Guía de recuperación, de lo más leve al restablecimiento de fábrica | [`docs/RECOVERY.md`](docs/RECOVERY.md) |

## Antes de empezar

En la tele: **Ajustes → Preferencias del dispositivo → Información → apretá OK siete veces sobre
"Compilación"**. Después, en **Opciones de desarrollador**, activá **Depuración por USB**. En la mayoría
de las teles eso abre el puerto **5555** en la red, que no cambia y no pide código.

En la PC necesitás las [platform-tools de Android](https://developer.android.com/tools/releases/platform-tools)
(adb) y, para compilar el launcher, JDK 17 y el SDK de Android con `platforms;android-34` y
`build-tools;34.0.0`.

Todos los comandos se corren desde la carpeta del repo. Reemplazá `192.168.1.50` por la IP de tu tele
(Ajustes → Red).

## Paso a paso en Windows

```powershell
# 1. Foto inicial (no cambia nada): apps, memoria, ajustes
powershell -ExecutionPolicy Bypass -File tools\windows\diagnose.ps1 -TvHost 192.168.1.50

# 2. Tu lista: copiá la plantilla y sumá las apps de fábrica de tu modelo (examples\<tv>\debloat.txt)
mkdir local -Force; copy tools\windows\optimize.example.psd1 local\optimize.psd1

# 3. Simulación: muestra qué haría, sin tocar nada
powershell -ExecutionPolicy Bypass -File tools\windows\optimize.ps1 -TvHost 192.168.1.50

# 4. Aplicar (genera backup\reports\revert-<fecha>.ps1 para deshacerlo)
powershell -ExecutionPolicy Bypass -File tools\windows\optimize.ps1 -TvHost 192.168.1.50 -Apply -Include All -Reboot

# 5. Comparar con la foto inicial
powershell -ExecutionPolicy Bypass -File tools\windows\diagnose.ps1 -TvHost 192.168.1.50
```

`optimize.ps1` desactiva apps, quita del perfil las de sistema que algún servicio reactiva, deja a las
apps de streaming sin segundo plano (no arrancan solas al prender la tele ni quedan ocupando memoria,
y al abrirlas funcionan normal), pone las animaciones en 0,5x, apaga los reportes de errores y los
escaneos en segundo plano, y opcionalmente activa un DNS privado que bloquea publicidad. Todo lo que
escriben estos scripts queda en `backup\`, que git ignora: ahí hay números de serie y nombres de
dispositivos.

Detalle de cada script y de lo aprendido en el camino: [tools/windows/README.md](tools/windows/README.md).

### El launcher

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows\verify-environment.ps1                     # JDK 17, SDK 34
powershell -ExecutionPolicy Bypass -File tools\windows\prepare-launcher.ps1 -TvHost 192.168.1.50  # chequeos previos
powershell -ExecutionPolicy Bypass -File launcher\build-and-install.ps1 -TvHost 192.168.1.50      # compila e instala
powershell -ExecutionPolicy Bypass -File tools\windows\verify-launcher.ps1 -TvHost 192.168.1.50   # verifica
```

El script de instalación pone el launcher nuevo como inicio, comprueba que arranque y recién después
desactiva el original. Si algo falla, deja el original como estaba.

Para el launcher en español rioplatense (la tele puede seguir en español de España):

```powershell
tools\venv\Scripts\python.exe -I tools\tv.py "cmd locale set-app-locales com.gathin.tvhome --locales es-AR"
```

## Temas

Un tema es una carpeta con un `config.json` y, opcionalmente, fondos de pantalla. Se sube sin
recompilar:

```powershell
powershell -ExecutionPolicy Bypass -File tools\theme.ps1 -TvHost 192.168.1.50 themes\boca
powershell -ExecutionPolicy Bypass -File tools\theme.ps1 -TvHost 192.168.1.50 -Reset    # volver al original
```

Opciones nuevas de este fork (todas las demás, en [themes/README.md](themes/README.md)):

| Opción | Qué hace |
|---|---|
| `accent_color` | Color del foco, de los botones de arriba al enfocarlos, del saludo y de la frase |
| `tile_color`, `dock_color` | Fondo de las tarjetas sin imagen y banda del dock |
| `dock_stripe` | Franja del color de acento que cruza la pantalla a la altura del dock |
| `cinematic_tint: "theme"` | La parte de arriba brilla siempre del color del tema, no del de cada app |
| `cinematic_artwork: false` | Sin la portada difuminada de la app, para que se vea el fondo de pantalla |
| `dock_bottom_room` | Margen debajo del dock; con `0`, la fila siguiente queda oculta hasta que bajás |
| `home_message`, `home_messages` | Una frase, o varias, debajo del reloj |
| `home_message_rotation` | `daily` (una por día) o `each_home` (una distinta cada vez que volvés al inicio) |
| `home_message_minutes` | Cambiar la frase cada N minutos, incluso con el inicio en pantalla |

Si un ajuste del tema no se aplica, en la tele mantené OK sobre **Ajustes → Ajustes del launcher →
Seguir el tema**: lo que se elige en la tele tiene prioridad hasta que tocás esa opción.

### Tema azul y amarillo

[`themes/boca`](themes/boca/README.md): fondo azul noche, foco y saludo amarillos, dock azul cruzado
por una franja amarilla, la parte de arriba siempre en azul, frases en castellano rioplatense y seis
fondos de ejemplo que rotan cada 30 minutos.

**Los fondos son de ejemplo:** sumá, cambiá o borrá los que quieras de `themes/boca/wallpapers/`.
Para usar tus fotos, no hace falta editarlas a mano:

```powershell
python tools\prepare_wallpapers.py themes\boca\originals themes\boca\wallpapers
```

Recorta cada foto a 16:9, la lleva a 1280×720, oscurece la zona del reloj y la frase lo justo para esa
foto, la comprime por debajo de 300 KB, le pone un nombre que el launcher acepta y descarta las que son
más chicas que la pantalla. Las originales en `originals/` no se suben (git las ignora).

**Tus cosas personales** (tus frases, tus fotos, tu lista de apps) van en `local/`, que git ignora:
copiá el tema a `local\themes\boca`, cambialo ahí y subí esa carpeta con `tools\theme.ps1`.

## Si algo sale mal

Nada de esto flashea ni rootea la tele: un restablecimiento de fábrica deshace todo. La guía completa,
de lo más leve a lo más grave (sin inicio, ciclo de reinicios, red Wi-Fi borrada, ADB perdido, modo
recuperación), está en [docs/RECOVERY.md](docs/RECOVERY.md). Lo esencial:

- **Sin pantalla de inicio:** `adb shell pm enable --user 0 com.google.android.tvlauncher` (Google TV:
  `com.google.android.apps.tv.launcherx`), o desde el engranaje del control: Apps → Ver todas → Apps
  del sistema → el inicio original → Habilitar.
- **Revertir la optimización:** el `backup\reports\revert-<fecha>.ps1` que generó `optimize.ps1`.
- **Volver al launcher original:** `tools\restore.ps1` (ver el README en inglés).

## Al terminar

Apagá la **Depuración por USB** y la **Depuración inalámbrica** en las opciones de desarrollador: el
puerto 5555 le da acceso total a la tele a cualquiera conectado a tu red. Comprobalo desde la PC:
`Test-NetConnection <ip de la tele> -Port 5555` tiene que dar `False`. El launcher y todos los cambios
siguen funcionando sin la depuración.

## Contacto

| Para | Dónde |
|---|---|
| **Este fork**: herramientas de Windows, tema de Boca, colores de los temas y frases | [Issues](https://github.com/mezaniella/bocatv/issues) · [@mezaniella](https://github.com/mezaniella) · mezaniella [arroba] hotmail [punto] com |
| **El launcher original y los modelos de tele** | [Discussions del proyecto original](https://github.com/Gathin23/cleanyourtv/discussions) |
| **Problemas de seguridad** | En privado, por la [pestaña Security del original](https://github.com/Gathin23/cleanyourtv/security) |

## Créditos y licencia

Proyecto original: [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) y sus colaboradores.
Licencia MIT, ver [`LICENSE`](LICENSE). La tipografía Outfit está bajo la SIL Open Font License. Los
fondos de ejemplo del tema azul y amarillo pertenecen a sus dueños (ver
[themes/boca/README.md](themes/boca/README.md)).
