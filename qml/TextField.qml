import QtQuick
import app.musicplayer

// Campo de texto de una línea con etiqueta accesible. `committed` se emite al pulsar Intro
// o al salir del campo.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property bool secret: false

    signal committed(string text)

    function forceFocus() {
        input.forceActiveFocus()
        input.selectAll()
    }

    implicitHeight: Theme.hit
    radius: Theme.radiusM
    color: Theme.well
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.text : Theme.glassBorder

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.pixelSize: Theme.fontBase
        clip: true
        selectByMouse: true
        selectionColor: Theme.controlActive
        activeFocusOnTab: true
        echoMode: root.secret ? TextInput.Password : TextInput.Normal

        Accessible.name: root.placeholder

        onAccepted: root.committed(text)
        onActiveFocusChanged: if (!activeFocus) root.committed(text)

        Text {
            anchors.fill: parent
            visible: input.text === "" && !input.activeFocus
            text: root.placeholder
            color: Theme.textFaint
            font: input.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    HoverHandler { cursorShape: Qt.IBeamCursor }
}
