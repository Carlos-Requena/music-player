---
area: detalle
titulo: Detalle e inspeccionar
resumen: Detalle de un álbum, playlist o artista con Reproducir y Aleatorio, y el modo inspeccionar que gira la caja, la abre y saca el disco.
archivos: [qml/DetailView.qml, qml/ArtistHero.qml, qml/InspectView.qml]
opciones: [fichasAlbum, fichasPlaylist]
adr: [ADR-23]
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
  discografía. Un álbum o playlist sigue con la carátula y su información a la izquierda y las
  canciones a la derecha.
- **Canciones en cuadrícula** (`SongTile`), como el Muro de Inicio pero con fichas pequeñas (~110
  px, tantas columnas como quepan) y el título debajo, por petición del propietario: en un
  artista, bajo la cabecera «Órbita», a todo el ancho; en un álbum, playlist, «Relacionado» o
  categoría, a la derecha de la carátula. La elegida lleva el aro blanco y crece un poco; bajo el
  ratón, el brillo del Muro (opción `brillo`). Flechas en las cuatro direcciones.
- **Fichas de álbumes y playlists**, cada uno con su opción, a elegir por el propietario:
  «Número» (el número de pista en grande sobre el color de la carátula) o «Carátula» (la de cada
  canción con el número en una esquina). Un álbum va con «Número» por defecto (`fichasAlbum`: todas
  sus carátulas son la misma) y una playlist con «Carátula» (`fichasPlaylist`). Un artista,
  «Relacionado» y una categoría van siempre con carátula y sin número.
- **El halo no se corta**: la lista deja `glowRoom` (36 px) alrededor de la cuadrícula, y junto a la
  carátula empieza antes y llega al borde de la ventana para que las fichas queden en su sitio.
- **Relacionado** (`DetailView.related`, `kind` "related"): como un álbum, con la carátula de la
  canción, el título «Relacionado» y «Como «<canción>» · <artista>»; las canciones parecidas bajo
  «También te puede interesar», con Reproducir y Aleatorio, y debajo los carruseles de listas,
  artistas similares y más del artista. Sin el botón de inspeccionar.
- **Categoría de Explorar** (`DetailView.zona`, `kind` "zona", de `Library.openZona`): la carátula
  de su primer elemento, su nombre y «Explorar · N …». Si son canciones, la lista con Reproducir y
  Aleatorio; si no (álbumes, listas), sus elementos en una cuadrícula que llena el ancho
  (columnas de ~170 px), sin el título de la zona repetido. Sin el botón de inspeccionar ni `I`.
- **Inspeccionar:** la caja en grande sobre el escenario desenfocado. Giro de 180° para la
  contraportada con las canciones, pliegue de la tapa para ver el libreto y la bandeja, y el disco,
  que sale y gira mientras suena. Se sale con Esc o con el botón «Volver» de arriba a la
  izquierda, en el mismo sitio que en el detalle y en «Sonando».
- **Fichas de canción** con `SongTile` ([interfaz-comun](interfaz-comun.md)): la que suena, con
  el título en acento y ▸; la elegida, con el aro. Qué hace un clic lo decide la opción `clic` ([reproduccion](reproduccion.md)); el doble clic e Intro
  siempre la hacen sonar. En la discografía y en las cuadrículas de una categoría, los artistas
  van en círculo y lo demás con las esquinas de la opción `esquinas`.
- **Categoría de Explorar con álbumes o listas** (sin canciones): se recorre con el mismo Muro que
  Inicio (`MuroView` con medio margen, para que el aro de la elegida no se corte, a la derecha de su carátula, sin repetir el nombre de la
  zona): un clic elige (aro, brillo, nombre abajo) y el doble lo abre, o lo que diga la opción
  `clic`. Lo pidió el propietario.

## Reglas y decisiones

- **La cabecera del artista es estática**: el anillo es una `Shape` con tres `PathMultiline`
  (sin textura ni animación) y solo existe con un artista (`Loader` en la cabecera de la lista).
  Las rayas no tienen por qué ser todas del mismo largo: ondulan alrededor del círculo (`rays`).
- **Cabecera y canciones en la misma `ListView`**: así la rueda baja de la cabecera a la lista
  sin dos zonas de desplazamiento. Cada elemento de la lista es una fila de fichas
  (`tileRows`, de `columns` en `columns`): solo existen las filas a la vista y unas pocas más.
  El margen va dentro del delegado (`inset`), no en la `x` del delegado
  ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).

- **Medidas comunes** ([ADR-23](../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)):
  el título de un álbum es `Theme.fontTitle`; el nombre del artista, `fontDisplay`; las etiquetas
  («Canciones», carruseles), `SectionLabel`. El botón de volver y la columna de la carátula van en
  `Theme.margin`. El velo que separa el detalle del escenario está en `Main.qml`.
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
| Tarjeta de las tiras y de la cuadrícula de una categoría | [`ZoneCard`](../../qml/DetailView.qml), [`wall`](../../qml/DetailView.qml) |
| Medidas de la cabecera del artista | [`photo`](../../qml/ArtistHero.qml), [`ringOuter`](../../qml/ArtistHero.qml) |
| Rayas del anillo y su color | [`rays`](../../qml/ArtistHero.qml), [`shade`](../../qml/ArtistHero.qml) |
| Margen de la cuadrícula | [`inset`](../../qml/DetailView.qml) |
| Columnas, lado de la ficha y filas | [`columns`](../../qml/DetailView.qml), [`tileSide`](../../qml/DetailView.qml), [`tileRows`](../../qml/DetailView.qml) |
| Número o carátula (`fichasAlbum`, `fichasPlaylist`) | [`numbered`](../../qml/DetailView.qml), [`numberOnly`](../../qml/DetailView.qml) |
| Bajar el detalle en pruebas (`--detail-at`) | [`scrollTo`](../../qml/DetailView.qml) |
| Girar la caja | [`turn`](../../qml/InspectView.qml) |
| Abrir la tapa | [`toggleOpen`](../../qml/InspectView.qml) |
| Sacar el disco | [`toggleDisc`](../../qml/InspectView.qml) |

## Dependencias

- **[catalogo](catalogo.md)** (`Catalog.detalle`, `Library.openDetail`, `Library.openZona`): el
  detalle abierto.
- **[reproduccion](reproduccion.md)** (`Player.playTracks`, `Player.prefetchTracks`): reproducir y
  precargar.
- **[vistas](vistas.md)** (`MuroView`): la cuadrícula de una categoría de Explorar con álbumes.
- **[personalizacion](personalizacion.md)** (`AppSettings.opcion`): las opciones `fichasAlbum` y `fichasPlaylist`.
- **[interfaz-comun](interfaz-comun.md)** (`SongTile`, `WheelScroll`, `Cover`, botones): las fichas de canción, la rueda y las piezas de la cabecera.
- **La usan:** [ventana](ventana.md).

## Estado actual

- **Última verificación:** 2026-11-21, halo sin recortar y fichas por separado en álbumes y playlists ([historial](../history/verificacion/detalle.md)).
- **Pruebas:** capturas con `--autoplay --open`, `--related ID`, `--shuffle`, `--detail-at y` e `--inspect flip|open|disc`
  ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** la cuadrícula de canciones con el teclado de verdad y en una ventana
  estrecha; la cuadrícula de una categoría con la rueda de verdad y en una ventana
  estrecha; la cabecera del artista en una ventana estrecha (1120 px) y en Linux; bajar
  con la rueda o el trackpad de verdad (la rueda simulada solo mueve la primera muesca); un artista
  con menos de tres canciones.
- **Historial:** [docs/history/verificacion/detalle.md](../history/verificacion/detalle.md).
