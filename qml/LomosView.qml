import QtQuick
import QtQuick.Effects
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
    readonly property real side: Math.min(280, height * 0.36, width * 0.22)
    readonly property real centerSide: side * 1.28
    readonly property real spineWidth: side * 0.107
    readonly property real strip: centerSide * 0.045
    readonly property real groupGap: side * 0.157
    readonly property real centerX: width / 2
    readonly property real centerY: 64 + centerSide / 2
    readonly property real floorY: centerY + side / 2

    // Cajas que caben a cada lado sin salirse del escenario.
    readonly property int perSide: {
        const room = width / 2 - centerSide / 2 - groupGap - 24
        let k = 0
        while (k < 8 && reach(k + 1) <= room)
            ++k
        return k
    }

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

    // Reflejo en el suelo: la franja inferior de la estantería, volteada y fundida a transparente.
    Item {
        id: fade
        width: root.width
        height: root.side * 0.45
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 1; color: "black" }
            }
        }
    }

    ShaderEffectSource {
        id: mirror
        width: root.width
        height: root.side * 0.45
        y: root.floorY + 4
        opacity: 0.3
        sourceItem: shelf
        sourceRect: Qt.rect(0, root.floorY - height, width, height)
        transform: Scale {
            origin.y: mirror.height / 2
            yScale: -1
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fade
            // Umbral 0.5 con dispersión 1 hace que la máscara siga el degradado
            // en vez de recortar en seco.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: shelf
        anchors.fill: parent

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
                // Solo las cajas cercanas descargan carátula y calculan su color.
                readonly property bool near: k <= root.perSide + 1

                property real coverSide: center ? root.centerSide : root.side
                property real spine: center ? root.strip : root.spineWidth
                // En Qt un ángulo positivo aleja lo que queda a la derecha del eje.
                property real angle: center ? 0 : (rightSide ? -60 : 60)

                width: spine + coverSide
                height: coverSide
                x: center ? root.centerX - root.centerSide / 2 - root.strip
                          : rightSide ? root.centerX + root.centerSide / 2 + root.groupGap + root.reach(k) - width
                                      : root.centerX - root.centerSide / 2 - root.strip - root.groupGap - root.reach(k)
                y: root.centerY - coverSide / 2
                z: 100 - k
                opacity: k <= root.perSide ? 1 : 0
                visible: opacity > 0

                Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
                Behavior on coverSide { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
                Behavior on spine { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
                Behavior on angle { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title + ", " + modelData.subtitle

                // Queda tapada por el lomo, que se dibuja encima.
                TintProbe {
                    id: probe
                    x: box.rightSide ? box.coverSide : 0
                    thumb: box.near ? box.modelData.thumb : ""
                }

                Cover {
                    x: box.rightSide ? 0 : box.spine
                    width: box.coverSide
                    height: box.coverSide
                    thumb: box.modelData.thumb
                    pixels: 544
                    load: box.near

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
                    color: Qt.darker(probe.tint, 1.25)

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
                        color: Theme.text
                        font.pixelSize: Math.max(9, Math.round(root.spineWidth * 0.38))
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.4
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) Player.prefetchItem(JSON.stringify(box.modelData))
                }

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
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.centerY + root.centerSide / 2 + 26
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
