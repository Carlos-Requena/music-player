import QtQuick
import app.musicplayer

// Botón de icono con área táctil de 44 px, foco por teclado y nombre accesible.
Item {
    id: root

    property string icon
    property string label
    property bool filled: false
    property bool active: false
    property bool solid: false
    property real iconSize: 20
    property color background: active ? Theme.text : (solid || hover.hovered ? Theme.control : "transparent")
    property color foreground: active ? Theme.ground : Theme.text

    signal clicked()

    implicitWidth: Theme.hit
    implicitHeight: Theme.hit
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: root.clicked()

    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.background
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.text

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Icon {
        anchors.centerIn: parent
        path: root.icon
        filled: root.filled
        size: root.iconSize
        color: root.foreground
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    // Agarre exclusivo al pulsar: el clic no llega a lo que haya debajo (sin esto, cerrar
    // «Sonando» con su flecha pulsaba también el botón de opciones, en el mismo sitio).
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }
}
