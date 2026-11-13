import QtQuick
import app.musicplayer

// Botón con texto en píldora; `primary` lo rellena de blanco.
Item {
    id: root

    property string text
    property string icon: ""
    property bool primary: false

    signal clicked()

    implicitWidth: row.implicitWidth + 40
    implicitHeight: Theme.hit
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) root.clicked()
    Keys.onReturnPressed: if (enabled) root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.primary ? Theme.text : (hover.hovered ? Theme.controlActive : Theme.control)
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            path: root.icon
            filled: root.icon === Theme.iconPlay
            size: 18
            color: root.primary ? Theme.ground : Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.primary ? Theme.ground : Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}
