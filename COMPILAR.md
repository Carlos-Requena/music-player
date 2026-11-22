# Compilar e instalar

Cómo compilar el reproductor y dejarlo instalado como una aplicación más, en **macOS**, en
**CachyOS** (o cualquier Arch Linux) y en **Windows** 10 o 11.

En resumen:

| Sistema | Dependencias | Compilar e instalar |
|---|---|---|
| macOS | `brew install rust qtbase qtdeclarative qtmultimedia qtshadertools mpv yt-dlp deno ffmpeg` | `scripts/crear-app-macos.sh` |
| CachyOS | `scripts/instalar-linux.sh --dependencias` | `scripts/instalar-linux.sh` |
| Windows | Rust, Visual Studio Build Tools, Qt para MSVC e Inno Setup ([abajo](#windows)) | `scripts\crear-instalador-windows.ps1` |

## Qué necesita

| Pieza | Para qué | Cuándo |
|---|---|---|
| Rust (cargo) 1.87 o superior | compilar el núcleo | al compilar |
| Compilador de C++ (Xcode CLT en macOS, `base-devel` en Arch, Visual Studio Build Tools en Windows) | el puente Rust–Qt | al compilar |
| Qt 6.9 o superior (probado con 6.12): base, declarative, shadertools | la interfaz | al compilar y al usar |
| mpv | reproducir el audio | al usar |
| yt-dlp + deno (o Node.js) | obtener el audio de YouTube | al usar |

La interfaz QML va **dentro del binario**: no hay que copiar archivos aparte.

---

## macOS

### 1. Dependencias

Con [Homebrew](https://brew.sh) instalado:

```bash
xcode-select --install
```

```bash
brew install rust qtbase qtdeclarative qtmultimedia qtshadertools mpv yt-dlp deno ffmpeg
```

(Si ya tienes Rust con `rustup`, quita `rust` de la lista.)

### 2. Compilar y crear la app

Desde la carpeta del proyecto:

```bash
scripts/crear-app-macos.sh
```

El script:

1. compila en modo release (la primera vez tarda un par de minutos, luego unos 15 s);
2. crea `Reproductor.app` con su icono;
3. la firma con una firma local (Apple Silicon no abre apps sin firmar);
4. la copia a `/Applications`.

Después ábrela desde Launchpad o Spotlight («Reproductor de música»).

Opciones:

| Opción | Efecto |
|---|---|
| `--independiente` | Copia Qt dentro de la app (~130 MB en vez de ~7 MB). Úsala si no quieres que una actualización de Qt en Homebrew afecte a la app. Puede mostrar avisos `Cannot resolve rpath … QtSvg`: son inofensivos. |
| `--sin-instalar` | Deja la app en `target/Reproductor.app` sin copiarla. |
| `--destino ~/Applications` | Instala en otra carpeta. |

Sin `--independiente`, la app usa el Qt de Homebrew: tras un `brew upgrade` grande de Qt,
vuelve a ejecutar el script.

### 3. Iniciar sesión

Opciones › Cuenta › **Iniciar sesión** abre una ventana con la página de Google: entra con tu
cuenta y listo, sin permisos especiales.

Solo si prefieres **importar la sesión de tu navegador** («Importar desde el navegador»), macOS
exige un permiso, porque protege los datos de los navegadores:

1. Ajustes del Sistema › Privacidad y seguridad › **Acceso total al disco** › activa
   **Reproductor** (o tu terminal: Terminal, iTerm, VS Code… si lo lanzas con `cargo run`).
   La app tiene un botón que abre ese panel.
2. Cierra la app (o la terminal) del todo y vuelve a abrirla.
3. Con Chrome, Brave o Edge, macOS preguntará además por la clave del navegador: pulsa
   **Permitir**.

Cada vez que vuelves a crear la app con el script, su firma local cambia y macOS puede olvidar
el permiso: si el inicio de sesión vuelve a fallar tras actualizar, desactiva y activa
«Reproductor» en Acceso total al disco.

### Actualizar

```bash
git pull
```

```bash
scripts/crear-app-macos.sh
```

### Desinstalar

```bash
rm -rf /Applications/Reproductor.app
```

Las preferencias y la sesión están en `~/Library/Application Support/musicplayer` y la caché en
`~/Library/Caches/musicplayer`; bórralas si quieres empezar de cero.

---

## CachyOS / Arch Linux

### 1. Dependencias

```bash
scripts/instalar-linux.sh --dependencias
```

Instala con `pacman` (te pedirá la contraseña):
`base-devel rust qt6-base qt6-declarative qt6-multimedia qt6-shadertools qt6-wayland qt6-webengine mpv yt-dlp deno ffmpeg`.
(`qt6-webengine` es para la ventana de inicio de sesión; sin él la app funciona igual y puedes
importar la sesión del navegador.)

Si prefieres hacerlo a mano:

```bash
sudo pacman -S --needed base-devel rust qt6-base qt6-declarative qt6-multimedia qt6-shadertools qt6-wayland qt6-webengine mpv yt-dlp deno ffmpeg
```

(Si ya usas `rustup`, quita `rust` de la lista.)

### 2. Compilar e instalar

```bash
scripts/instalar-linux.sh
```

El script compila en modo release y lo instala **para tu usuario**, sin `sudo`:

| Qué | Dónde |
|---|---|
| Programa | `~/.local/bin/musicplayer` |
| Ventana de inicio de sesión (con `qt6-webengine`) | `~/.local/bin/musicplayer-login` |
| Entrada del menú | `~/.local/share/applications/musicplayer.desktop` |
| Icono | `~/.local/share/icons/hicolor/scalable/apps/musicplayer.svg` |

Búscalo en el menú de aplicaciones como «Reproductor de música», o ejecuta `musicplayer` (si
`~/.local/bin` está en tu `PATH`; en CachyOS suele estarlo).

### Actualizar

```bash
git pull
```

```bash
scripts/instalar-linux.sh
```

### Desinstalar

```bash
scripts/instalar-linux.sh --desinstalar
```

Las preferencias y la sesión están en `~/.config/musicplayer` y la caché en
`~/.cache/musicplayer`.

> Linux todavía no se ha probado en una máquina real: si algo falla, el mensaje de error de
> `cargo build` o de la terminal al ejecutar `musicplayer` es lo que hay que mirar.

---

## Windows

Se compila **en un PC con Windows** 10 (1809 o posterior) u 11, de 64 bits: desde el Mac no se
puede (el puente con Qt necesita el Qt de Windows). El resultado es un instalador `.exe` que lleva
dentro todo lo que hace falta para usarla: Qt, mpv, yt-dlp y deno.

### 1. Herramientas para compilar

En una terminal de PowerShell:

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools --override "--quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

```powershell
winget install Rustlang.Rustup JRSoftware.InnoSetup
```

Y **Qt 6.9 o superior para MSVC** (la interfaz usa `RectangularShadow`, que llegó en 6.9; en el Mac se usa 6.12), con el [instalador de Qt](https://www.qt.io/download-qt-installer-oss)
(cuenta de Qt gratuita): marca *Qt 6.x › MSVC 2022 64-bit*, *Qt Multimedia* y *Qt Shader Tools*. Sin
cuenta, con [aqtinstall](https://github.com/miurahr/aqtinstall) (necesita Python):

```powershell
pip install aqtinstall
```

```powershell
aqt install-qt windows desktop 6.12.0 win64_msvc2022_64 -m qtmultimedia qtshadertools -O C:\Qt
```

Si `aqt` no encuentra esa versión, `aqt list-qt windows desktop` muestra las que hay y
`aqt list-qt windows desktop --arch 6.12.0` el nombre de la variante MSVC. El script encuentra Qt
solo si está en `C:\Qt\6.x\msvc20xx_64` (usa la versión más nueva); si no, indica dónde está
`qmake6.exe` con la variable `QMAKE`.

### 2. Crear el instalador

Desde la carpeta del proyecto, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\crear-instalador-windows.ps1
```

El script:

1. compila en modo release el reproductor y `musicplayer-login.exe` (la ventana de inicio de
   sesión con WebView2);
2. copia Qt junto al programa con `windeployqt` (solo los módulos que usa la interfaz);
3. descarga mpv ([shinchiro](https://github.com/shinchiro/mpv-winbuild-cmake/releases)), yt-dlp y
   deno de sus publicaciones oficiales en GitHub (se guardan en `target\windows\descargas` y no se
   vuelven a bajar);
4. crea `target\windows\Reproductor-<versión>-instalador.exe` con Inno Setup.

| Opción | Efecto |
|---|---|
| `-Instalar` | Abre el instalador al terminar. |
| `-ConFfmpeg` | Añade ffmpeg (~200 MB más). Solo lo usa la carátula animada de Apple Music, desactivada por defecto. |
| `-SinDescargas -Dependencias C:\ruta` | No descarga nada: copia `mpv.exe`, `yt-dlp.exe` y `deno.exe` (y `ffmpeg.exe`, `ffprobe.exe` con `-ConFfmpeg`) de esa carpeta. |

### 3. Instalar y usar

Abre el instalador: se instala **para tu usuario**, sin pedir permisos de administrador, en
`%LOCALAPPDATA%\Programs\Reproductor`, con su entrada en el menú Inicio («Reproductor de
música»). Para actualizar, crea un instalador nuevo y ábrelo encima.

Opciones › Cuenta › **Iniciar sesión** abre una ventana con WebView2 (el motor de Edge que ya trae
Windows). Importar del navegador funciona con **Firefox**; Chrome, Edge y Brave cifran sus cookies
de forma que yt-dlp no siempre puede leerlas.

### Desinstalar

Configuración › Aplicaciones › «Reproductor de música» › Desinstalar. Las preferencias y la sesión
siguen en `%APPDATA%\musicplayer` y la caché en `%LOCALAPPDATA%\musicplayer`; bórralas si
quieres empezar de cero.

> Windows todavía no se ha probado en una máquina real. Si algo falla, compila en modo de
> depuración (`cargo build`) y ejecuta `target\debug\musicplayer.exe` desde PowerShell: esa
> versión deja ver los mensajes de error en la terminal (la de release no abre consola).

---

## Discord

La app ya incluye el Application ID de su aplicación de Discord: se conecta sola en cuanto
Discord está abierto, sin configurar nada. Para usar otra aplicación de Discord (otro nombre
tras «Escuchando»), créala en
[discord.com/developers/applications](https://discord.com/developers/applications) y compila
con su ID, o pégalo en Opciones › Plugins › Discord:

```bash
MUSICPLAYER_DISCORD_ID=123456789012345678 scripts/crear-app-macos.sh
```

## Compilar a mano (cualquier sistema)

```bash
cargo build --release
```

```bash
./target/release/musicplayer
```

`cargo run --release` hace las dos cosas. Para desarrollar, `cargo run` (sin `--release`)
compila más rápido pero la app va más lenta.

## Problemas al compilar

| Error | Solución |
|---|---|
| (Windows) `Could not find qmake` o `link.exe` no encontrado | Abre la terminal «Developer PowerShell for VS 2022» o indica `QMAKE=C:\Qt\6.12.0\msvc2022_64\bin\qmake6.exe`. |
| `Could not find qmake` / Qt no encontrado | Instala Qt 6 (ver arriba). Si tienes varios, indica cuál: `QMAKE=/ruta/a/qmake6 cargo build --release` (en Arch: `/usr/bin/qmake6`; en Homebrew: `/opt/homebrew/bin/qmake6`). |
| Falla al enlazar con `QtQuick` o `QtQml` | Falta `qtdeclarative` (macOS) o `qt6-declarative` (Arch). |
| `error: linker cc not found` (Linux) | `sudo pacman -S base-devel`. |
| La app arranca pero dice «No se pudo iniciar el motor de audio (mpv)» | Instala `mpv`. |
| Ninguna canción suena | Instala o actualiza `yt-dlp` y `deno`. YouTube cambia a menudo: `brew upgrade yt-dlp` o `sudo pacman -Syu yt-dlp`. |
| (Linux, Wayland) la ventana sale sin desenfoque o borrosa | Instala `qt6-wayland`. |
