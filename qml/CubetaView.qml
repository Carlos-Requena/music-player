import QtQuick
import app.musicplayer

// Vista "Cubeta": los elementos se pasan de uno en uno, como discos en una caja de tienda.
FocusScope {
    id: root

    property var zonas: []
    property string titulo: ""
    property int index: 0

    readonly property var items: {
        let out = []
        for (const zona of zonas)
            out = out.concat(zona.items)
        return out
    }
    readonly property var currentItem: items.length ? items[Math.min(index, items.length - 1)] : null

    readonly property real side: Math.min(400, height * 0.6, width * 0.36)
    readonly property real stackX: width * 0.3
    readonly property real frontY: height * 0.3

    signal activated(var item)

    onZonasChanged: index = 0

    function step(delta) {
        if (items.length)
            index = Math.max(0, Math.min(items.length - 1, index + delta))
    }

    Keys.onUpPressed: step(1)
    Keys.onDownPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onLeftPressed: step(-1)
    Keys.onReturnPressed: if (currentItem) activated(currentItem)
    Keys.onEnterPressed: if (currentItem) activated(currentItem)

    WheelHandler {
        property real travelled: 0
        onWheel: event => {
            travelled += event.angleDelta.y
            if (Math.abs(travelled) >= 120) {
                root.step(travelled > 0 ? -1 : 1)
                travelled = 0
            }
        }
    }

    Repeater {
        model: root.items

        Cover {
            id: disc
            required property var modelData
            required property int index

            // 0 = disco de delante; los siguientes asoman por detrás, cada vez más pequeños.
            readonly property int depth: index - root.index
            readonly property real shrink: Math.pow(0.94, Math.max(0, depth))

            thumb: modelData.thumb
            pixels: 544
            load: depth >= -1 && depth <= 5
            width: root.side * shrink
            height: width
            x: root.stackX - width / 2
            y: depth < 0 ? root.height : root.frontY - 40 * Math.max(0, depth)
            z: 100 - depth
            opacity: depth < 0 || depth > 4 ? 0 : 1
            visible: opacity > 0

            Behavior on y { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.animMove } }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: Math.min(0.6, 0.15 * Math.max(0, disc.depth))
            }

            // Clic derecho: menú con «Añadir a la lista temporal».
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: eventPoint => disc.Window.window.openMenu(disc.modelData, eventPoint.scenePosition)
            }

            TapHandler {
                onTapped: {
                    if (disc.depth === 0)
                        root.activated(disc.modelData)
                    else
                        root.index = disc.index
                    root.forceActiveFocus()
                }
            }
        }
    }

    // Frontal de la cubeta.
    Rectangle {
        x: root.stackX - root.side / 2 - 34
        y: root.frontY + root.side - 44
        z: 150
        width: root.side + 68
        height: 120
        radius: 10
        border.width: 1
        border.color: Theme.glassBorder
        gradient: Gradient {
            GradientStop { position: 0; color: "#1A1D24" }
            GradientStop { position: 1; color: "#0E1014" }
        }

        Text {
            x: 22
            y: 18
            text: root.titulo
            color: Theme.text
            font.pixelSize: 20
            font.weight: Font.ExtraBold
            font.letterSpacing: 2.6
            font.capitalization: Font.AllUppercase
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 22
            y: 22
            text: root.items.length ? (root.index + 1) + " de " + root.items.length : ""
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }

    Column {
        x: root.width * 0.56
        y: root.frontY + 20
        width: root.width - x - 48
        spacing: 10

        Text {
            width: parent.width
            text: root.currentItem ? root.currentItem.title : ""
            color: Theme.text
            font.pixelSize: 46
            font.weight: Font.Bold
            font.letterSpacing: -0.7
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.currentItem ? root.currentItem.subtitle : ""
            color: Theme.textMuted
            font.pixelSize: 15
            elide: Text.ElideRight
        }
    }
}
