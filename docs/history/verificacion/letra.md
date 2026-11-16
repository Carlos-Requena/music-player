# Historial de verificación · Letra sincronizada

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/letra.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-16 · Letra centrada también en vertical y retraso como pie discreto

- **Cambio:** con la letra centrada, la línea que suena va al 50 % de la altura y la letra no deja
  hueco arriba al empezar. `LyricsTiming` pasa a ser un pie de texto tenue (diseño B), el mismo en
  «Sonando» (antes, cápsula arriba a la derecha) y en el panel (antes, pie con separador que pintaba
  el panel); la letra se recorta encima de él.
- **Verificado:** capturas de «Sonando» y del panel al empezar la canción (la letra llena la zona y
  el pie se lee) y a mitad de canción adelantando la letra 30 s con sesenta clics simulados en «−»
  (la línea activa, a media palabra, en el centro; el pie iluminado con «Letra −30,0 s»).
- **No verificado:** con música sonando de verdad (YouTube pedía sesión); el foco por teclado del
  pie; volver a cero pulsando el texto.

## 2026-11-16 · Letra centrada

- **Cambio:** opción `letraAlineacion` (Centrada por defecto, A la izquierda). El `Flow` de cada
  línea pasa a renglones calculados (`rows`, con el ancho de `FontMetrics`), cada uno un `Row`
  centrado; las líneas inactivas encogen desde el centro y los puntos de las pausas van centrados.
- **Verificado:** capturas de «Sonando» (con fondo «Fluido») y del panel lateral con letra de
  LRCLIB: cada renglón centrado y los partidos en dos («Love of my life, you've / hurt me») también.
- **No verificado:** el barrido y la cascada con música sonando (YouTube pedía sesión); CPU de la
  letra con el cambio (no debería variar: el mismo número de `Text`); «A la izquierda» en captura.

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
