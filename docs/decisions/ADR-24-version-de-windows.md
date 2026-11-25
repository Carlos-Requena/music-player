---
adr: ADR-24
titulo: Windows con el mismo código, WebView2 para iniciar sesión y un instalador por usuario con mpv, yt-dlp y deno dentro
estado: ampliada por ADR-25
fecha: 2026-11-22
areas: [sesion, reproduccion, plugins, resolucion]
---

# ADR-24 · Windows con el mismo código, WebView2 para iniciar sesión y un instalador por usuario con mpv, yt-dlp y deno dentro

- **Estado:** Ampliada por [ADR-25](ADR-25-yt-dlp-residente-en-windows.md) (yt-dlp residente con un Python embebido).
- **Registrada:** 2026-11-22
- **Ámbito:** [sesion](../areas/sesion.md), [reproduccion](../areas/reproduccion.md), [plugins](../areas/plugins.md), [resolucion](../areas/resolucion.md)

## Decisión

- **Un solo código** para macOS, Linux y Windows: lo propio de Windows va en bloques
  `#[cfg(windows)]` y en `src/tuberia.rs` (tuberías con nombre y el «job» que cierra a los hijos).
  mpv sigue en un proceso aparte ([ADR-02](ADR-02-mpv-en-proceso-aparte.md)), ahora por
  `\\.\pipe\musicplayer-mpv-<pid>`; Discord, por `\\.\pipe\discord-ipc-N`.
- **Inicio de sesión con WebView2** (el motor de Edge que trae Windows), en el binario aparte
  `musicplayer-login.exe` del crate `login/` ([ADR-07](ADR-07-inicio-de-sesion-en-proceso-aparte.md)),
  en modo InPrivate y consciente del DPI por monitor. Lo eligió el propietario.
- **Instalador `.exe` de Inno Setup**, por usuario (sin administrador, en
  `%LOCALAPPDATA%\Programs\Reproductor`), con Qt (windeployqt), mpv, yt-dlp y deno dentro; ffmpeg,
  solo con `-ConFfmpeg`. Lo crea `scripts/crear-instalador-windows.ps1`. Lo eligió el propietario.

## Alternativas descartadas

- **Qt WebEngine para iniciar sesión, como en Linux**: unos 200 MB más en el instalador para usarlo
  una vez; WebView2 ya está en Windows 10 y 11. La duda del propietario fue la nitidez: WebView2 se
  ve tan nítido como Edge si el proceso declara el DPI por monitor, y así se hace.
- **Solo importar del navegador**: Chrome, Edge y Brave cifran sus cookies en Windows de forma que
  yt-dlp no siempre las lee; solo Firefox sería fiable.
- **Una carpeta con acceso directo, o compilar en GitHub Actions**: el propietario prefirió un
  instalador con desinstalador.
- **Pedir al usuario que instale mpv, yt-dlp y deno** (winget o scoop): un paso más y versiones
  que no controla el instalador. `audio::search_path` los busca primero junto al ejecutable y luego
  en el PATH, así que uno instalado aparte sigue valiendo.
- **Manejadores síncronos para las tuberías**: Windows pone en fila las operaciones de un mismo
  archivo síncrono, y la lectura que espera los eventos de mpv bloquearía cada orden (razonado, de
  la documentación de Win32; no se llegó a probar).

## Motivo

El propietario pidió una versión para Windows. Las piezas de las otras plataformas ya funcionan en
Windows (Qt, cxx-qt, mpv, yt-dlp, souvlaki); solo cambian la comunicación entre procesos, el cierre
de los hijos, la búsqueda de programas y la ventana de inicio de sesión.

## Consecuencias

- Todo proceso auxiliar se lanza con `audio::command` (sin ventana de consola en Windows).
- Un cambio en la comunicación con mpv o Discord se piensa también para la tubería con nombre.
- En Windows no hay yt-dlp residente ([ADR-08](ADR-08-yt-dlp-residente.md)): yt-dlp es un `.exe`
  sin Python a la vista; la vía rápida ([ADR-03](ADR-03-via-rapida-y-yt-dlp-de-respaldo.md)) cubre
  la mayoría de pistas.
- Compilar para Windows exige un PC con Windows (o una máquina virtual): desde macOS solo se
  comprueba con `cargo check --target x86_64-pc-windows-msvc` lo que no depende de Qt.
