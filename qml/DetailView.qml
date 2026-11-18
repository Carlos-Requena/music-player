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
    readonly property real totalSeconds: tracks.reduce((sum, track) => sum + (track.duration || 0), 0)
    property int current: 0
    // Color dominante de la foto o carátula (la sonda de la ventana).
    property color tint: "#3A3F4B"
    // Margen lateral de las filas: en un artista, la lista va centrada y con un ancho cómodo.
    readonly property real inset: artist ? Math.max(40, (width - 1000) / 2) : 0

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
    Keys.onUpPressed: step(-1)
    Keys.onDownPressed: step(1)
    Keys.onReturnPressed: play(current, false)
    Keys.onEnterPressed: play(current, false)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_S) {
            play(0, true)
            event.accepted = true
        } else if (event.key === Qt.Key_I && !root.artist) {
            root.inspect()
            event.accepted = true
        }
    }

    // Velo sobre el escenario: deja ver el modo ambiente pero separa el detalle del fondo.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.035, 0.05, 0.62)
    }

    // Absorbe clics para que no lleguen a la vista de debajo.
    TapHandler { acceptedButtons: Qt.AllButtons; gesturePolicy: TapHandler.ReleaseWithinBounds }

    readonly property real coverSide: Math.min(360, height * 0.5, width * 0.32)

    // Separada de la navegación de arriba para que no parezca pegada a ella. Va encima de la
    // lista, que en un artista empieza arriba del todo.
    IconButton {
        z: 2
        x: 40
        y: 20
        icon: Theme.iconBack
        label: "Volver"
        solid: true
        onClicked: root.closed()
    }

    Column {
        id: info
        visible: !root.artist
        x: 40
        y: 84
        width: root.coverSide
        spacing: 14

        Cover {
            width: root.coverSide
            height: root.coverSide
            thumb: root.detail ? root.detail.thumb : ""
            pixels: 544
        }

        Text {
            width: parent.width
            text: root.detail ? root.detail.title : ""
            color: Theme.text
            font.pixelSize: 30
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
            font.pixelSize: 13
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
                visible: !root.artist
                icon: Theme.iconInspect
                label: "Inspeccionar"
                solid: true
                onClicked: root.inspect()
            }
        }
    }

    ListView {
        id: list
        x: root.artist ? 0 : info.x + info.width + 40
        width: root.artist ? root.width : root.width - x - 32
        y: root.artist ? 0 : 84
        height: root.height - y
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.tracks
        currentIndex: root.current

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

            Text {
                x: root.inset + 14
                visible: root.artist && root.tracks.length > 0
                height: visible ? 44 : 0
                text: "Canciones"
                color: Theme.textMuted
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.7
                font.capitalization: Font.AllUppercase
            }

            Text {
                x: root.inset
                visible: Library.detalleLoading && root.tracks.length === 0
                height: visible ? 48 : 0
                text: "Cargando canciones…"
                color: Theme.textMuted
                font.pixelSize: 14
            }
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool playing: Player.queue !== "" && Player.title === modelData.title && Player.artist === modelData.artist
            readonly property bool focused: index === root.current

            width: list.width
            height: 52

            Accessible.role: Accessible.Button
            Accessible.name: modelData.title + ", " + modelData.artist
            Accessible.onPressAction: root.play(index, false)

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: root.inset
                anchors.rightMargin: root.inset
                radius: 10
                color: row.focused ? Theme.controlActive : (rowHover.hovered ? Theme.control : "transparent")
            }

            Text {
                x: root.inset + 14
                width: 28
                anchors.verticalCenter: parent.verticalCenter
                text: row.playing ? "▸" : (row.index + 1)
                color: row.playing ? Theme.accent : Theme.textMuted
                font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
            }

            Column {
                x: root.inset + 58
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 58 - 70 - 2 * root.inset
                spacing: 1

                Text {
                    width: parent.width
                    text: row.modelData.title
                    color: row.playing ? Theme.accent : Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.detail && root.detail.kind !== "album"
                    text: row.modelData.artist
                    color: Theme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.inset + 14
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.duration > 0 ? Theme.mmss(row.modelData.duration) : ""
                color: Theme.textMuted
                font.pixelSize: 13
            }

            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
            }

            // Clic derecho: menú con «Añadir a la lista temporal».
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: eventPoint => row.Window.window.openMenu(row.modelData, eventPoint.scenePosition)
            }

            TapHandler {
                onTapped: {
                    root.current = row.index
                    root.forceActiveFocus()
                }
                onDoubleTapped: root.play(row.index, false)
            }
        }

        // Discografía de un artista: filas de carátulas bajo sus canciones.
        footer: Column {
            x: root.inset
            width: list.width - 2 * root.inset
            topPadding: root.zonas.length ? 28 : 0
            bottomPadding: root.artist ? 40 : 0
            spacing: 22

            Repeater {
                model: root.zonas

                Column {
                    id: zone
                    required property var modelData
                    width: parent.width
                    spacing: 10

                    Text {
                        text: zone.modelData.titulo
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.7
                        font.capitalization: Font.AllUppercase
                    }

                    Flickable {
                        width: parent.width
                        height: 190
                        contentWidth: strip.width
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: strip
                            spacing: 16

                            Repeater {
                                model: zone.modelData.items

                                Column {
                                    id: card
                                    required property var modelData
                                    width: 150
                                    spacing: 6

                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.title

                                    Cover {
                                        width: 150
                                        height: 150
                                        thumb: card.modelData.thumb
                                    }

                                    Text {
                                        width: parent.width
                                        text: card.modelData.title
                                        color: Theme.text
                                        font.pixelSize: 13
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
                        }
                    }
                }
            }
        }
    }
}
