---
area: detalle
titulo: Detalle e inspeccionar
resumen: Detalle de un álbum, playlist o artista con Reproducir y Aleatorio, y el modo inspeccionar que gira la caja, la abre y saca el disco.
archivos: [qml/DetailView.qml, qml/ArtistHero.qml, qml/InspectView.qml]
opciones: []
adr: []
---

# Detalle e inspeccionar

Elegir un álbum, playlist o artista abre su detalle; `I` lo inspecciona.

## Qué hace

- **Detalle** (`Library.openDetail`): se muestra al instante lo conocido (carátula, título) y las
  canciones llegan después. De un artista se usa la playlist de «todas sus canciones» y se añaden
  sus carruseles (álbumes, singles…). Botones Reproducir y Aleatorio.
- **Artista, en disposición «Órbita»** (elegida por el propietario entre tres, a partir de una
  muestra suya): ocupa todo el ancho. Arriba (`ArtistHero`), su foto en círculo en el centro, un
  anillo de rayas del color de la foto (`tint`, la sonda de la ventana) y sus tres canciones más
  escuchadas en tarjetas de vidrio alrededor, con su botón de reproducir; debajo, el nombre, los
  oyentes, Reproducir y Aleatorio. Al bajar, la lista de canciones (centrada, hasta 1000 px) y la
  discografía. Un álbum o playlist sigue con la carátula a la izquierda y la lista a la derecha.
- **Inspeccionar:** la caja en grande sobre el escenario desenfocado. Giro de 180° para la
  contraportada con las canciones, pliegue de la tapa para ver el libreto y la bandeja, y el disco,
  que sale y gira mientras suena.

## Reglas y decisiones

- **La cabecera del artista es estática**: el anillo es una `Shape` con tres `PathMultiline`
  (sin textura ni animación) y solo existe con un artista (`Loader` en la cabecera de la lista).
  Las rayas no tienen por qué ser todas del mismo largo: ondulan alrededor del círculo (`rays`).
- **Cabecera y canciones en la misma `ListView`**: así la rueda baja de la cabecera a la lista
  sin dos zonas de desplazamiento. El margen de las filas va dentro del delegado (`inset`), no en
  la `x` del delegado ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).

- **Al llegar las canciones se resuelven las seis primeras** ([resolucion](resolucion.md)): la que
  elijas suena al momento.
- **La tapa se abre con un pliegue plano** (`Scale` en X), no con una `Rotation`: las rotaciones de
  más de ~70° acercan la pieza a la cámara y la agrandan ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Artista abierto (Daddy Yankee, 1440×900 Retina), con la cabecera «Órbita» / sin ella | 290 / 287–290 MB (dentro del ruido) | 2026-11-18, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/DetailView.qml` | Detalle con la lista de canciones y la discografía |
| `qml/ArtistHero.qml` | Cabecera «Órbita» de un artista: foto, anillo y tres canciones |
| `qml/InspectView.qml` | Caja 3D: girar, abrir, sacar el disco |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Reproducir desde una canción | [`play`](../../qml/DetailView.qml) |
| Medidas de la cabecera del artista | [`photo`](../../qml/ArtistHero.qml), [`ringOuter`](../../qml/ArtistHero.qml) |
| Rayas del anillo y su color | [`rays`](../../qml/ArtistHero.qml), [`shade`](../../qml/ArtistHero.qml) |
| Margen de las filas de un artista | [`inset`](../../qml/DetailView.qml) |
| Bajar el detalle en pruebas (`--detail-at`) | [`scrollTo`](../../qml/DetailView.qml) |
| Girar la caja | [`turn`](../../qml/InspectView.qml) |
| Abrir la tapa | [`toggleOpen`](../../qml/InspectView.qml) |
| Sacar el disco | [`toggleDisc`](../../qml/InspectView.qml) |

## Dependencias

- **[catalogo](catalogo.md)** (`Catalog.detalle`, `Library.openDetail`): el detalle abierto.
- **[reproduccion](reproduccion.md)** (`Player.playTracks`, `Player.prefetchTracks`): reproducir y
  precargar.
- **La usan:** [ventana](ventana.md).

## Estado actual

- **Última verificación:** 2026-11-18, vista de artista «Órbita» ([historial](../history/verificacion/detalle.md)).
- **Pruebas:** capturas con `--autoplay --open`, `--shuffle`, `--detail-at y` e `--inspect flip|open|disc`
  ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** la cabecera del artista en una ventana estrecha (1120 px) y en Linux; bajar
  con la rueda o el trackpad de verdad (la rueda simulada solo mueve la primera muesca); un artista
  con menos de tres canciones.
- **Historial:** [docs/history/verificacion/detalle.md](../history/verificacion/detalle.md).
