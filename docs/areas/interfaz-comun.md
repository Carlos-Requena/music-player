---
area: interfaz-comun
titulo: Piezas comunes de la interfaz
resumen: Vidrio, carátula, icono, botones, deslizador, pestañas y campo de texto que usan todas las pantallas.
archivos: [qml/Glass.qml, qml/Cover.qml, qml/Icon.qml, qml/IconButton.qml, qml/PillButton.qml, qml/Slider.qml, qml/TextField.qml, qml/Tabs.qml, qml/TabButton.qml, qml/FocusRing.qml, qml/TrackRow.qml, qml/SectionLabel.qml, qml/FocusedCaption.qml, qml/EmptyState.qml]
opciones: []
adr: [ADR-23]
---

# Piezas comunes de la interfaz

Lo que se reutiliza en todas partes. Una pieza que sirva en dos sitios se hace aquí (y se añade a
esta ficha), no se copia con otro nombre.

## Qué hace

| Pieza | Para qué |
|---|---|
| `Glass` | Panel de vidrio; con `backdrop` desenfoca en tiempo real lo de detrás, sin él solo tiñe (más barato) |
| `Cover` | Carátula desde su miniatura, con fondo neutro mientras carga (`placeholder: false` lo quita para que se vea lo de debajo); `load` permite no descargar lo que no se ve; `radius` la redondea (o la hace círculo); `ready`, cargada y ya a la vista |
| `Icon` | Icono vectorial de un trazo SVG en caja 24×24 |
| `IconButton` | Botón de icono: 44 px, foco por teclado, nombre accesible, agarre exclusivo |
| `PillButton` | Botón de texto en píldora; `primary` lo rellena |
| `Slider` | Deslizador de 0 a 1; `stepSize` es lo que mueve cada flecha |
| `TextField` | Campo de una línea con etiqueta accesible; `committed` al pulsar Intro o salir |
| `Tabs` | Pestañas o segmentos (`tabs: [{ id, label, icon? }]`, `current`, `picked(id)`): navegación superior, Letra/Cola/Temporal del panel y de «Sonando», segmentos y categorías de Opciones. `navigate` (regla de dos), `fill` (anchos iguales), `well` (pozo oscuro), `vertical` |
| `TabButton` | Una pestaña o un segmento; la agrupa `Tabs` y `CategoryBar` la usa suelta (con renombrar y clic derecho) |
| `FocusRing` | Aro de foco del teclado: 2 px del color del texto, separado 3 px del control |
| `TrackRow` | Fila de canción (número o miniatura, título, artista, duración, «suena», elegida, arrastrándose): detalle, cola y temporal. Solo dibuja; los gestos los pone quien la usa |
| `SectionLabel` | Etiqueta de sección en mayúsculas espaciadas |
| `FocusedCaption` | Nombre y subtítulo del elemento enfocado (Muro, Lomos, Cubeta) |
| `EmptyState` | Aviso de algo vacío: icono, frase y botón opcional (secciones sin sesión, búsqueda, temporal) |

## Reglas y decisiones

- **Una pieza por papel** ([ADR-23](../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)):
  pestañas, filas de canción, etiquetas, título de lo enfocado y avisos vacíos salen de aquí. Las
  medidas (letra, radios, margen) son las de `Theme` ([personalizacion](personalizacion.md)).
- **Regla de dos** en `TabButton`: lo que dice dónde estás (`navigate`) se marca en blanco y es
  una píldora; un valor que eliges (`navigate: false`), en vidrio claro (`controlActive`) con el
  radio M. El ratón encima, siempre `control`.
- **Foco con `FocusRing`, fuera del control**: un borde interior blanco no se veía sobre lo
  elegido ni sobre el botón principal (blancos), por eso `PillButton` lo ponía en acento. Ahora es
  el mismo en todo. En las rejillas (Muro, Explorar), el elemento del teclado lleva un aro de
  `Theme.cursorWidth` (3 px) y el brillo de color es solo del ratón.
- **`TrackRow`**: «suena» = título en acento y ▸ (en lugar del número o sobre la miniatura);
  elegida = vidrio claro. Qué hace un clic lo decide la opción `clic` (`Theme.singleClick`), que
  aplica quien la usa. Quien pone un `MouseArea` encima (la cola) le pasa `hovered`.

- **Botones con agarre exclusivo** (`gesturePolicy: TapHandler.ReleaseWithinBounds`): si no, el clic
  atraviesa a lo de debajo ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- **`Icon` se recrea** con un `Loader` cada vez que sube `Theme.renderEpoch`: una `Shape` con
  CurveRenderer no se redibuja tras liberar los gráficos de la ventana.
- **`Glass` con `backdrop` cuesta un desenfoque por fotograma**: úsalo solo donde se vea. Sin
  `backdrop` no reserva ni la máscara del desenfoque. El desenfoque se rehace cada vez que cambia
  algo dentro de `backdrop`: dale la capa más pequeña que sirva (en «Sonando», solo su fondo). Si
  el `backdrop` se mueve (sube con una pantalla), su `x` e `y` están en las dependencias del recorte.
- **`Glass` copia el fondo a media resolución** (`textureSize`): se desenfoca tanto que no se nota y
  la copia pesa la cuarta parte (la de Opciones ocupa casi toda la ventana).
- **`Cover.picture`** da la imagen de la carátula para leer su textura en un sombreador (el reflejo
  de Lomos) sin cargarla dos veces.
- **`Slider` dibuja en píxeles enteros** (`drawn`): un `value` que cambia sin mover el tirador un
  píxel no redibuja la ventana.
- **`Cover` con `radius` es un sombreador** (`shaders/caratula.frag`): lee la textura de la imagen
  (oculta), la recorta para cubrir el recuadro (`crop`, como `PreserveAspectCrop`: las miniaturas
  de vídeo no se deforman) y calcula el borde redondeado, sin capa ni máscara. Lo usan todas las
  carátulas redondeadas (opción `esquinas`): Muro, Explorar, detalle, filas, barra, panel,
  «Sonando» y mini. Con una `Shape` por carátula (`ShapePath.fillItem`), un Muro lleno ocupaba unos
  24 MB más que con carátulas cuadradas; con el sombreador, unos 10 MB
  ([vistas](vistas.md#medidas)). Se vuelve a pintar sola tras ocultar la ventana, sin
  `renderEpoch`.
- Los iconos (trazos) están en `Theme.qml` (`iconPlay`, `iconQueue`…).

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/Glass.qml` | Vidrio |
| `qml/Cover.qml` | Carátula |
| `qml/Icon.qml` | Icono |
| `qml/IconButton.qml` | Botón de icono |
| `qml/PillButton.qml` | Botón de texto |
| `qml/Slider.qml` | Deslizador |
| `qml/TextField.qml` | Campo de texto |
| `qml/Tabs.qml` | Pestañas y segmentos |
| `qml/TabButton.qml` | Una pestaña |
| `qml/FocusRing.qml` | Aro de foco |
| `qml/TrackRow.qml` | Fila de canción |
| `qml/SectionLabel.qml` | Etiqueta de sección |
| `qml/FocusedCaption.qml` | Título de lo enfocado |
| `qml/EmptyState.qml` | Aviso de vacío |
| `shaders/caratula.frag` (+ `.qsb`) | Esquinas redondeadas de `Cover`; se compila con `scripts/shaders.sh` |

## Dependencias

- No usa otras áreas (solo `Theme`).
- **La usan:** todas las que tienen interfaz.

## Estado actual

- **Última verificación:** 2026-11-21, piezas comunes nuevas y regla de dos ([historial](../history/verificacion/interfaz-comun.md)).
- **Pruebas:** ninguna automática.
- **Sin verificar:** el sombreador de `Cover` en Linux (OpenGL y Vulkan) y en una pantalla sin
  Retina; el foco de teclado (`FocusRing`) en las pestañas con el teclado de verdad (las capturas no
  dejan la ventana activa); la opción `clic` con el ratón de verdad (sin clics simulados).
- **Historial:** [docs/history/verificacion/interfaz-comun.md](../history/verificacion/interfaz-comun.md).
