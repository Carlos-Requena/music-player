# Historial de verificación · Reproducción y cola

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/reproduccion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-18 · Ecualizador y amplificador de volumen (rama `feature/artista-y-ecualizador`)

- **Cambio:** filtros de mpv (`audio::effects_chain`) con diez bandas, amplificador hasta +12 dB y
  limitador; opciones `ecualizador`, `ecualizadorBandas` y `amplificador`; `Player.applyEffects`;
  interfaz en Opciones › Plugins.
- **Verificado:** tres pruebas de la cadena de filtros; mpv 0.42 acepta la cadena (sin errores);
  con `--autoplay`, `get_property af` por el socket de mpv devuelve la cadena guardada y
  `sonando true`; captura de Opciones › Plugins con el preajuste Graves y +4 dB. Memoria de mpv
  igual con y sin efectos (232 / 231 MB) y ~1 % de un núcleo más.
- **No verificado:** cómo suena (mpv iba sin salida de audio); el corte al mover un deslizador
  mientras suena; Linux.

## 2026-11-17 · Colas con límite, mensajes de mpv sin árbol JSON (rama `perf/letra`)

- **Cambio:** `album_queue` guarda las últimas 24 colas y no descarga dos veces la misma a la vez;
  los mensajes de mpv se leen con `Message` (nombres prestados de la línea) y una línea que se
  reutiliza; las ediciones de la cola no la copian (`mem::take`); `new_request` reúne el comienzo
  de cada petición; fuera el alias `Mpv::load_stream`.
- **Verificado:** prueba nueva de `Message` (posición, aviso con escapes, fin de pista, respuesta
  sin evento); `--play` y un álbum de Lomos con audio local: `sonando true`.
- **No verificado:** con el audio real de YouTube; reordenar, quitar y barajar la cola a la vista.

## 2026-11-16 · Progreso en píxeles enteros y la letra una vez (rama `perf/letra`)

- **Cambio:** `Slider` (y con él la barra de posición), la línea de la barra Compacta y la del
  mini reproductor se dibujan en píxeles enteros. `Player` pide la letra de una canción pulsada al
  llegar su cola (`defer_lyrics`), no dos veces. Depuración: `MUSICPLAYER_DEBUG_AUDIO`.
- **Verificado:** con el panel en la pestaña Cola, 2,9 s → 0,3 s de CPU en 25 s; `--play` de una
  canción (letra de 46 líneas, sin la búsqueda fallida a LRCLIB de antes) y `--autoplay` de un
  álbum en Lomos con audio local: `sonando true`, sin `error`. Con YouTube real, el álbum pide
  sesión (como antes de los cambios).
- **No verificado:** el arranque con audio de YouTube; la barra Compacta y el mini a la vista.

## 2026-11-16 · La zona central de la barra Clásica ya no se mueve con el título

- **Cambio:** la columna de botones y posición se centra con un margen fijo a los dos lados
  (`side`, a partir de los 300 px máximos de lo que suena), no anclada al ancho del título. Rama
  `fix/clics-y-barra`.
- **Verificado:** capturas de la barra Clásica con «Nada sonando» y con «Cosas del amor»: el botón
  de reproducir y la posición en el mismo sitio.
- **No verificado:** con un título larguísimo y la ventana al ancho mínimo (1120 px); Linux.

## 2026-11-16 · Quitar «Me gusta» desde la barra

- **Cambio:** el corazón alterna: lo da en la cuenta y, pulsado otra vez, lo quita
  (`like/removelike`); no acepta otro clic mientras va la petición.
- **Verificado:** sin sesión, un clic de verdad en el corazón: stderr `me gusta … (true): Hace
  falta iniciar sesión…` y el corazón vuelve a vacío. `cargo test` en verde.
- **No verificado:** con sesión (no se usan las cookies del propietario en pruebas): dar, quitar y
  que la sección «Me gusta» se actualice.

## 2026-11-16 · `kill` a la app ya no deja mpv huérfano

Con SIGTERM la app moría sin destruir el `Player` y su mpv seguía vivo con padre 1 (~20 MB cada
uno; 15 tras 15 mediciones del runbook de rendimiento). `src/signals.cpp` (self-pipe y
`QSocketNotifier`) convierte SIGTERM, SIGINT y SIGHUP en `QCoreApplication::quit()`.
Verificado en macOS (M4 Pro), release, `HOME` temporal y `MUSICPLAYER_SILENT=1`: arrancar, esperar
10 s, `kill -TERM`/`-INT`/`-HUP` y a los 2 s `pgrep -f "musicplayer-mpv-$APP.sock"` vacío, la app
fuera y código de salida 0, en las tres. También con `--autoplay` en marcha (pista cargada):
mpv cerrado tras el `kill`. **No verificado:** con audio sonando de verdad ni con el yt-dlp
residente vivo (YouTube respondía «Sign in to confirm you're not a bot», también a `yt-dlp`
directo, así que `--autoplay` acabó en `sonando false`); Linux.

## 2026-11-16 · Estilos Clásica y Compacta de la barra

- **Cambio:** opción `barra` (Islas, Clásica, Compacta) en Opciones › Apariencia; `PlayerBar.qml`
  reorganizado en piezas comunes y un `Loader` por estilo.
- **Verificado:** captura de cada estilo con una canción cargada y su letra (`HOME` de pruebas,
  release) y de la fila nueva en Opciones; sin errores de QML en la terminal.
- **No verificado:** arrastrar la línea de posición de Compacta y sus flechas; el audio (YouTube
  pidió sesión).

## 2026-11-16 · Barra en tres islas, «Me gusta» y Aleatorio

- **Cambio:** `PlayerBar.qml` en tres islas con un solo desenfoque; corazón de «Me gusta» y botón
  Aleatorio (`Player.shuffleQueue`, baraja lo que queda detrás de la que suena).
- **Verificado:** capturas sin nada sonando y con «Creep» cargada (cola 49, letra 39). Memoria en
  Explorar, tres ejecuciones cada una (M4 Pro, release, `HOME` de pruebas): 212–219 MB antes,
  217–221 MB después; la diferencia (~3 MB) está dentro del ruido. Con un desenfoque por isla
  salían 215–228 MB y se descartó.
- **No verificado:** el audio (YouTube respondió `LOGIN_REQUIRED` sin sesión, no se insistió); el
  «Me gusta» de verdad y barajar con una cola sonando.

## 2026-11-15 · Señal `saltada` y clic en toda la barra

`Player.next` emite `saltada` (lo usa la mascota); el fin natural de una pista usa `advance`, que no
la emite. Pulsar cualquier zona libre de la barra abre «Sonando» (antes solo la carátula y el
título). Verificado con `MUSICPLAYER_DEBUG_CLICK` y `--shot`: clic en zona libre → «Sonando»;
clic en reproducir y en la barra de progreso → no se abre y la posición salta; «Siguiente» → pasa
de pista sin abrirla. No sonó nada (YouTube bloqueaba sin sesión): no verificado con audio real.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
