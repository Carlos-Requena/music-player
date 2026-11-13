import QtQuick
import app.musicplayer

// Barra de reproducción flotante. En `compact` (estilo "Escenario") se reduce a una píldora.
Glass {
    id: root

    property bool compact: false
    property bool lyricsOn: true
    signal lyricsToggled()
    signal miniRequested()
    // Pulsar la canción (carátula o título) abre la pantalla «Sonando».
    signal expandRequested()

    tint: Theme.glassStrong
    radius: compact ? height / 2 : 22

    Row {
        id: nowPlaying
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: root.compact ? 230 : 300
        spacing: 12

        HoverHandler {
            enabled: Player.title !== ""
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            enabled: Player.title !== ""
            onTapped: root.expandRequested()
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Abrir la pantalla Sonando"

        Cover {
            width: 56
            height: 56
            thumb: Player.thumb
            pixels: 120
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 68
            spacing: 2

            Text {
                width: parent.width
                text: Player.title !== "" ? Player.title : "Nada sonando"
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Player.error !== "" ? Player.error : (Player.loading ? "Cargando…" : Player.artist)
                color: Player.error !== "" ? Theme.accent : Theme.textMuted
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

                // Late mientras la pista se está resolviendo.
                SequentialAnimation on opacity {
                    running: Player.loading
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }

            IconButton {
                icon: Theme.iconNext
                label: "Siguiente"
                filled: true
                onClicked: Player.next()
            }

            IconButton {
                icon: Theme.iconRepeat
                label: Player.repetir ? "Repetir la cola: activado" : "Repetir la cola"
                iconSize: 18
                foreground: Player.repetir ? Theme.accent : Theme.textMuted
                onClicked: Player.repetir = !Player.repetir
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 620)
            height: 20
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                horizontalAlignment: Text.AlignRight
                text: Theme.mmss(Player.position)
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * (34 + 10)
                label: "Posición"
                value: Player.duration > 0 ? Player.position / Player.duration : 0
                onMoved: value => Player.seek(value * Player.duration)
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
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        IconButton {
            icon: Theme.iconMini
            label: "Mini reproductor"
            onClicked: root.miniRequested()
        }

        IconButton {
            icon: Theme.iconLyrics
            label: "Panel de letra y cola"
            solid: root.lyricsOn
            visible: !root.compact
            onClicked: root.lyricsToggled()
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            path: Theme.iconVolume
            color: Theme.textMuted
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: root.compact ? 72 : 96
            label: "Volumen"
            fill: Theme.text
            value: Player.volume / 100
            onMoved: value => Player.changeVolume(value * 100)
        }
    }
}
