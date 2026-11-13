import QtQuick
import app.musicplayer

// Campo de búsqueda en píldora de vidrio.
Glass {
    id: root

    readonly property bool editing: input.activeFocus

    signal submitted(string query)
    signal dismissed()

    function edit() {
        input.forceActiveFocus()
        input.selectAll()
    }

    implicitHeight: Theme.hit
    radius: height / 2

    Icon {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        path: Theme.iconSearch
        size: 18
        color: Theme.textMuted
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 42
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.pixelSize: 14
        clip: true
        selectByMouse: true
        selectionColor: Theme.controlActive
        activeFocusOnTab: true

        Accessible.name: "Buscar"

        onAccepted: root.submitted(text)
        Keys.onEscapePressed: root.dismissed()

        Text {
            anchors.fill: parent
            visible: input.text === ""
            text: "Buscar"
            color: Theme.textMuted
            font: input.font
            verticalAlignment: Text.AlignVCenter
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.text
    }

    HoverHandler { cursorShape: Qt.IBeamCursor }

    TapHandler {
        onTapped: root.edit()
    }
}
