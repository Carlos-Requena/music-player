import QtQuick
import app.musicplayer

// Carátula a partir de la URL de su miniatura, con un fondo neutro mientras carga.
Item {
    id: root

    property string thumb: ""
    // Lado en píxeles que se pide al servidor y se guarda en memoria.
    property int pixels: 320
    // Permite no descargar las carátulas que aún no se ven.
    property bool load: true

    readonly property string url: load ? thumb.replace("w544-h544", "w" + pixels + "-h" + pixels) : ""

    Rectangle {
        anchors.fill: parent
        color: "#1A1D24"
    }

    Image {
        anchors.fill: parent
        source: root.url
        sourceSize: Qt.size(root.pixels, root.pixels)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }
}
