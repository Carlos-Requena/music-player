import QtQuick
import QtQuick.Effects
import app.musicplayer

// Panel de vidrio. Si se le pasa `backdrop`, desenfoca en tiempo real lo que esa capa
// tiene detrás del panel; sin él solo aplica el tinte translúcido (más barato).
Item {
    id: root

    property real radius: Theme.radius
    property color tint: Theme.glass
    property Item backdrop: null
    property real blur: 1
    default property alias content: holder.data

    ShaderEffectSource {
        id: grab
        anchors.fill: parent
        visible: false
        live: root.visible && Theme.blur
        sourceItem: root.backdrop
        // A media resolución: se va a desenfocar mucho y la diferencia no se ve, y la copia (la
        // de Opciones ocupa casi toda la ventana) pesa la cuarta parte.
        textureSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio / 2)),
                             Math.max(1, Math.ceil(height * Screen.devicePixelRatio / 2)))
        sourceRect: {
            if (!root.backdrop)
                return Qt.rect(0, 0, 0, 0)
            // Dependencias explícitas: mapToItem no es reactivo por sí solo.
            void (root.x + root.y + root.width + root.height + root.backdrop.x + root.backdrop.y + root.backdrop.width + root.backdrop.height)
            const origin = root.mapToItem(root.backdrop, 0, 0)
            return Qt.rect(origin.x, origin.y, root.width, root.height)
        }
    }

    // Máscara del desenfoque: sin `backdrop` no hace falta y no se reserva su textura.
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.backdrop !== null && Theme.blur

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.backdrop !== null && Theme.blur
        source: grab
        blurEnabled: true
        blur: root.blur
        blurMax: 48
        saturation: 0.25
        maskEnabled: true
        maskSource: mask
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        border.width: 1
        border.color: Theme.glassBorder
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
