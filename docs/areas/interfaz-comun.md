---
area: interfaz-comun
titulo: Piezas comunes de la interfaz
resumen: Vidrio, carátula, icono, botones, deslizador y campo de texto que usan todas las pantallas.
archivos: [qml/Glass.qml, qml/Cover.qml, qml/Icon.qml, qml/IconButton.qml, qml/PillButton.qml, qml/Slider.qml, qml/TextField.qml]
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
| `Cover` | Carátula desde su miniatura, con fondo neutro mientras carga; `load` permite no descargar lo que no se ve |
| `Icon` | Icono vectorial de un trazo SVG en caja 24×24 |
| `IconButton` | Botón de icono: 44 px, foco por teclado, nombre accesible, agarre exclusivo |
| `PillButton` | Botón de texto en píldora; `primary` lo rellena |
| `Slider` | Deslizador de 0 a 1 |
| `TextField` | Campo de una línea con etiqueta accesible; `committed` al pulsar Intro o salir |

## Reglas y decisiones

- **Botones con agarre exclusivo** (`gesturePolicy: TapHandler.ReleaseWithinBounds`): si no, el clic
  atraviesa a lo de debajo ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- **`Icon` se recrea** con un `Loader` cada vez que sube `Theme.renderEpoch`: una `Shape` con
  CurveRenderer no se redibuja tras liberar los gráficos de la ventana.
- **`Glass` con `backdrop` cuesta un desenfoque por fotograma**: úsalo solo donde se vea.
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

## Dependencias

- No usa otras áreas (solo `Theme`).
- **La usan:** todas las que tienen interfaz.

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** ninguna automática.
- **Sin verificar:** —
- **Historial:** [docs/history/verificacion/interfaz-comun.md](../history/verificacion/interfaz-comun.md).
