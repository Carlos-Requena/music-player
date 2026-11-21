import QtQuick
import app.musicplayer

// Fila de canción, la misma en el detalle, la cola (panel y «Sonando») y la temporal (ADR-23).
// Solo dibuja: los gestos los pone quien la usa (la cola, por ejemplo, arrastra para reordenar;
// qué hace un clic lo decide la opción `clic`, ver `Theme.singleClick`). A la izquierda va el
// número (`number` > 0) o la miniatura; la que suena lleva el título en acento y ▸.
Item {
    id: root

    property string title
    property string artist
    property string thumb: ""
    // Mayor que 0: el número de la pista en lugar de la miniatura.
    property int number: 0
    // Duración en segundos (0: sin duración) o un texto en su lugar.
    property real duration: 0
    property string trailing: ""
    property bool showArtist: true
    property bool playing: false
    // Elegida con el clic o el teclado: vidrio claro (regla de dos).
    property bool chosen: false
    // Arrastrándose (cola).
    property bool lifted: false
    property bool hoverEnabled: true
    // Hueco a la derecha para un botón propio (la × de la temporal).
    property real rightInset: 0
    // Bajo el puntero; quien pone su propio `MouseArea` encima (la cola) lo da él.
    property bool hovered: hover.hovered

    implicitHeight: Theme.rowHeight

    Accessible.role: Accessible.Button
    Accessible.name: title + (artist !== "" ? ", " + artist : "")

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusS
        color: root.chosen || root.lifted ? Theme.controlActive
             : (root.hovered && root.hoverEnabled ? Theme.control : "transparent")
        border.width: root.lifted ? 1 : 0
        border.color: Theme.glassBorder
    }

    Text {
        id: numberText
        visible: root.number > 0
        x: 8
        width: 28
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.playing ? "▸" : root.number
        color: root.playing ? Theme.accent : Theme.textMuted
        font.pixelSize: Theme.fontSmall
    }

    Cover {
        id: cover
        visible: root.number <= 0
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.rowCover
        height: Theme.rowCover
        thumb: root.thumb
        pixels: 120
        radius: Theme.coverRadius(width)
    }

    // La que suena, con miniatura: ▸ sobre ella.
    Rectangle {
        visible: root.playing && root.number <= 0
        anchors.fill: cover
        radius: cover.radius
        color: Qt.rgba(0, 0, 0, 0.5)

        Icon {
            anchors.centerIn: parent
            path: Theme.iconPlay
            filled: true
            size: 16
            color: Theme.accent
        }
    }

    Column {
        x: root.number > 0 ? 50 : 8 + Theme.rowCover + 12
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - (end.visible ? end.implicitWidth + 24 : 12) - root.rightInset
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: root.playing ? Theme.accent : Theme.text
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.showArtist && root.artist !== ""
            text: root.artist
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }

    Text {
        id: end
        anchors.right: parent.right
        anchors.rightMargin: 12 + root.rightInset
        anchors.verticalCenter: parent.verticalCenter
        visible: text !== ""
        text: root.trailing !== "" ? root.trailing : root.duration > 0 ? Theme.mmss(root.duration) : ""
        color: Theme.textMuted
        font.pixelSize: Theme.fontSmall
    }

    HoverHandler {
        id: hover
        enabled: root.hoverEnabled
        cursorShape: Qt.PointingHandCursor
    }
}
