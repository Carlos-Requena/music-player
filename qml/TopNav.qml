import QtQuick
import app.musicplayer

// Navegación principal: pestañas en píldora, como en la dirección "Escenario".
Glass {
    id: root

    property string current: "inicio"
    signal selected(string section)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.hit + 8
    radius: height / 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Catalog.sections

            Item {
                id: tab
                required property var modelData
                readonly property bool active: modelData.id === root.current

                width: label.implicitWidth + 32
                height: Theme.hit
                activeFocusOnTab: true

                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.onPressAction: root.selected(modelData.id)
                Keys.onReturnPressed: root.selected(modelData.id)

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: tab.active ? Theme.text : (tabHover.hovered ? Theme.control : "transparent")
                    border.width: tab.activeFocus ? 2 : 0
                    border.color: Theme.text

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: tab.active ? Theme.ground : Theme.textMuted
                    font.pixelSize: 14
                    font.weight: tab.active ? Font.DemiBold : Font.Normal
                }

                HoverHandler {
                    id: tabHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.selected(tab.modelData.id)
                }
            }
        }
    }
}
