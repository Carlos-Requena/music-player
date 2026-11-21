import QtQuick
import app.musicplayer

// Nombre y subtítulo del elemento enfocado, iguales en el Muro, Lomos y Cubeta (ADR-23).
Column {
    id: root

    property var item: null
    property int alignment: Text.AlignHCenter
    // Líneas del nombre (Cubeta lo deja partirse en tres).
    property int lines: 1

    spacing: 6

    Text {
        width: parent.width
        horizontalAlignment: root.alignment
        text: root.item ? root.item.title : ""
        color: Theme.text
        font.pixelSize: Theme.fontDisplay
        font.weight: Font.Bold
        font.letterSpacing: Theme.displaySpacing
        wrapMode: root.lines > 1 ? Text.WordWrap : Text.NoWrap
        maximumLineCount: root.lines
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        horizontalAlignment: root.alignment
        text: root.item ? root.item.subtitle : ""
        color: Theme.textMuted
        font.pixelSize: Theme.fontBody
        elide: Text.ElideRight
    }
}
