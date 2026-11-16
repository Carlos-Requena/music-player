# Historial de verificación · Letra sincronizada

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/letra.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-16 · Las palabras largas caben en recuadros estrechos

- **Cambio:** una palabra más ancha que la línea se encoge hasta caber (`FontMetrics` común); en
  «Sonando» el tamaño base baja con el ancho del recuadro.
- **Verificado:** captura de «Supercalifragilisticexpialidocious» en «Sonando» Grande (recuadro de
  ~430 px): antes se cortaba, ahora cabe; sin avisos de bucle de enlaces en la terminal.
- **No verificado:** CPU de la letra sonando (YouTube pidió sesión y no sonó), el panel lateral con
  esa canción.

## 2026-11-14 · Letra al estilo Better Lyrics, tres calidades

- **Cómo:** CPU acumulada de la app en 25 s (`ps -o time=`), reproduciendo la misma canción, panel
  lateral y «Sonando», release, M4 Pro. Memoria con `footprint`.
- **Resultado:** las cifras de [la ficha](../../areas/letra.md#medidas). Descartados: gestor de
  «hover»/cursor/clic por línea (~25 % de CPU), `Text.CurveRendering` (~95 MB más), brillo con
  `layer.effect` (texto borroso), medios píxeles en la elevación (borroso).
- **No verificado:** Linux.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
