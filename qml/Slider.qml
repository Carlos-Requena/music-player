import QtQuick
import app.musicplayer

// Deslizador horizontal: `value` va de 0 a 1 y `moved` avisa al arrastrar o pulsar.
Item {
    id: root

    property real value: 0
    property string label
    property color fill: Theme.accent
    // Lo que mueve cada flecha del teclado (0–1).
    property real stepSize: 0.05

    signal moved(real value)

    // Parte rellena tal como se dibuja, en píxeles enteros: la posición de la canción cambia diez
    // veces por segundo y, mientras no avance un píxel, la barra no cambia y no se redibuja.
    readonly property real drawn: width > 0 ? Math.round(Math.max(0, Math.min(1, value)) * width) / width : 0

    implicitHeight: 20
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: label

    Keys.onLeftPressed: root.moved(Math.max(0, root.value - root.stepSize))
    Keys.onRightPressed: root.moved(Math.min(1, root.value + root.stepSize))

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.22)

        Rectangle {
            width: parent.width * root.drawn
            height: parent.height
            radius: height / 2
            color: root.fill
        }
    }

    Rectangle {
        x: root.width * root.drawn - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: width / 2
        color: Theme.text

        FocusRing {
            shown: root.activeFocus
            corner: width / 2
        }
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
