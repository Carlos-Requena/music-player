import QtQuick
import app.musicplayer

// Barra de reproducción flotante. En `compact` (estilo "Escenario") se reduce a una píldora.
Glass {
    id: root

    property bool compact: false
    property bool lyricsOn: true
    signal lyricsToggled()

    tint: Theme.glassStrong
    radius: compact ? height / 2 : 22

    Row {
        id: nowPlaying
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: root.compact ? 230 : 300
        spacing: 12

        Cover {
            width: 56
            height: 56
            art: Player.cover
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 68
            spacing: 2

            Text {
                width: parent.width
                text: Player.title
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Player.artist
                color: Theme.textMuted
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
    }

    Column {
        anchors.left: nowPlaying.right
        anchors.right: extras.left
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            IconButton {
                icon: Theme.iconPrevious
                label: "Anterior"
                filled: true
                onClicked: Player.previous()
            }

            IconButton {
                icon: Player.playing ? Theme.iconPause : Theme.iconPlay
                label: Player.playing ? "Pausa" : "Reproducir"
                filled: true
                active: true
                onClicked: Player.toggle()
            }

            IconButton {
                icon: Theme.iconNext
                label: "Siguiente"
                filled: true
                onClicked: Player.next()
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 620)
            height: 20
            spacing: 10

            Text {
                id: elapsed
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                horizontalAlignment: Text.AlignRight
                text: Theme.mmss(Player.position)
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Item {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * (34 + 10)
                height: 20

                Accessible.role: Accessible.Slider
                Accessible.name: "Posición"

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.22)

                    Rectangle {
                        width: Player.duration > 0 ? parent.width * Player.position / Player.duration : 0
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                    }
                }

                Rectangle {
                    x: (Player.duration > 0 ? track.width * Player.position / Player.duration : 0) - 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    function seek(mouse) {
                        Player.seek(Math.max(0, Math.min(1, (mouse.x - 8) / track.width)) * Player.duration)
                    }
                    onPressed: mouse => seek(mouse)
                    onPositionChanged: mouse => seek(mouse)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                text: Theme.mmss(Player.duration)
                color: Theme.textMuted
                font.pixelSize: 12
            }
        }
    }

    Row {
        id: extras
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        IconButton {
            icon: Theme.iconLyrics
            label: "Letra"
            solid: root.lyricsOn
            visible: !root.compact
            onClicked: root.lyricsToggled()
        }
    }
}
