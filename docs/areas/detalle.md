---
area: detalle
titulo: Detalle e inspeccionar
resumen: Detalle de un álbum, playlist o artista con Reproducir y Aleatorio, y el modo inspeccionar que gira la caja, la abre y saca el disco.
archivos: [qml/DetailView.qml, qml/InspectView.qml]
opciones: []
adr: []
---

# Detalle e inspeccionar

Elegir un álbum, playlist o artista abre su detalle; `I` lo inspecciona.

## Qué hace

- **Detalle** (`Library.openDetail`): se muestra al instante lo conocido (carátula, título) y las
  canciones llegan después. De un artista se usa la playlist de «todas sus canciones» y se añaden
  sus carruseles (álbumes, singles…). Botones Reproducir y Aleatorio.
- **Inspeccionar:** la caja en grande sobre el escenario desenfocado. Giro de 180° para la
  contraportada con las canciones, pliegue de la tapa para ver el libreto y la bandeja, y el disco,
  que sale y gira mientras suena.

## Reglas y decisiones

- **Al llegar las canciones se resuelven las seis primeras** ([resolucion](resolucion.md)): la que
  elijas suena al momento.
- **La tapa se abre con un pliegue plano** (`Scale` en X), no con una `Rotation`: las rotaciones de
  más de ~70° acercan la pieza a la cámara y la agrandan ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/DetailView.qml` | Detalle con la lista de canciones y la discografía |
| `qml/InspectView.qml` | Caja 3D: girar, abrir, sacar el disco |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Reproducir desde una canción | [`play`](../../qml/DetailView.qml) |
| Girar la caja | [`turn`](../../qml/InspectView.qml) |
| Abrir la tapa | [`toggleOpen`](../../qml/InspectView.qml) |
| Sacar el disco | [`toggleDisc`](../../qml/InspectView.qml) |

## Dependencias

- **[catalogo](catalogo.md)** (`Catalog.detalle`, `Library.openDetail`): el detalle abierto.
- **[reproduccion](reproduccion.md)** (`Player.playTracks`, `Player.prefetchTracks`): reproducir y
  precargar.
- **La usan:** [ventana](ventana.md).

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** capturas con `--autoplay --open`, `--shuffle` e `--inspect flip|open|disc`
  ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** —
- **Historial:** [docs/history/verificacion/detalle.md](../history/verificacion/detalle.md).
