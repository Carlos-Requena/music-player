import QtQuick
import app.musicplayer

// Deslizador horizontal: `value` va de 0 a 1 y `moved` avisa al arrastrar o pulsar.
Item {
    id: root

    property real value: 0
    property string label
    property color fill: Theme.accent

    signal moved(real value)

    implicitHeight: 20
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: label

    Keys.onLeftPressed: root.moved(Math.max(0, root.value - 0.05))
    Keys.onRightPressed: root.moved(Math.min(1, root.value + 0.05))

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.22)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 2
            color: root.fill
        }
    }

    Rectangle {
        x: root.width * Math.max(0, Math.min(1, root.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: 6
        color: Theme.text
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.PointingHandCursor

        function report(mouse) {
            root.moved(Math.max(0, Math.min(1, (mouse.x - 8) / root.width)))
        }

        onPressed: mouse => report(mouse)
        onPositionChanged: mouse => report(mouse)
    }
}
