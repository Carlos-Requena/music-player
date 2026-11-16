# Historial de verificación · Reproducción y cola

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/reproduccion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

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

## 2026-11-15 · Señal `saltada` y clic en toda la barra

`Player.next` emite `saltada` (lo usa la mascota); el fin natural de una pista usa `advance`, que no
la emite. Pulsar cualquier zona libre de la barra abre «Sonando» (antes solo la carátula y el
título). Verificado con `MUSICPLAYER_DEBUG_CLICK` y `--shot`: clic en zona libre → «Sonando»;
clic en reproducir y en la barra de progreso → no se abre y la posición salta; «Siguiente» → pasa
de pista sin abrirla. No sonó nada (YouTube bloqueaba sin sesión): no verificado con audio real.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
