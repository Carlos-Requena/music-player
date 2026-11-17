# Historial de verificación · Resolución del audio y arranque instantáneo

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/resolucion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

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
