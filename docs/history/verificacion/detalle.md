# Historial de verificación · Detalle e inspeccionar

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/detalle.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-21 · Canciones en cuadrícula y opción `fichas` (en `master`)

- **Cambio:** la lista de canciones del detalle pasa a ser una cuadrícula de fichas pequeñas
  (`SongTile`, ~110 px, título debajo) en filas de una `ListView`. El artista la tiene bajo
  «Órbita», a todo el ancho; álbumes y playlists, a la derecha de su carátula. Opción `fichas`:
  número en grande sobre el color de la carátula (por defecto) o carátula con el número en la
  esquina. Flechas izquierda y derecha. La rueda con `WheelScroll`.
- **Cómo:** `--shot` (release, `HOME` de pruebas, `MUSICPLAYER_SILENT=1`): Bad Bunny por
  `--search … --autoplay --open` (arriba, y con 3 muescas de rueda simulada: baja 360 px); su
  playlist «UN VERANO SIN TI» abierta con un clic simulado en los dos modos de `fichas`; un
  single de Inicio (Lomos, `--index 8`); categorías de Explorar con canciones y con álbumes.
- **Resultado:** 12 columnas en el artista y 7 junto a la carátula (1440 px); números del 1 al 23
  sobre el color de la carátula, o carátulas con el número; sin avisos de QML.
- **No verificado:** teclado y ratón de verdad; ventana estrecha; Linux; un álbum de verdad con
  muchas pistas.

## 2026-11-21 · Categoría de Explorar con el Muro de Inicio (en `master`)

- **Cambio:** una categoría de Explorar con álbumes o listas se recorre con `MuroView` (un clic
  elige con aro y brillo, el nombre sale abajo, el doble la abre; o lo que diga la opción `clic`).
- **Cómo:** `--shot` (release, `HOME` de pruebas, `explorarFuente` = `youtube`) con `--section
  explorar --index 1 --autoplay --open`, en «Doble clic» y en «Un clic» con el ratón sobre la
  segunda carátula (`MUSICPLAYER_DEBUG_CLICK` con `wheel` de 0 pasos).
- **Resultado:** la primera elegida con su aro entero; con «Un clic», el nombre de abajo es el de
  la carátula bajo el ratón.
- **No verificado:** abrir un álbum con el clic de verdad; las flechas del teclado en la cuadrícula.

## 2026-11-21 · Interfaz unificada: `TrackRow`, opción `clic` y «Volver» de Inspeccionar (en `master`)

- **Cambio:** filas con `TrackRow` (56 px, la que suena con título en acento y ▸, la elegida en
  vidrio claro); un clic elige o hace sonar según `clic`; título del álbum `fontTitle`, nombre del
  artista `fontDisplay`; discografía con artistas en círculo; Inspeccionar con el botón «Volver»
  arriba a la izquierda en lugar de la píldora «Salir Esc»
  ([ADR-23](../../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)).
- **Cómo:** 29 capturas con `--shot` (release, `HOME` de pruebas, `MUSICPLAYER_SILENT=1`, macOS Retina 1440×900, sin sesión), revisadas a ojo, sin errores de QML en la salida: detalle de Recomendados (Vidrio y Grafito), artista «Aimer», Relacionado e
  Inspeccionar (`--inspect open`).
- **Resultado:** la primera fila sale elegida en vidrio claro; Grafito redondea apenas la carátula.
- **No verificado:** el clic y el doble clic con el ratón de verdad en las dos opciones de `clic`.

## 2026-11-21 · Categorías de Explorar como detalle (en `master`)

- **Cambio:** `DetailView.zona` (`kind` "zona"): canciones en la lista con Reproducir y Aleatorio,
  o los elementos en una cuadrícula que llena el ancho; sin inspeccionar. Las tarjetas de las
  tiras y de la cuadrícula son un componente (`ZoneCard`).
- **Verificado:** capturas de «Recomendados» (lista de 20) y de «Álbumes y singles nuevos»
  (24 álbumes en 5 columnas), y de «Relacionado» bajado hasta sus tiras (sin cambios a la vista).
- **No verificado:** la cuadrícula con la rueda de verdad, en una ventana estrecha y en Linux.

## 2026-11-21 · Página «Relacionado» (en `master`)

- **Cambio:** `DetailView.related`: título «También te puede interesar» sobre las canciones y sin
  el botón de inspeccionar.
- **Verificado:** capturas desde el clic derecho en la primera tarjeta de Inicio (cabecera,
  canciones, Reproducir y Aleatorio) y con `--related 3qmkPx8R--Y --detail-at 3000` (los tres
  carruseles).
- **No verificado:** abrir una lista o un artista desde sus carruseles; Linux.

## 2026-11-18 · Vista de artista «Órbita» (rama `feature/artista-y-ecualizador`)

- **Cambio:** `ArtistHero.qml` (foto, anillo de rayas del color de la foto y tres canciones
  flotando); con un artista, la lista ocupa todo el ancho, lleva la cabecera y sus filas van
  centradas (`inset`); fuera la máscara circular de la carátula (ya no hace falta); argumento
  `--detail-at` de depuración.
- **Verificado:** capturas de Luis Fonsi y Daddy Yankee (el anillo cambia de color con la foto),
  bajando 700 px (canciones) y hasta el final (discografía); un álbum sigue igual; pulsar la
  primera tarjeta deja `sonando true` con las 50 canciones en la cola. Memoria igual con y sin la
  cabecera (290 / 287–290 MB).
- **No verificado:** ventana estrecha; Linux; rueda o trackpad reales.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
