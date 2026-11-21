# Historial de verificación · Piezas comunes de la interfaz

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/interfaz-comun.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-21 · Piezas comunes nuevas, regla de dos y esquinas con sombreador (en `master`)

- **Cambio:** `Tabs`, `TabButton`, `FocusRing`, `TrackRow`, `SectionLabel`, `FocusedCaption` y
  `EmptyState` ([ADR-23](../../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md));
  `TabStrip` desaparece (lo sustituye `Tabs`). Foco de `IconButton`, `PillButton` y `Slider` con
  `FocusRing` (antes, borde interior blanco o de acento). `Cover` redondea con un sombreador
  (`shaders/caratula.frag`) en vez de una `Shape`.
- **Cómo:** 29 capturas con `--shot` (release, `HOME` de pruebas, `MUSICPLAYER_SILENT=1`, macOS Retina 1440×900, sin sesión), revisadas a ojo, sin errores de QML en la salida. Memoria: Inicio en Muro a los 30 s, `footprint … phys_footprint`, alternando
  `esquinas` redondeadas y cuadradas en el mismo `HOME`.
- **Resultado:** pestañas de navegación en blanco (navegación, panel, «Sonando», categorías de
  Opciones) y segmentos en vidrio claro (Opciones); filas de detalle, cola y temporal iguales; la
  que suena con título en acento y ▸. Carátulas redondeadas, artistas en círculo y miniaturas de
  vídeo recortadas sin deformar; repintadas tras ocultar y restaurar la ventana (`--minimize
  --hide --restore`). Memoria con `Shape`: 218–243 MB frente a 197–223 MB cuadradas (cuatro de
  cada); con el sombreador: 216–219 MB frente a 205–208 MB (tres de cada).
- **No verificado:** el foco del teclado en las capturas (la ventana de prueba no queda activa);
  Linux; pantalla sin Retina.

## 2026-11-17 · TabStrip, vidrio a media resolución y Cover.picture (rama `perf/letra`)

- **Cambio:** `TabStrip`, las pestañas del panel y de «Sonando» en un solo componente (con agarre
  exclusivo también en el panel, que no lo tenía); `Glass` y la barra copian el fondo a media
  resolución; `Cover.picture` para el reflejo de Lomos.
- **Verificado:** Opciones abierta: 253–256 MB → 231–239 MB; capturas de la barra, Opciones y
  las pestañas, sin diferencias a la vista en el desenfoque.
- **No verificado:** las pestañas con el teclado; el desenfoque con una skin clara.

## 2026-11-16 · `Slider.drawn` y el recorte del vidrio (rama `perf/letra`)

- **Cambio:** `Slider` dibuja el relleno y el tirador en píxeles enteros (`drawn`); `Glass`
  incluye `x` e `y` de su `backdrop` en las dependencias del recorte (el de «Sonando» sube con
  ella).
- **Verificado:** capturas de la barra de reproducción y del volumen; medida en
  [reproduccion](reproduccion.md).
- **No verificado:** arrastrar el deslizador a la vista.

## 2026-11-16 · `Cover` con `placeholder` y `ready`

- **Cambio:** `placeholder: false` quita el fondo neutro mientras carga, para que se vea la
  carátula pequeña de debajo; `ready` dice si ya está cargada y a la vista. Los usa «Sonando».
- **Verificado:** capturas de «Sonando» con la carátula redonda y nítida.
- **No verificado:** el momento de la carga (las capturas llegan con la grande ya puesta).

## 2026-11-16 · `Cover` redondeada sin el borde repetido

- **Cambio:** `fillTransform` escala la textura de `ShapePath.fillItem` para cubrir la carátula y
  la centra; antes ocupaba su tamaño en píxeles físicos (272 px de 311 en el panel) y el último
  píxel se repetía por la derecha y por abajo.
- **Verificado:** capturas con ventana (Retina) del panel lateral y de «Sonando»: la carátula
  coincide con la de Lomos, esquinas incluidas.
- **No verificado:** pantalla con densidad 1 (CachyOS); la captura sin ventana no pinta la forma.

## 2026-11-16 · `Cover` con radio, `Slider` con paso, `Glass` sin máscara de sobra

- **Cambio:** `Cover.radius` (forma rellena con la imagen), `Slider.stepSize`, y `Glass` solo
  reserva la máscara del desenfoque si desenfoca.
- **Verificado:** capturas de la barra (carátula en círculo) y del panel.
- **No verificado:** la carátula redonda tras ocultar la ventana (mini reproductor) y volver.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
