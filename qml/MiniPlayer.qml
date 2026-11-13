import QtQuick
import QtQuick.Window
import app.musicplayer

// Mini reproductor: ventana pequeña, siempre encima y sin marco. Mientras está abierto la
// ventana principal se oculta y libera su memoria gráfica.
Window {
    id: mini

    // Al volver de oculta o minimizada, recrea los iconos (ver `Theme.renderEpoch`).
    property bool wasAway: false
    onVisibilityChanged: state => {
        if (state === Window.Hidden || state === Window.Minimized)
            wasAway = true
        else if (wasAway) {
            wasAway = false
            Theme.renderEpoch++
        }
    }

    signal restore()

    width: 400
    height: 112
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Mini reproductor"

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.glassBorder

        // Fondo opaco bajo el vidrio: el escritorio no se puede desenfocar.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.ground
            z: -1
        }

        // Arrastrar desde cualquier zona libre mueve la ventana.
        DragHandler {
            target: null
            onActiveChanged: if (active) mini.startSystemMove()
        }

        Cover {
            id: art
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            height: 80
            thumb: Player.thumb
            pixels: 160
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 16
            spacing: 2

            Text {
                width: parent.width - 36
                text: Player.title !== "" ? Player.title : "Nada sonando"
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width - 36
                text: Player.artist
                color: Theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Row {
                spacing: 2

                IconButton {
                    icon: Theme.iconPrevious
                    label: "Anterior"
                    filled: true
                    iconSize: 18
                    onClicked: Player.previous()
                }

                IconButton {
                    icon: Player.playing ? Theme.iconPause : Theme.iconPlay
                    label: Player.playing ? "Pausa" : "Reproducir"
                    filled: true
                    active: true
                    iconSize: 18
                    onClicked: Player.toggle()
                }

                IconButton {
                    icon: Theme.iconNext
                    label: "Siguiente"
                    filled: true
                    iconSize: 18
                    onClicked: Player.next()
                }
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: 6
            y: 6
            icon: Theme.iconExpand
            label: "Volver a la ventana completa"
            iconSize: 16
            onClicked: mini.restore()
        }

        // Progreso: una línea fina en el borde inferior.
        Rectangle {
            x: card.radius
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: (parent.width - 2 * card.radius) * (Player.duration > 0 ? Player.position / Player.duration : 0)
            height: 3
            radius: 1.5
            color: Theme.accent
        }
    }

    Shortcut { sequence: "Space"; onActivated: Player.toggle() }
    Shortcut { sequence: "Escape"; onActivated: mini.restore() }
}
