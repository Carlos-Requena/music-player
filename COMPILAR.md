# Compilar e instalar

Cómo compilar el reproductor y dejarlo instalado como una aplicación más, en **macOS** y en
**CachyOS** (o cualquier Arch Linux).

En resumen:

| Sistema | Dependencias | Compilar e instalar |
|---|---|---|
| macOS | `brew install rust qtbase qtdeclarative qtshadertools mpv yt-dlp deno` | `scripts/crear-app-macos.sh` |
| CachyOS | `scripts/instalar-linux.sh --dependencias` | `scripts/instalar-linux.sh` |

## Qué necesita

| Pieza | Para qué | Cuándo |
|---|---|---|
| Rust (cargo) 1.87 o superior | compilar el núcleo | al compilar |
| Compilador de C++ (Xcode CLT en macOS, `base-devel` en Arch) | el puente Rust–Qt | al compilar |
| Qt 6.8 o superior: base, declarative, shadertools | la interfaz | al compilar y al usar |
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
brew install rust qtbase qtdeclarative qtshadertools mpv yt-dlp deno
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

### 3. Permisos

- **Iniciar sesión con Chrome, Brave o Edge**: macOS pedirá permiso para leer la clave del
  navegador; pulsa **Permitir**.
- **Iniciar sesión con Safari**: Ajustes del Sistema › Privacidad y seguridad › **Acceso total
  al disco** › activa **Reproductor** (o tu terminal si lo lanzas con `cargo run`). Después
  cierra la app del todo y vuelve a abrirla.

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
`base-devel rust qt6-base qt6-declarative qt6-shadertools qt6-wayland mpv yt-dlp deno`.

Si prefieres hacerlo a mano:

```bash
sudo pacman -S --needed base-devel rust qt6-base qt6-declarative qt6-shadertools qt6-wayland mpv yt-dlp deno
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
| `Could not find qmake` / Qt no encontrado | Instala Qt 6 (ver arriba). Si tienes varios, indica cuál: `QMAKE=/ruta/a/qmake6 cargo build --release` (en Arch: `/usr/bin/qmake6`; en Homebrew: `/opt/homebrew/bin/qmake6`). |
| Falla al enlazar con `QtQuick` o `QtQml` | Falta `qtdeclarative` (macOS) o `qt6-declarative` (Arch). |
| `error: linker cc not found` (Linux) | `sudo pacman -S base-devel`. |
| La app arranca pero dice «No se pudo iniciar el motor de audio (mpv)» | Instala `mpv`. |
| Ninguna canción suena | Instala o actualiza `yt-dlp` y `deno`. YouTube cambia a menudo: `brew upgrade yt-dlp` o `sudo pacman -Syu yt-dlp`. |
| (Linux, Wayland) la ventana sale sin desenfoque o borrosa | Instala `qt6-wayland`. |
