import QtQuick
import app.musicplayer

// Detalle de un álbum, playlist o artista: carátula, datos, botones de reproducir y
// aleatorio, y la lista de canciones. Un artista ocupa todo el ancho: arriba su cabecera
// «Órbita» (`ArtistHero`) y, al bajar, sus canciones y su discografía.
FocusScope {
    id: root

    readonly property var detail: Catalog.detalle
    readonly property var tracks: detail ? (detail.tracks || []) : []
    // Al llegar las canciones se resuelven las primeras: así la que elijas suena al momento,
    // también las que YouTube solo da con sesión (que tardan ~2 s en resolverse).
    onTracksChanged: if (tracks.length) Player.prefetchTracks(JSON.stringify(tracks.slice(0, 6)), 6)
    readonly property var zonas: detail ? (detail.zonas || []) : []
    readonly property bool artist: detail !== null && detail.kind === "artist"
    // «Relacionado» de una canción: sus canciones parecidas se reproducen como un álbum y debajo
    // van listas, artistas similares y más del artista.
    readonly property bool related: detail !== null && detail.kind === "related"
    // Categoría de Explorar (`Library.openZona`): canciones en la lista o elementos en cuadrícula.
    readonly property bool zona: detail !== null && detail.kind === "zona"
    readonly property real totalSeconds: tracks.reduce((sum, track) => sum + (track.duration || 0), 0)
    property int current: 0
    // Color dominante de la foto o carátula (la sonda de la ventana).
    property color tint: Theme.neutralTint
    // Margen lateral de la cuadrícula: en un artista, el de la ventana; en lo demás, el hueco
    // para que la ficha elegida crezca sin que se corte su aro.
    readonly property real inset: artist ? Theme.margin : Math.ceil(tileTarget * 0.03) + Theme.cursorWidth + 6

    // Cuadrícula de fichas pequeñas (`SongTile`): tantas columnas de ~110 px como quepan.
    readonly property real tileTarget: 110
    readonly property real tileGap: 16
    readonly property int columns: Math.max(1, Math.floor((list.width - 2 * inset + tileGap) / (tileTarget + tileGap)))
    readonly property real tileSide: Math.floor((list.width - 2 * inset - (columns - 1) * tileGap) / columns)
    // Filas de `columns` canciones, con el índice de la primera de cada una.
    readonly property var tileRows: {
        const out = []
        for (let i = 0; i < tracks.length; i += columns)
            out.push({ first: i, items: tracks.slice(i, i + columns) })
        return out
    }
    // Álbum o playlist: número de pista en la ficha, en grande sobre su color o en la esquina de
    // la carátula (opción `fichas`). Un artista, «Relacionado» o una categoría no llevan número.
    readonly property bool numbered: !artist && !related && !zona
    readonly property bool numberOnly: numbered && AppSettings.opcion("fichas", AppSettings.revision) !== "caratula"

    signal closed()
    signal inspect()
    signal opened(var item)

    function play(index, shuffle) {
        if (tracks.length)
            Player.playTracks(JSON.stringify(tracks), index, shuffle)
    }

    // Baja la lista `y` píxeles desde arriba (depuración: `--detail-at`).
    function scrollTo(y) {
        list.contentY = list.originY + Math.min(y, Math.max(0, list.contentHeight - list.height))
    }

    function step(delta) {
        if (tracks.length)
            current = Math.max(0, Math.min(tracks.length - 1, current + delta))
    }

    onDetailChanged: {
        current = 0
        list.positionViewAtBeginning()
    }

    Keys.onEscapePressed: root.closed()
    Keys.onUpPressed: step(-columns)
    Keys.onDownPressed: step(columns)
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: play(current, false)
    Keys.onEnterPressed: play(current, false)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_S) {
            play(0, true)
            event.accepted = true
        } else if (event.key === Qt.Key_I && !root.artist && !root.related && !root.zona) {
            root.inspect()
            event.accepted = true
        }
    }

    // El velo que lo separa del escenario está en `Main.qml`: cubre toda la ventana.

    // Absorbe clics para que no lleguen a la vista de debajo.
    TapHandler { acceptedButtons: Qt.AllButtons; gesturePolicy: TapHandler.ReleaseWithinBounds }

    readonly property real coverSide: Math.min(360, height * 0.5, width * 0.32)

    // Separada de la navegación de arriba para que no parezca pegada a ella. Va encima de la
    // lista, que en un artista empieza arriba del todo.
    IconButton {
        z: 2
        x: Theme.margin
        y: 20
        icon: Theme.iconBack
        label: "Volver"
        solid: true
        onClicked: root.closed()
    }

    Column {
        id: info
        visible: !root.artist
        x: Theme.margin
        y: 84
        width: root.coverSide
        spacing: 14

        Cover {
            width: root.coverSide
            height: root.coverSide
            thumb: root.detail ? root.detail.thumb : ""
            pixels: 544
            radius: Theme.coverRadius(width)
        }

        Text {
            width: parent.width
            text: root.detail ? root.detail.title : ""
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: {
                const parts = []
                if (root.detail && root.detail.subtitle)
                    parts.push(root.detail.subtitle)
                if (root.tracks.length)
                    parts.push(root.tracks.length + (root.tracks.length === 1 ? " canción" : " canciones")
                               + (root.totalSeconds > 0 ? " · " + Math.round(root.totalSeconds / 60) + " min" : ""))
                return parts.join(" · ")
            }
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: 10

            PillButton {
                text: "Reproducir"
                icon: Theme.iconPlay
                primary: true
                enabled: root.tracks.length > 0
                onClicked: root.play(0, false)
            }

            PillButton {
                text: "Aleatorio"
                icon: Theme.iconShuffle
                enabled: root.tracks.length > 0
                onClicked: root.play(0, true)
            }

            IconButton {
                visible: !root.artist && !root.related && !root.zona
                icon: Theme.iconInspect
                label: "Inspeccionar"
                solid: true
                onClicked: root.inspect()
            }
        }
    }

    // Categoría de Explorar sin canciones (álbumes, listas): el mismo Muro que Inicio, con el
    // nombre de la elegida abajo; abrir una la lleva a su detalle.
    readonly property bool wall: root.zona && root.tracks.length === 0 && root.zonas.length > 0

    Loader {
        id: wallLoader
        // Medio margen de más a cada lado: la elegida crece y su aro no se corta.
        x: list.x - Theme.margin / 2
        y: 84
        width: list.width + Theme.margin
        height: root.height - y
        active: root.wall
        focus: active
        sourceComponent: MuroView {
            focus: true
            margin: Theme.margin / 2
            // Sin el nombre de la zona: ya está a la izquierda.
            zonas: root.zonas.map(zona => Object.assign({}, zona, { titulo: "" }))
            onActivated: item => root.opened(item)
        }
    }

    ListView {
        id: list
        visible: !root.wall
        x: root.artist ? 0 : info.x + info.width + Theme.margin
        width: root.artist ? root.width : root.width - x - Theme.margin
        y: root.artist ? 0 : 84
        height: root.height - y
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Una fila de fichas por elemento: solo existen las filas a la vista y unas pocas más.
        model: root.tileRows
        currentIndex: Math.floor(root.current / root.columns)
        spacing: 18
        cacheBuffer: Math.max(0, Math.round(root.tileSide * 3))

        WheelScroll { view: list }

        header: Column {
            width: list.width

            // Solo existe con un artista: así un álbum no paga su anillo ni sus tarjetas.
            Loader {
                width: list.width
                height: active ? Math.max(560, list.height - 40) : 0
                active: root.artist
                sourceComponent: ArtistHero {
                    detail: root.detail
                    tracks: root.tracks
                    tint: root.tint
                    onPlay: (index, shuffle) => root.play(index, shuffle)
                }
            }

            SectionLabel {
                x: root.inset + 8
                visible: (root.artist || root.related) && root.tracks.length > 0
                height: visible ? 44 : 0
                text: root.related ? "También te puede interesar" : "Canciones"
            }

            Text {
                x: root.inset + 8
                visible: Library.detalleLoading && root.tracks.length === 0
                height: visible ? 48 : 0
                text: "Cargando canciones…"
                color: Theme.textMuted
                font.pixelSize: Theme.fontBase
            }
        }

        // La lista pone cada delegado en x = 0: el margen va dentro, en la `Row` (TRAMPAS).
        delegate: Item {
            id: tileRow
            required property var modelData
            required property int index

            width: list.width
            height: tiles.y + tiles.height

            Row {
                id: tiles
                x: root.inset
                // Hueco arriba en la primera fila: la elegida crece y su aro no debe cortarse.
                y: tileRow.index === 0 ? 10 : 0
                spacing: root.tileGap

                Repeater {
                    model: tileRow.modelData.items

                    SongTile {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property int track: tileRow.modelData.first + index

                        side: root.tileSide
                        title: modelData.title
                        artist: modelData.artist
                        thumb: modelData.thumb || ""
                        number: root.numbered ? track + 1 : 0
                        numberOnly: root.numberOnly
                        tint: root.tint
                        playing: Player.queue !== "" && Player.title === modelData.title && Player.artist === modelData.artist
                        chosen: track === root.current

                        Accessible.onPressAction: root.play(track, false)

                        // Clic derecho: menú con «Añadir a la lista temporal».
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: eventPoint => tile.Window.window.openMenu(tile.modelData, eventPoint.scenePosition)
                        }

                        // Un clic elige o hace sonar según la opción `clic`; el doble, siempre suena.
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                root.current = tile.track
                                root.forceActiveFocus()
                                if (Theme.singleClick && tapCount === 1)
                                    root.play(tile.track, false)
                            }
                            onDoubleTapped: if (!Theme.singleClick) root.play(tile.track, false)
                        }
                    }
                }
            }
        }

        // Discografía de un artista: filas de carátulas bajo sus canciones. Una categoría de
        // Explorar sin canciones llena el ancho con una cuadrícula (su nombre ya está a la izquierda).
        footer: Column {
            x: root.inset
            width: list.width - 2 * root.inset
            topPadding: root.zonas.length && !root.zona ? 28 : 0
            bottomPadding: root.artist ? 40 : 0
            spacing: 22

            Repeater {
                model: root.zonas

                Column {
                    id: zone
                    required property var modelData
                    width: parent.width
                    spacing: 10

                    SectionLabel {
                        x: 8
                        visible: !root.zona
                        text: zone.modelData.titulo
                    }

                    Flickable {
                        visible: !root.zona
                        width: parent.width
                        height: visible ? 190 : 0
                        contentWidth: strip.width
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: strip
                            spacing: 16

                            Repeater {
                                model: root.zona ? [] : zone.modelData.items
                                ZoneCard { side: 150 }
                            }
                        }
                    }

                    // Cuadrícula de una categoría: tantas columnas de ~170 px como quepan.
                    Flow {
                        id: wall
                        visible: root.zona
                        width: parent.width
                        spacing: 18
                        readonly property int columns: Math.max(1, Math.floor((width + spacing) / (170 + spacing)))
                        readonly property real side: Math.floor((width - (columns - 1) * spacing) / columns)

                        Repeater {
                            model: root.zona ? zone.modelData.items : []
                            ZoneCard { side: wall.side }
                        }
                    }
                }
            }
        }
    }

    // Tarjeta de una zona: carátula y título; clic para abrirla, clic derecho para su menú.
    component ZoneCard: Column {
        id: card
        required property var modelData
        property real side: 150
        width: side
        spacing: 6

        Accessible.role: Accessible.Button
        Accessible.name: modelData.title

        // Los artistas, siempre en círculo.
        Cover {
            width: card.side
            height: card.side
            thumb: card.modelData.thumb
            radius: card.modelData.kind === "artist" ? width / 2 : Theme.coverRadius(width)
        }

        Text {
            width: parent.width
            horizontalAlignment: card.modelData.kind === "artist" ? Text.AlignHCenter : Text.AlignLeft
            text: card.modelData.title
            color: Theme.text
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        // Clic derecho: menú con «Añadir a la lista temporal».
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: eventPoint => card.Window.window.openMenu(card.modelData, eventPoint.scenePosition)
        }

        TapHandler {
            onTapped: root.opened(card.modelData)
        }
    }
}
