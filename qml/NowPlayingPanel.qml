import QtQuick
import app.musicplayer

// Panel derecho del estilo "Vidrio": carátula y título de lo que suena, con su letra o la cola.
Glass {
    id: root

    property string tab: "letra"
    readonly property real pad: 16

    Cover {
        id: cover
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: width
        thumb: Player.thumb
        pixels: 544
        radius: Theme.coverRadius(width)
    }

    Column {
        id: heading
        anchors.top: cover.bottom
        anchors.topMargin: 14
        x: root.pad
        width: root.width - 2 * root.pad
        spacing: 2

        Text {
            width: parent.width
            text: Player.title !== "" ? Player.title : "Elige algo para escuchar"
            color: Theme.text
            font.pixelSize: Theme.fontHeading
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Player.artist
            color: Theme.textMuted
            font.pixelSize: Theme.fontBase
            elide: Text.ElideRight
        }

        // Formato real del audio, informado por mpv.
        SectionLabel {
            visible: Player.calidad !== ""
            topPadding: 4
            text: Player.calidad
            color: Theme.textFaint
        }
    }

    // Pestañas de navegación (regla de dos: lo elegido, en blanco).
    Tabs {
        id: tabs
        anchors.top: heading.bottom
        anchors.topMargin: 14
        x: root.pad
        width: root.width - 2 * root.pad
        visible: Player.title !== "" || Catalog.temporal.length > 0
        navigate: true
        fill: true
        well: true
        current: root.tab
        tabs: [
            { id: "letra", label: "Letra" },
            { id: "cola", label: "Cola" },
            { id: "temporal", label: "Temporal" + (Catalog.temporal.length ? " · " + Catalog.temporal.length : "") }
        ]
        onPicked: id => root.tab = id
    }

    // Con su pie discreto de retraso (`LyricsTiming`), como en «Sonando». Solo existe mientras se
    // ve: una letra con tiempos por sílaba son miles de objetos, y el panel arranca oculto. Se
    // crea poco a poco (`asynchronous`) para no trabar la animación al abrir el panel.
    Loader {
        active: root.visible && root.tab === "letra"
        asynchronous: true
        anchors.top: tabs.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        x: root.pad
        width: root.width - 2 * root.pad
        sourceComponent: LyricsView {}
    }

    QueueList {
        id: queue
        visible: root.tab === "cola"
        anchors.top: tabs.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        x: root.pad
        width: root.width - 2 * root.pad
    }

    // Lista temporal: canciones sueltas reunidas con el clic derecho, para oírlas en bucle.
    Item {
        id: temporal
        visible: root.tab === "temporal"
        anchors.top: tabs.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        x: root.pad
        width: root.width - 2 * root.pad

        EmptyState {
            visible: Catalog.temporal.length === 0
            width: parent.width
            topPadding: 18
            icon: Theme.iconTemporal
            text: "Haz clic derecho en una canción, un álbum o una playlist y elige «Añadir a la lista temporal» para escucharlas juntas en bucle."
        }

        Row {
            id: temporalActions
            visible: Catalog.temporal.length > 0
            spacing: 8

            PillButton {
                text: "Reproducir en bucle"
                icon: Theme.iconRepeat
                primary: true
                onClicked: Player.playTemporal(0)
            }

            PillButton {
                text: "Vaciar"
                onClicked: Player.clearTemporal()
            }
        }

        ListView {
            id: temporalList
            visible: Catalog.temporal.length > 0
            anchors.top: temporalActions.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Catalog.temporal

            WheelScroll { view: temporalList }

            // Elegida con un clic (opción `clic` en «doble»).
            property int chosen: -1

            delegate: TrackRow {
                id: entry
                required property var modelData
                required property int index

                width: temporalList.width
                title: modelData.title
                artist: modelData.artist
                thumb: modelData.thumb
                playing: Player.queue !== "" && Player.title === modelData.title && Player.artist === modelData.artist
                chosen: temporalList.chosen === index
                rightInset: Theme.hit - 6

                Accessible.onPressAction: Player.playTemporal(index)

                // Un clic hace sonar o elige según la opción `clic`; el doble, siempre suena.
                TapHandler {
                    onTapped: {
                        if (!Theme.singleClick)
                            temporalList.chosen = entry.index
                        else if (tapCount === 1)
                            Player.playTemporal(entry.index)
                    }
                    onDoubleTapped: if (!Theme.singleClick) Player.playTemporal(entry.index)
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Theme.iconClose
                    iconSize: 16
                    label: "Quitar «" + entry.modelData.title + "» de la lista temporal"
                    onClicked: Player.removeFromTemporal(entry.index)
                }
            }
        }
    }
}
