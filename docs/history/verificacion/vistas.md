# Historial de verificación · Vistas de las secciones

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/vistas.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-17 · Lomos con anillo de cajas y reflejo por sombreador; Muro en una lista (rama `perf/letra`)

- **Cambio:** Lomos crea un anillo fijo de cajas (`ring`) en vez de una por elemento, pide la
  carátula a 544 px solo cerca del centro (226 px en las demás) y el reflejo es un sombreador
  (`shaders/reflejo.frag`) en vez de una capa con máscara. El Muro es una `ListView` que solo crea
  las filas cercanas. Muro y Lomos avisan del elemento bajo el puntero (`hinted`).
- **Verificado:** memoria en Álbumes (Lomos, `--index 5`), dos pasadas: 222–226 MB → 205–207 MB.
  Capturas de Lomos (reflejos y halo como antes) y del Muro desplazado con la rueda. El Muro salía
  pegado al borde: corregido con `leftMargin` (trampa nueva).
- **Medidas anteriores** (de la ficha): Álbumes en Lomos ~290 MB y los reflejos de las cajas
  visibles ~7 MB (2026-11-13, M4 Pro, release; otro método, con la caché de secciones).
- **No verificado:** recorrer Lomos deprisa a la vista (la caja que cambia de elemento en el
  extremo); las teclas del Muro con filas que aún no existen; Linux (el sombreador, con Vulkan).

## 2026-11-16 · Barra para recorrer Lomos

- **Cambio:** barra `1 —●— N` bajo el título de la elegida en Lomos (rama `feature/rediseno`).
- **Verificado:** captura de Inicio en Lomos con `--index 3` (`HOME` de pruebas, release): la barra
  sale centrada bajo el subtítulo con el punto en su sitio.
- **No verificado:** arrastrarla con el ratón de verdad; Álbumes y Playlists con sesión; Linux.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
