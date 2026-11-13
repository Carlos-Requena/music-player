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
            font.pixelSize: 24
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Player.artist
            color: Theme.textMuted
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        // Formato real del audio, informado por mpv.
        Text {
            visible: Player.calidad !== ""
            text: Player.calidad
            color: Theme.textFaint
            font.pixelSize: 11
            font.letterSpacing: 0.8
            font.capitalization: Font.AllUppercase
        }
    }

    Rectangle {
        id: tabs
        anchors.top: heading.bottom
        anchors.topMargin: 14
        x: root.pad
        width: root.width - 2 * root.pad
        height: Theme.hit + 8
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.25)
        visible: Player.title !== "" || Catalog.temporal.length > 0

        Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: [
                    { id: "letra", label: "Letra" },
                    { id: "cola", label: "Cola" },
                    { id: "temporal", label: "Temporal" + (Catalog.temporal.length ? " · " + Catalog.temporal.length : "") }
                ]

                Item {
                    id: tabButton
                    required property var modelData
                    readonly property bool chosen: modelData.id === root.tab

                    width: (tabs.width - 16) / 3
                    height: Theme.hit
                    activeFocusOnTab: true

                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.onPressAction: root.tab = modelData.id
                    Keys.onReturnPressed: root.tab = modelData.id

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: tabButton.chosen ? Theme.controlActive : (tabHover.hovered ? Theme.control : "transparent")
                        border.width: tabButton.activeFocus ? 2 : 0
                        border.color: Theme.text
                    }

                    Text {
                        anchors.centerIn: parent
                        text: tabButton.modelData.label
                        color: tabButton.chosen ? Theme.text : Theme.textMuted
                        font.pixelSize: 14
                        font.weight: tabButton.chosen ? Font.DemiBold : Font.Normal
                    }

                    HoverHandler {
                        id: tabHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.tab = tabButton.modelData.id
                    }
                }
            }
        }
    }

    LyricsView {
        visible: root.tab === "letra"
        anchors.top: tabs.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        x: root.pad
        width: root.width - 2 * root.pad
    }

    ListView {
        id: queue
        visible: root.tab === "cola"
        anchors.top: tabs.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        x: root.pad
        width: root.width - 2 * root.pad
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Catalog.queue

        // Mantiene a la vista la pista que suena.
        function follow() {
            positionViewAtIndex(Player.index, ListView.Contain)
        }
        onVisibleChanged: if (visible) follow()
        Connections {
            target: Player
            function onIndexChanged() { queue.follow() }
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: index === Player.index

            width: queue.width
            height: 56

            Accessible.role: Accessible.Button
            Accessible.name: modelData.title + ", " + modelData.artist
            Accessible.onPressAction: Player.playIndex(index)

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: row.current ? Theme.controlActive : (rowHover.hovered ? Theme.control : "transparent")
            }

            Cover {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                thumb: row.modelData.thumb
                pixels: 120
            }

            Column {
                x: 58
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 58 - 52
                spacing: 1

                Text {
                    width: parent.width
                    text: row.modelData.title
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: row.current ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: row.modelData.artist
                    color: Theme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.mmss(row.modelData.duration)
                color: Theme.textMuted
                font.pixelSize: 12
            }

            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Player.playIndex(row.index)
            }

            // Clic derecho: menú con «Añadir a la lista temporal».
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: eventPoint => row.Window.window.openMenu(row.modelData, eventPoint.scenePosition)
            }
        }
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

        Text {
            visible: Catalog.temporal.length === 0
            width: parent.width
            topPadding: 18
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Haz clic derecho en una canción, un álbum o una playlist y elige «Añadir a la lista temporal» para escucharlas juntas en bucle."
            color: Theme.textMuted
            font.pixelSize: 14
            lineHeight: 1.2
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

            delegate: Item {
                id: entry
                required property var modelData
                required property int index

                width: temporalList.width
                height: 56

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title + ", " + modelData.artist
                Accessible.onPressAction: Player.playTemporal(index)

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: entryHover.hovered ? Theme.control : "transparent"
                }

                Cover {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    thumb: entry.modelData.thumb
                    pixels: 120
                }

                Column {
                    x: 58
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 58 - Theme.hit - 6
                    spacing: 1

                    Text {
                        width: parent.width
                        text: entry.modelData.title
                        color: Theme.text
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: entry.modelData.artist
                        color: Theme.textMuted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: entryHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Player.playTemporal(entry.index)
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
