import QtQuick
import app.musicplayer

// Carátula a partir de la URL de su miniatura, con un fondo neutro mientras carga. Con
// `radius` sale con las esquinas redondeadas (o en círculo): un sombreador (`caratula.frag`) lee
// la textura de la imagen y recorta el borde, sin capa ni máscara aparte.
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
    // La imagen, para usar su textura en un sombreador (el reflejo de Lomos) sin cargarla dos veces.
    readonly property Image picture: image

    Rectangle {
        anchors.fill: parent
        visible: root.placeholder
        radius: root.radius
        color: Theme.placeholder
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

    // Redondeada: la textura de `image` (oculta) con las esquinas recortadas. Una `Shape` por
    // carátula costaba unos 24 MB más en un Muro lleno (ADR-23). `crop` hace lo que
    // `PreserveAspectCrop`: muestra la parte central que cubre el recuadro.
    ShaderEffect {
        anchors.fill: parent
        visible: root.radius > 0 && image.status === Image.Ready
        opacity: image.opacity

        readonly property real imageAspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 1
        readonly property real boxAspect: root.height > 0 ? root.width / root.height : 1

        property variant source: image
        property size size: Qt.size(width, height)
        property real radius: Math.min(root.radius, width / 2, height / 2)
        property size crop: imageAspect > boxAspect ? Qt.size(boxAspect / imageAspect, 1)
                                                    : Qt.size(1, imageAspect / boxAspect)
        fragmentShader: "qrc:/qt/qml/app/musicplayer/shaders/caratula.frag.qsb"
    }
}
