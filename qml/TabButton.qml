import QtQuick
import app.musicplayer

// Una pestaña o un segmento, con la regla de dos (ADR-23): lo que dice dónde estás (`navigate`:
// secciones, categorías, Letra/Cola/Temporal, categorías de Opciones) se marca en blanco y es una
// píldora; un valor que eliges (`navigate: false`, los segmentos de Opciones) se marca en vidrio
// claro, con el radio M de la skin. La agrupa `Tabs`; `CategoryBar` la usa suelta.
Item {
    id: root

    property string text
    property string icon: ""
    property bool chosen: false
    property bool navigate: true
    // Icono y texto a la izquierda (barra lateral de Opciones) en vez de centrados.
    property bool alignLeft: false
    property int fontSize: Theme.fontBase
    property real radius: navigate ? height / 2 : Math.max(0, Theme.radiusM - 4)

    signal clicked()
    // Clic derecho, con el punto en coordenadas de la escena (el menú de una categoría).
    signal contextRequested(point scenePoint)

    readonly property color ink: chosen ? (navigate ? Theme.ground : Theme.text) : Theme.textMuted

    implicitWidth: content.implicitWidth + 26
    implicitHeight: Theme.hit
    activeFocusOnTab: true

    Accessible.role: navigate ? Accessible.PageTab : Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: chosen
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.chosen ? (root.navigate ? Theme.text : Theme.controlActive)
                           : (hover.hovered ? Theme.control : "transparent")

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    FocusRing {
        shown: root.activeFocus
        corner: root.radius
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        x: root.alignLeft ? 14 : Math.max(0, (root.width - width) / 2)
        spacing: root.alignLeft ? 12 : 8

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            path: root.icon
            size: 18
            color: root.ink
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - (root.icon !== "" ? 30 : 0) - (root.alignLeft ? 28 : 16))
            text: root.text
            color: root.ink
            font.pixelSize: root.fontSize
            font.weight: root.chosen ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: eventPoint => root.contextRequested(eventPoint.scenePosition)
    }
}
