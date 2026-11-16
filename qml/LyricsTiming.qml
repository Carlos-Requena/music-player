import QtQuick
import app.musicplayer

// Ajuste del retraso de la letra de la canción que suena (se guarda por canción), como un pie
// discreto centrado bajo la letra (diseño B elegido por el propietario): solo texto tenue, sin
// cápsula ni bordes, «−  letra en hora  +». Con retraso, el texto se ilumina y dice cuánto
// («Letra +0,5 s»); pulsarlo la vuelve a poner en hora. «−» la adelanta y «+» la atrasa medio
// segundo. Los botones mantienen sus 44 px de área aunque el signo sea pequeño.
Row {
    id: root

    readonly property real delay: Catalog.lyricsDelay
    readonly property color tone: delay === 0 ? Theme.textFaint : Theme.text

    spacing: 0

    function change(seconds) {
        Catalog.setLyricsDelay(Math.round((delay + seconds) * 10) / 10)
    }

    IconButton {
        icon: "M6 12h12"
        iconSize: 14
        foreground: root.tone
        label: "Adelantar la letra medio segundo"
        onClicked: root.change(-0.5)
    }

    Item {
        id: reset
        width: label.implicitWidth + 16
        height: Theme.hit
        activeFocusOnTab: root.delay !== 0

        Accessible.role: Accessible.Button
        Accessible.name: root.delay === 0 ? "Letra en hora" : label.text + ". Poner en hora"
        Accessible.onPressAction: Catalog.setLyricsDelay(0)
        Keys.onReturnPressed: Catalog.setLyricsDelay(0)
        Keys.onSpacePressed: Catalog.setLyricsDelay(0)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: reset.activeFocus ? 2 : 0
            border.color: Theme.text
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.delay === 0 ? "letra en hora"
                : "Letra " + (root.delay > 0 ? "+" : "−") + Math.abs(root.delay).toFixed(1).replace(".", ",") + " s"
            color: root.tone
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }

        HoverHandler {
            enabled: root.delay !== 0
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            enabled: root.delay !== 0
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: Catalog.setLyricsDelay(0)
        }
    }

    IconButton {
        icon: Theme.iconPlus
        iconSize: 14
        foreground: root.tone
        label: "Atrasar la letra medio segundo"
        onClicked: root.change(0.5)
    }
}
