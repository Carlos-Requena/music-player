import QtQuick
import QtQuick.Shapes
import app.musicplayer

// Carátula a partir de la URL de su miniatura, con un fondo neutro mientras carga. Con
// `radius` sale con las esquinas redondeadas (o en círculo): la imagen rellena una forma, sin
// capa ni máscara aparte.
Item {
    id: root

    property string thumb: ""
    // Lado en píxeles que se pide al servidor y se guarda en memoria.
    property int pixels: 320
    // Permite no descargar las carátulas que aún no se ven.
    property bool load: true
    property real radius: 0

    readonly property string url: load ? thumb.replace("w544-h544", "w" + pixels + "-h" + pixels) : ""

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "#1A1D24"
    }

    Image {
        id: image
        anchors.fill: parent
        visible: root.radius <= 0
        source: root.url
        sourceSize: Qt.size(root.pixels, root.pixels)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // Se recrea cuando la ventana vuelve de estar oculta (ver `Theme.renderEpoch`).
    Loader {
        id: rounded
        anchors.fill: parent
        active: root.radius > 0

        readonly property int epoch: Theme.renderEpoch
        onEpochChanged: if (active) {
            active = false
            active = Qt.binding(() => root.radius > 0)
        }

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            opacity: image.opacity

            ShapePath {
                strokeColor: "transparent"
                fillItem: image
                PathRectangle {
                    width: root.width
                    height: root.height
                    radius: root.radius
                }
            }
        }
    }
}
