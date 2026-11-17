import QtQuick
import app.musicplayer

// Pestañas en una cápsula (panel lateral y «Sonando»): `tabs` es `[{ id, label }]`, `current` el
// id elegido y `picked(id)` avisa al pulsar una (o con Intro, con el foco en ella).
Rectangle {
    id: root

    property var tabs: []
    property string current: ""
    property int fontSize: 14
    property real innerRadius: 10

    signal picked(string id)

    height: Theme.hit + 8
    radius: innerRadius + 4
    color: Qt.rgba(0, 0, 0, 0.25)

    Row {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.tabs

            Item {
                id: tab
                required property var modelData
                readonly property bool chosen: modelData.id === root.current

                width: (root.width - 8 - 4 * (root.tabs.length - 1)) / Math.max(1, root.tabs.length)
                height: Theme.hit
                activeFocusOnTab: true

                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.onPressAction: root.picked(modelData.id)
                Keys.onReturnPressed: root.picked(modelData.id)

                Rectangle {
                    anchors.fill: parent
                    radius: root.innerRadius
                    color: tab.chosen ? Theme.controlActive : (hover.hovered ? Theme.control : "transparent")
                    border.width: tab.activeFocus ? 2 : 0
                    border.color: Theme.text
                }

                Text {
                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: tab.chosen ? Theme.text : Theme.textMuted
                    font.pixelSize: root.fontSize
                    font.weight: tab.chosen ? Font.DemiBold : Font.Normal
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.picked(tab.modelData.id)
                }
            }
        }
    }
}
