---
area: interfaz-comun
titulo: Piezas comunes de la interfaz
resumen: Vidrio, carátula, icono, botones, deslizador, pestañas y campo de texto que usan todas las pantallas.
archivos: [qml/Glass.qml, qml/Cover.qml, qml/Icon.qml, qml/IconButton.qml, qml/PillButton.qml, qml/Slider.qml, qml/TextField.qml, qml/TabStrip.qml]
opciones: []
adr: []
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
| `TabStrip` | Pestañas en una cápsula (`tabs: [{ id, label }]`, `current`, `picked(id)`): las del panel lateral y las de «Sonando» |

## Reglas y decisiones

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
- **`Cover` con `radius`** rellena una forma con la imagen (`ShapePath.fillItem`), sin capa ni
  máscara aparte; la forma se recrea con `Theme.renderEpoch`, como `Icon`. La forma pone la
  textura en su esquina con su tamaño en píxeles físicos, así que `fillTransform` la escala para
  cubrir la carátula y la centra (como `PreserveAspectCrop`) ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
  Es lo que usan la barra, el panel y «Sonando».
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
| `qml/TabStrip.qml` | Pestañas |

## Dependencias

- No usa otras áreas (solo `Theme`).
- **La usan:** todas las que tienen interfaz.

## Estado actual

- **Última verificación:** 2026-11-17, `TabStrip`, vidrio a media resolución y Cover.picture ([historial](../history/verificacion/interfaz-comun.md)).
- **Pruebas:** ninguna automática.
- **Sin verificar:** `Cover` con `radius` tras ocultar y volver a mostrar la ventana; en una
  pantalla sin Retina (densidad 1, CachyOS): la captura sin ventana no pinta el relleno de la forma.
- **Historial:** [docs/history/verificacion/interfaz-comun.md](../history/verificacion/interfaz-comun.md).
