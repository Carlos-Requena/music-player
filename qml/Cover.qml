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
    // Fondo neutro mientras carga. Sin él, se ve lo que haya debajo (otra carátula más pequeña
    // que ya está en memoria, como en «Sonando»).
    property bool placeholder: true

    readonly property string url: load ? thumb.replace("w544-h544", "w" + pixels + "-h" + pixels) : ""
    // Cargada y ya a la vista del todo (terminado el fundido de entrada).
    readonly property bool ready: image.status === Image.Ready && image.opacity >= 1

    Rectangle {
        anchors.fill: parent
        visible: root.placeholder
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
            id: shape
            preferredRendererType: Shape.CurveRenderer
            opacity: image.opacity

            // La forma coloca la textura en su esquina con su tamaño en píxeles físicos, no con el
            // de `image`: sin escalarla, en una carátula mayor que eso se repetía el último píxel
            // por la derecha y por abajo. Se escala para cubrir la carátula (como
            // PreserveAspectCrop) y se centra.
            readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
            readonly property real texW: Math.max(1, image.implicitWidth / dpr)
            readonly property real texH: Math.max(1, image.implicitHeight / dpr)
            readonly property real scale: Math.max(root.width / texW, root.height / texH)

            ShapePath {
                strokeColor: "transparent"
                fillItem: image
                fillTransform: Qt.matrix4x4(shape.scale, 0, 0, (root.width - shape.texW * shape.scale) / 2,
                                            0, shape.scale, 0, (root.height - shape.texH * shape.scale) / 2,
                                            0, 0, 1, 0,
                                            0, 0, 0, 1)
                PathRectangle {
                    width: root.width
                    height: root.height
                    radius: root.radius
                }
            }
        }
    }
}
