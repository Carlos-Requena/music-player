import QtQuick
import app.musicplayer

// Aviso de una pantalla o una lista vacía: icono, frase y, si hace falta, un botón (por ejemplo
// «Iniciar sesión»). El mismo en las secciones, la búsqueda, la temporal y la letra (ADR-23).
Column {
    id: root

    property string icon: ""
    property string text
    // Texto del botón; vacío, sin botón.
    property string action: ""
    property string actionIcon: ""

    signal triggered()

    spacing: 14

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.icon !== ""
        path: root.icon
        size: 28
        color: Theme.textFaint
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.text
        color: Theme.textMuted
        font.pixelSize: Theme.fontBody
        lineHeight: 1.2
    }

    PillButton {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.action !== ""
        text: root.action
        icon: root.actionIcon
        primary: true
        onClicked: root.triggered()
    }
}
