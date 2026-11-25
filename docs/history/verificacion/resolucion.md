# Historial de verificación · Resolución del audio y arranque instantáneo

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/resolucion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-22 · yt-dlp residente en Windows con Python embebido (ADR-25)

- **Fallo:** con calidad Premium y sesión, cada pista tardaba en Windows 7–8 s: `yt-dlp.exe` en un proceso por pista (2,7 s solo en arrancar). El propietario eligió llevar el residente a Windows.
- **Cambio:** `daemon::interpreter` usa en Windows `python\python.exe` con `yt-dlp.zip` al lado; `scripts/crear-instalador-windows.ps1` descarga el Python embebido de python.org y el yt-dlp en script y reescribe el `._pth`; `--probe resolve` pasa a medir solo el residente (antes respondía la vía rápida).
- **Cómo:** Windows 11, release; Python 3.15.2 embebido y yt-dlp 2026.10.26 en script copiados a `target\release\python\`; `MUSICPLAYER_SILENT=1 target\release\musicplayer.exe --probe resolve kJQP7kiw5Fk,JGwWNGJdvx8,fJ9rUzIMcZQ,9bZkp7q19f0` sin sesión; memoria del `python.exe` muestreada mientras resolvía; `cargo build --release` sin avisos.
- **Resultado:** 4762, 2445, 2507 y 2413 ms (la primera arranca el residente), frente a 7,2–7,8 s de `yt-dlp.exe`; ~77 MB en uso (60 MB privados); no queda ningún `python.exe` al terminar. Una prueba previa con un script de PowerShell 5 colgaba: enviaba un BOM delante del JSON (la app no lo hace).
- **No verificado:** con sesión (`web_music` y cookies); el script del instalador entero (descarga y `._pth`) ni la app instalada con la ventana abierta.

## 2026-11-22 · sin yt-dlp residente en Windows

- **Cómo:** `cargo build --release` y `cargo test` en macOS (M4 Pro); prueba `--autoplay` como en [reproduccion](reproduccion.md).
- **Resultado:** sin cambios en macOS (`sonando true`, sin error).
- **No verificado:** tiempos de la vía rápida y de yt-dlp en Windows.

## 2026-11-17 · El clic no espera a las precargas (rama `perf/letra`)

- **Cambio:** `resolve` (clic, pasar de pista) no cuenta en `MAX_WORKERS` y reintenta; las
  precargas (`resolve_with(…, false)`) esperan turno y no reintentan. Las listas de álbumes se
  precargan como las pistas, solo la última (`hint_list`). El ratón precarga a los 250 ms y no si
  sale antes. Fuera `resolver::settle`, que no usaba nadie.
- **Verificado:** `cargo test`; reproducción con `--play` y con un álbum de Lomos usando
  `MUSICPLAYER_DEBUG_AUDIO`.
- **No verificado:** la resolución real (YouTube pedía sesión): ni el tiempo de clic con dos
  precargas en marcha ni la precarga al pasar el ratón.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
