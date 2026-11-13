import QtQuick
import app.musicplayer

// Ajuste del retraso de la letra de la canción que suena (se guarda por canción): «−» la
// adelanta, «+» la atrasa medio segundo; clic en el texto vuelve a cero.
Rectangle {
    width: timing.implicitWidth + 16
    height: Theme.hit
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.45)
    border.width: 1
    border.color: Theme.glassBorder

    Row {
        id: timing
        anchors.centerIn: parent
        spacing: 2

        IconButton {
            icon: "M6 12h12"
            iconSize: 16
            label: "Adelantar la letra medio segundo"
            onClicked: Catalog.setLyricsDelay(Catalog.lyricsDelay - 0.5)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 118
            horizontalAlignment: Text.AlignHCenter
            text: Catalog.lyricsDelay === 0 ? "Letra en hora"
                : "Letra " + (Catalog.lyricsDelay > 0 ? "+" : "−") + Math.abs(Catalog.lyricsDelay).toFixed(1).replace(".", ",") + " s"
            color: Catalog.lyricsDelay === 0 ? Theme.textMuted : Theme.text
            font.pixelSize: 13

            // Clic en el texto: vuelve a cero.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: Catalog.setLyricsDelay(0)
            }
        }

        IconButton {
            icon: Theme.iconPlus
            iconSize: 16
            label: "Atrasar la letra medio segundo"
            onClicked: Catalog.setLyricsDelay(Catalog.lyricsDelay + 0.5)
        }
    }
}
