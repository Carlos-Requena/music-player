import QtQuick
import app.musicplayer

// Pestañas o segmentos en fila (o en columna): `tabs` es `[{ id, label, icon? }]`, `current` el id
// elegido y `picked(id)` avisa al pulsar uno. Las cinco variantes de la app son esta pieza:
// navegación superior, Letra/Cola/Temporal del panel y de «Sonando», segmentos de Opciones y sus
// categorías. `navigate` sigue la regla de dos (ver `TabButton`); `fill` reparte el ancho a
// partes iguales; `well` pone el pozo oscuro detrás (dentro de un panel; la navegación superior
// va sobre vidrio y no lo lleva); `vertical`, en columna con el texto a la izquierda.
Item {
    id: root

    property var tabs: []
    property string current
    property bool navigate: true
    property bool fill: false
    property bool vertical: false
    property bool well: false
    property int fontSize: Theme.fontBase

    signal picked(string id)

    readonly property int pad: well ? 4 : 0

    implicitWidth: row.implicitWidth + 2 * pad
    implicitHeight: row.implicitHeight + 2 * pad

    Rectangle {
        anchors.fill: parent
        visible: root.well
        radius: root.navigate ? height / 2 : Theme.radiusM
        color: Theme.well
    }

    Grid {
        id: row
        x: root.pad
        y: root.pad
        columns: root.vertical ? 1 : Math.max(1, root.tabs.length)
        spacing: root.vertical || root.well ? 4 : 2

        Repeater {
            model: root.tabs

            TabButton {
                required property var modelData

                width: root.vertical ? root.width - 2 * root.pad
                     : root.fill ? (root.width - 2 * root.pad - row.spacing * (root.tabs.length - 1)) / Math.max(1, root.tabs.length)
                     : implicitWidth
                text: modelData.label
                icon: modelData.icon || ""
                chosen: modelData.id === root.current
                navigate: root.navigate
                alignLeft: root.vertical
                fontSize: root.fontSize
                onClicked: root.picked(modelData.id)
            }
        }
    }
}
