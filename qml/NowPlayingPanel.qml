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
        visible: Player.title !== ""

        Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: [
                    { id: "letra", label: "Letra" },
                    { id: "cola", label: "Cola" }
                ]

                Item {
                    id: tabButton
                    required property var modelData
                    readonly property bool chosen: modelData.id === root.tab

                    width: (tabs.width - 12) / 2
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
        }
    }
}
