import QtQuick
import app.musicplayer

// Panel derecho del estilo "Vidrio": carátula, título y letra de lo que suena.
Glass {
    id: root

    readonly property real pad: 16

    Cover {
        id: cover
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: width
        art: Player.cover
    }

    Column {
        id: heading
        anchors.top: cover.bottom
        anchors.topMargin: 14
        x: root.pad
        width: root.width - 2 * root.pad
        spacing: 2

        Text {
            width: parent.width
            text: Player.title
            color: Theme.text
            font.pixelSize: 24
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Player.artist
            color: Theme.textMuted
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }

    LyricsView {
        anchors.top: heading.bottom
        anchors.topMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        x: root.pad
        width: root.width - 2 * root.pad
    }
}
