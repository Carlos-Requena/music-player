# Historial de verificación · Resolución del audio y arranque instantáneo

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/resolucion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-27 · otra edición con el título traducido

- **Fallo:** «終焉のフィナーレ» (`Ui7L0VZqAT0`, edición japonesa de Yu-Peng Chen) no está
  disponible por ninguna vía, ni con la sesión y yt-dlp 2026.11.23; su edición internacional se
  llama «Caelestinum Finale Termini» (`VqtScyk2C5A`) y `same_song` la descartaba por el título.
- **Cambio:** `same_song` acepta un título distinto con el mismo artista principal y la duración
  a ±1 s, solo entre los cinco primeros resultados de la búsqueda.
- **Cómo:** `cargo build --release` sin avisos, `cargo test` (casos nuevos); `--play
  Ui7L0VZqAT0` con una copia de la configuración y la sesión del propietario: suena
  `VqtScyk2C5A` a 239 kbps, arranque 2,6 s.
- **No verificado:** la app empaquetada; Linux y Windows.

## 2026-11-24 · yt-dlp 2026.11.23: Premium y las ediciones japonesas vuelven a sonar

- **Causa de «las canciones de Genshin han dejado de sonar»:** la cuenta da ediciones japonesas
  que solo suenan con yt-dlp y las cookies; yt-dlp 2026.10.26 dejó de resolver los retos de
  YouTube y todo caía a la vía rápida, que no las ve. En Windows sonaban porque el instalador
  trae un yt-dlp más reciente.
- **Cambio:** yt-dlp 2026.11.23 (PyPI) instalado en el entorno de Homebrew del propietario
  (`pip install --no-deps --ignore-installed`; se deshace con `brew reinstall yt-dlp`). En el
  código, «no disponible» no aparca Premium (`FAST_ONLY`) y «Requested format is not available»
  ya no cuenta como no disponible.
- **Cómo:** `cargo build --release` sin avisos, `cargo test`; `--play` con una copia de la
  configuración y la sesión: `dQw4w9WgXcQ` a 276 kbps (3,5 s), `rQ0mqd9Y2Mk` a 243 kbps (3,9 s),
  `bmzmDeh2eAQ` por la vía rápida (2,5 s, sin aparcar Premium); yt-dlp con las cookies da el
  formato 774 en `rQ0mqd9Y2Mk` y `8Ifm9ys-ds8`.
- **No verificado:** la app empaquetada; Linux y Windows.

## 2026-11-24 · Premium aparcado si yt-dlp falla; pistas no disponibles recordadas

- **Fallo:** yt-dlp 2026.10.26 ya no resuelve los retos de YouTube (deno: «a.addOnDisposeCallback
  is not a function», también con el script de retos al día de GitHub); con Premium, cada pista
  perdía ~4–5 s antes de caer a la vía rápida. Homebrew aún no tiene la 2026.11.23.
- **Cambio:** `premium_paused` (10 min de vía rápida tras un fallo de yt-dlp con una pista que la
  vía rápida da), `UNAVAILABLE` y un solo yt-dlp si el residente dice «no disponible»;
  `same_song` acepta el artista traducido con la duración a ±1 s.
- **Cómo:** `cargo build --release` sin avisos, `cargo test`; `--play` con una copia de la
  configuración y la sesión del propietario: `8Ifm9ys-ds8` (suena `pGy-at-thME`, 986 ms),
  `rQ0mqd9Y2Mk` (suena `lm3t3myPspk`, 606 ms) y `bmzmDeh2eAQ` (2,8 s, la primera de la sesión).
- **No verificado:** Premium con un yt-dlp que funcione (vuelta tras la pausa); Linux y Windows.

## 2026-11-24 · otra edición para las pistas de otra región

- **Fallo:** con la sesión, la playlist `PLYmtktlWO6Jk_f5Ci-Ml24_UD5g-ojciZ` daba «さざ波 La
  vaguelette» como `rQ0mqd9Y2Mk` (edición japonesa: con yt-dlp 2026.10.26, roto, no salía por ninguna vía); sin sesión, la misma fila es `lm3t3myPspk`, que suena. En Windows sonaba porque allí
  llegaba esa otra.
- **Cambio:** `resolver::alternative` (búsqueda sin la cuenta, `ytm::search_songs_anonymous`) y
  `Player::replace_video_id`; sin reintento si YouTube dice «no disponible».
- **Cómo:** `cargo build --release` sin avisos, `cargo test`; `--play rQ0mqd9Y2Mk` con una copia
  de la configuración y la sesión del propietario en un `HOME` de pruebas (`sonando true`,
  arranque 9,2 s con Premium y yt-dlp 2026.10.26); `--autoplay` sin sesión (`sonando true`, 181 ms).
- **No verificado:** Linux y Windows; la app empaquetada; con yt-dlp actualizado.

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
