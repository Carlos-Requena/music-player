# Historial de verificación · Reproducción y cola

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/reproduccion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

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
