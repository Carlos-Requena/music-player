import QtQuick
import app.musicplayer

// Vista "Lomos": estantería en la que el elemento elegido se ve de frente y el resto
// asoma como lomos, con suelo reflectante. Sirve para álbumes y para playlists.
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

    // Geometría de la estantería, proporcional al espacio disponible.
    readonly property real side: Math.min(280, height * 0.38, width * 0.25)
    readonly property real centerSide: side * 1.28
    readonly property real spineWidth: side * 0.107
    readonly property real strip: centerSide * 0.045
    readonly property real groupGap: side * 0.157
    readonly property real centerX: width / 2
    readonly property real centerY: 64 + centerSide / 2

    signal activated(var item)

    onZonasChanged: index = 0

    // Ancho visible de la carátula de la caja que está a `k` puestos del centro.
    function sliver(k) {
        return side * (k === 1 ? 0.405 : k === 2 ? 0.157 : k === 3 ? 0.079 : 0.036)
    }

    // Distancia del borde interior del grupo al borde exterior del lomo `k`.
    function reach(k) {
        let total = 0
        for (let j = 1; j <= k; ++j)
            total += spineWidth + sliver(j)
        return total
    }

    function step(delta) {
        if (items.length)
            index = Math.max(0, Math.min(items.length - 1, index + delta))
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: if (currentItem) activated(currentItem)
    Keys.onEnterPressed: if (currentItem) activated(currentItem)

    WheelHandler {
        property real travelled: 0
        onWheel: event => {
            travelled += event.angleDelta.y + event.angleDelta.x
            if (Math.abs(travelled) >= 120) {
                root.step(travelled > 0 ? -1 : 1)
                travelled = 0
            }
        }
    }

    Column {
        x: 40
        y: 4
        spacing: 2

        Text {
            text: root.titulo
            color: Theme.text
            font.pixelSize: 24
            font.weight: Font.ExtraBold
            font.letterSpacing: 3.4
            font.capitalization: Font.AllUppercase
        }

        Text {
            text: root.items.length ? (root.index + 1) + " / " + root.items.length : ""
            color: Theme.textMuted
            font.pixelSize: 12
            font.letterSpacing: 1.2
        }
    }

    Repeater {
        model: root.items

        Item {
            id: box
            required property var modelData
            required property int index

            readonly property int offset: index - root.index
            readonly property int k: Math.abs(offset)
            readonly property bool center: offset === 0
            readonly property bool rightSide: offset > 0
            readonly property var look: Catalog.cover(modelData.art)

            property real coverSide: center ? root.centerSide : root.side
            property real spine: center ? root.strip : root.spineWidth
            property real angle: center ? 0 : (rightSide ? 60 : -60)

            width: spine + coverSide
            height: coverSide
            x: center ? root.centerX - root.centerSide / 2 - root.strip
                      : rightSide ? root.centerX + root.centerSide / 2 + root.groupGap + root.reach(k) - width
                                  : root.centerX - root.centerSide / 2 - root.strip - root.groupGap - root.reach(k)
            y: root.centerY - coverSide / 2
            z: 100 - k
            opacity: k <= 7 ? 1 : 0
            visible: opacity > 0

            Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
            Behavior on coverSide { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
            Behavior on spine { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
            Behavior on angle { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            Accessible.role: Accessible.Button
            Accessible.name: modelData.title + ", " + modelData.subtitle

            Item {
                id: visual
                anchors.fill: parent

                Cover {
                    x: box.rightSide ? 0 : box.spine
                    width: box.coverSide
                    height: box.coverSide
                    art: box.modelData.art

                    transform: Rotation {
                        origin.x: box.rightSide ? box.coverSide : 0
                        origin.y: box.coverSide / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: box.angle
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: box.center ? 0 : 0.24
                    }
                }

                Rectangle {
                    id: spineRect
                    x: box.rightSide ? box.coverSide : 0
                    width: box.spine
                    height: parent.height
                    color: box.look.spine

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                            GradientStop { position: 0.5; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.32) }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: spineRect.height - 24
                        height: spineRect.width
                        rotation: 90
                        opacity: box.center ? 0 : 1
                        text: box.modelData.title
                        color: box.look.ink
                        font.pixelSize: Math.max(9, root.spineWidth * 0.38)
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.4
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }

            // Reflejo en el suelo: la misma textura, volteada y atenuada.
            ShaderEffectSource {
                sourceItem: visual
                width: box.width
                height: box.height
                y: box.height + 6
                opacity: 0.2
                transform: Scale {
                    origin.y: box.height / 2
                    yScale: -1
                }
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            TapHandler {
                onTapped: {
                    if (box.center)
                        root.activated(box.modelData)
                    else
                        root.index = box.index
                    root.forceActiveFocus()
                }
            }
        }
    }

    // Funde los reflejos con el suelo.
    Rectangle {
        x: 0
        y: root.centerY + root.centerSide / 2 + 6
        z: 150
        width: parent.width
        height: Math.max(0, parent.height - y)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.03, 0.035, 0.05, 0.25) }
            GradientStop { position: 0.55; color: Qt.rgba(0.03, 0.035, 0.05, 0.96) }
            GradientStop { position: 1; color: Qt.rgba(0.03, 0.035, 0.05, 0) }
        }
    }

    Column {
        z: 200
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.centerY + root.centerSide / 2 + 30
        width: parent.width - 80
        spacing: 6

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.currentItem ? root.currentItem.title : ""
            color: Theme.text
            font.pixelSize: 40
            font.weight: Font.Bold
            font.letterSpacing: -0.5
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.currentItem ? root.currentItem.subtitle : ""
            color: Theme.textMuted
            font.pixelSize: 13
            font.letterSpacing: 0.5
            elide: Text.ElideRight
        }
    }
}
