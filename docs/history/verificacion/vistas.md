# Historial de verificación · Vistas de las secciones

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/vistas.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-21 · Opción `clic` en el Muro (en `master`)

- **Cambio:** con «Un clic», un clic en el Muro abre o hace sonar, y el nombre de abajo sigue a la
  carátula bajo el ratón (`hoverItem`); con «Doble clic», como estaba.
- **Cómo:** `--shot --section inicio` con `clic` = `uno` y el ratón sobre la tercera carátula
  (`MUSICPLAYER_DEBUG_CLICK="500,350,wheel,6000,0"`).
- **Resultado:** abajo sale «pa ti toa <3» (la del ratón) mientras el aro sigue en la primera.
- **No verificado:** el clic de verdad; Lomos y Cubeta no cambian con la opción.

## 2026-11-21 · Interfaz unificada: sin cabecera, esquinas y aro del teclado (en `master`)

- **Cambio:** Lomos y Cubeta sin rótulo de sección; nombre de lo enfocado con `FocusedCaption` en
  Muro, Lomos y Cubeta; etiquetas con `SectionLabel`; margen común; carátulas con la opción
  `esquinas` (artistas en círculo); en Explorar, aro blanco en la tarjeta del teclado y brillo
  solo del ratón; la etiqueta de zona del Muro deja sitio a la carátula elegida; el frontal de
  Cubeta toma el fondo de la skin ([ADR-23](../../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)).
- **Cómo:** 29 capturas con `--shot` (release, `HOME` de pruebas, `MUSICPLAYER_SILENT=1`, macOS Retina 1440×900, sin sesión), revisadas a ojo, sin errores de QML en la salida: Inicio (Muro, Lomos, Cubeta), Explorar, Álbumes, búsqueda «Aimer», esquinas
  cuadradas, Neón. Memoria: ver la ficha de [interfaz-comun](../../areas/interfaz-comun.md).
- **Resultado:** la etiqueta de zona ya no se pisa con el aro; la barra de Lomos muestra la
  posición a la izquierda; los resultados de artistas salen en círculo.
- **No verificado:** el aro de Explorar con el teclado de verdad; Me gusta e Historial con sesión;
  Linux.

## 2026-11-21 · Brillo al pasar el ratón en el Muro y opción `brillo` (en `master`)

- **Cambio:** el Muro (Inicio y las demás secciones en Muro) hace crecer y brillar la carátula bajo
  el ratón con el color de su carátula, como las tarjetas de Explorar; halo y sonda solo en esa
  carátula (`Loader`). Opción `brillo` en Opciones › Vistas para desactivarlo en las dos vistas.
  `Theme.hoverGlow` y `Theme.glow` (el color, compartido).
- **Verificado** (release, `HOME` de pruebas, Retina): Inicio con el ratón sobre la tercera carátula
  (`wheel` de 0 pasos): crece y brilla en tono cálido; con `brillo` = `no`, la misma prueba no
  cambia nada, y Explorar tampoco. Fila nueva en Opciones › Vistas. `cargo test` en verde.
- **No verificado:** el brillo del foco del teclado (en estas capturas la ventana de prueba no
  quedó activa: tampoco sale con el brillo activado, así que no es la opción); el ratón de verdad;
  Me gusta, Historial y Búsqueda (mismo componente); CPU al pasar el ratón deprisa por el Muro;
  Linux.

## 2026-11-21 · Explorar por categorías (en `master`)

- **Cambio:** `qml/CategoriasView.qml`: Explorar en Muro muestra una tarjeta por zona («Portada con
  rótulo», elegida entre tres), con 40 px entre tarjetas, brillo del color de la carátula al pasar
  el ratón o con el foco, y clic para abrirla como detalle. `SectionView` la monta para Explorar en
  Muro ([ADR-22](../../decisions/ADR-22-explorar-por-categorias-con-recomendados.md)).
- **Verificado** (release, `HOME` de pruebas con `explorarFuente` = `youtube`, ventana Retina
  1440×900): capturas de Explorar (Recomendados primera, enfocada y brillando), del brillo al
  mover el ratón a la tercera tarjeta (`MUSICPLAYER_DEBUG_CLICK` con `wheel` de 0 pasos: brilla
  esa y se apaga la enfocada) y de un clic en la primera y en la segunda. Una `TintProbe` asomaba
  por la esquina redondeada de cada tarjeta y el nombre largo se cortaba: corregidos (trampa nueva).
  Memoria a los 30 s (`phys_footprint`): Explorar 200 MB, Inicio en Muro 400 MB.
- **No verificado:** el ratón de verdad; 5 tarjetas (ListenBrainz con usuario); otras skins;
  Linux.

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
