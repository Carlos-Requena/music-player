import QtQuick
import QtQuick.Effects
import app.musicplayer

// Vista "Lomos": estantería de cajas en 3D. La elegida se ve casi de frente y más grande; sus
// vecinas, giradas hacia ella; el resto asoma como lomos apretados. Cada caja se refleja en
// el suelo y la elegida proyecta un halo de su color.
//
// Cada caja es un cuerpo con frontal y dos lomos que se proyectan con una matriz 4×4 propia
// (rotación en Y + perspectiva). La posición de la estantería es continua (`pos`): al
// desplazarse, cada caja interpola ángulo, tamaño y sitio, sin saltos al cruzar el centro.
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

    // Posición continua de la estantería; sigue a `index` con una animación.
    property real pos: 0
    property bool animate: false
    onIndexChanged: pos = index
    Behavior on pos {
        enabled: root.animate
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    // Geometría, proporcional al espacio. Medidas tomadas del vídeo de referencia.
    readonly property real side: Math.max(80, Math.min(height * 0.34, width * 0.17, 320))
    readonly property real thickness: side * 0.11      // grosor de la caja (lomo)
    readonly property real centerScale: 1.35           // la elegida, más grande
    readonly property real centerTilt: 16              // giro leve que deja ver su lomo
    readonly property real centerGap: side * 0.17      // hueco a cada lado de la elegida
    readonly property real distance: side * 18         // distancia de la cámara (perspectiva suave)
    readonly property real centerX: width / 2
    readonly property real centerY: Math.max(70 + side * centerScale / 2, height * 0.4)
    readonly property real reflection: 0.38            // alto del reflejo respecto a la caja

    // Ángulo (grados) y escala de la caja a `u` puestos del centro.
    function angleAt(u) {
        return u <= 1 ? 50 * u : u <= 2 ? 50 + 28 * (u - 1) : 78
    }
    function scaleAt(u) {
        return u >= 1 ? 1 : centerScale + (1 - centerScale) * u
    }
    // Ángulo con signo para un desplazamiento continuo `d` (negativo = izquierda): monótono y
    // continuo, así una caja que cruza el centro gira sin saltos.
    function signedAngle(d) {
        const u = Math.abs(d)
        const tilt = centerTilt * Math.max(0, 1 - u)
        return (d < 0 ? angleAt(u) : -angleAt(u)) + tilt
    }

    // Extremos horizontales proyectados de una caja girada `a` grados con escala `s`,
    // relativos a su eje. Se usan para encajar los lomos sin huecos ni solapes.
    function extents(a, s) {
        const r = a * Math.PI / 180
        const c = Math.cos(r), n = Math.sin(r)
        const w = side * s / 2, t = thickness * s / 2
        let lo = 1e9, hi = -1e9
        for (const bx of [-w, w]) {
            for (const bz of [-t, t]) {
                const x = bx * c - bz * n
                const z = bx * n + bz * c
                const p = x * distance / (distance + z)
                lo = Math.min(lo, p)
                hi = Math.max(hi, p)
            }
        }
        return [lo, hi]
    }

    // Distancia al centro del eje de la caja a `k` puestos (k entero), hacia la derecha.
    // Por simetría vale para la izquierda cambiando el signo.
    readonly property var slots: {
        const out = [0]
        let edge = extents(-centerTilt, centerScale)[1]
        for (let k = 1; k <= 14; ++k) {
            const e = extents(-angleAt(k), 1)
            const gap = k === 1 ? centerGap : 0
            const axis = edge + gap - e[0]
            out.push(axis)
            edge = axis + e[1]
        }
        return out
    }

    // Cajas que caben a cada lado sin salirse del escenario.
    readonly property int perSide: {
        const room = width / 2 - 16
        let k = 0
        while (k < 13 && slots[k + 1] + extents(-angleAt(k + 1), 1)[1] <= room)
            ++k
        return k
    }

    function slotAt(u) {
        const k = Math.floor(u)
        if (k >= slots.length - 1)
            return slots[slots.length - 1]
        return slots[k] + (slots[k + 1] - slots[k]) * (u - k)
    }

    // Matriz que lleva el plano local (u, v) de una cara a la pantalla. La cara empieza en
    // el punto `o` del cuerpo de la caja y avanza según `du` y `dv` (vectores 3D, en el
    // espacio de la caja sin girar, con z hacia el fondo). Luego se gira `a` grados en Y, se
    // escala, se lleva a (X, Y) y se proyecta con la cámara delante del eje de la caja.
    function faceMatrix(o, du, dv, a, s, X, Y) {
        const r = a * Math.PI / 180
        const c = Math.cos(r), n = Math.sin(r)
        function rot(v) { return [s * (v[0] * c - v[2] * n), s * v[1], s * (v[0] * n + v[2] * c)] }
        const p = rot(o), u = rot(du), v = rot(dv)
        const D = distance
        return Qt.matrix4x4(
            u[0] + X * u[2] / D, v[0] + X * v[2] / D, 0, p[0] + X * (1 + p[2] / D),
            u[1] + Y * u[2] / D, v[1] + Y * v[2] / D, 0, p[1] + Y * (1 + p[2] / D),
            0, 0, 0, 0,
            u[2] / D, v[2] / D, 0, 1 + p[2] / D)
    }

    function withAlpha(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    signal activated(var item)

    // Otra sección: vuelve al principio sin animar. La misma sección refrescada (la caché y
    // luego la red): conserva el sitio.
    onTituloChanged: {
        animate = false
        index = 0
        pos = 0
        animate = true
    }
    onItemsChanged: if (index >= items.length) index = Math.max(0, items.length - 1)
    Component.onCompleted: {
        pos = index
        animate = true
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

    // Degradado que funde los reflejos (se comparte entre todas las cajas).
    Item {
        id: fade
        width: 64
        height: 64
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "black" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // Color de la elegida, para el halo del suelo.
    TintProbe {
        id: currentTint
        x: -width
        thumb: root.currentItem ? root.currentItem.thumb : ""
    }

    // Halo de luz en el suelo, bajo la caja elegida.
    RectangularShadow {
        x: root.centerX - width / 2
        y: root.centerY + root.side * root.centerScale / 2 - height / 2
        width: root.side * root.centerScale * 0.95
        height: root.side * 0.12
        radius: height / 2
        blur: root.side * 0.3
        spread: root.side * 0.02
        color: root.withAlpha(Qt.lighter(currentTint.tint, 1.6), 0.75)
        visible: root.items.length > 0

        Behavior on color { ColorAnimation { duration: Theme.animMove } }
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

                readonly property real d: index - root.pos
                readonly property real u: Math.abs(d)
                readonly property bool shown: u < root.perSide + 1
                readonly property bool near: u <= root.perSide + 2
                readonly property real a: root.signedAngle(d)
                readonly property real s: root.scaleAt(u)
                readonly property real bx: root.centerX + (d < 0 ? -1 : 1) * root.slotAt(u)
                readonly property real by: root.centerY
                readonly property real w: root.side
                readonly property real t: root.thickness
                // Lo que pasa del último puesto se desvanece.
                readonly property real fadeOut: Math.max(0, Math.min(1, root.perSide + 1 - u))
                readonly property color tint: probe.tint

                visible: shown && fadeOut > 0
                opacity: fadeOut
                z: 1000 - Math.round(u * 10)

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title + ", " + modelData.subtitle

                function select() {
                    if (index === root.index)
                        root.activated(modelData)
                    else
                        root.index = index
                    root.forceActiveFocus()
                }

                // ---- Reflejos (debajo de las caras) ----

                // Frontal reflejado: la carátula volteada que nace del borde inferior.
                Item {
                    width: box.w
                    height: box.w * root.reflection
                    clip: true
                    transform: Matrix4x4 {
                        matrix: root.faceMatrix([-box.w / 2, box.w / 2, -box.t / 2], [1, 0, 0], [0, 1, 0],
                                                box.a, box.s, box.bx, box.by)
                    }
                    opacity: 0.3
                    layer.enabled: box.visible
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: fade
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Rectangle {
                        width: box.w
                        height: box.w
                        color: Qt.darker(box.tint, 1.4)
                    }

                    Image {
                        width: box.w
                        height: box.w
                        source: box.near ? cover.url : ""
                        sourceSize: Qt.size(cover.pixels, cover.pixels)
                        fillMode: Image.PreserveAspectCrop
                        mirrorVertically: true
                        asynchronous: true
                    }
                }

                // Lomos reflejados: su color fundiéndose hacia abajo.
                Repeater {
                    model: [{ side: -1 }, { side: 1 }]

                    Rectangle {
                        required property var modelData
                        readonly property bool isLeft: modelData.side < 0
                        visible: isLeft ? box.a > 0.5 : box.a < -0.5
                        width: box.t
                        height: box.w * root.reflection
                        transform: Matrix4x4 {
                            matrix: isLeft
                                ? root.faceMatrix([-box.w / 2, box.w / 2, box.t / 2], [0, 0, -1], [0, 1, 0],
                                                  box.a, box.s, box.bx, box.by)
                                : root.faceMatrix([box.w / 2, box.w / 2, -box.t / 2], [0, 0, 1], [0, 1, 0],
                                                  box.a, box.s, box.bx, box.by)
                        }
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.withAlpha(Qt.darker(box.tint, 1.3), 0.3) }
                            GradientStop { position: 0.5; color: root.withAlpha(Qt.darker(box.tint, 1.3), 0.05) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }

                // ---- Lomos ----
                Repeater {
                    model: [{ side: -1 }, { side: 1 }]

                    Rectangle {
                        id: spine
                        required property var modelData
                        readonly property bool isLeft: modelData.side < 0
                        // Solo se ve el lomo que mira a la cámara.
                        visible: isLeft ? box.a > 0.5 : box.a < -0.5
                        width: box.t
                        height: box.w
                        color: Qt.darker(box.tint, 1.2)
                        antialiasing: true
                        transform: Matrix4x4 {
                            matrix: spine.isLeft
                                ? root.faceMatrix([-box.w / 2, -box.w / 2, box.t / 2], [0, 0, -1], [0, 1, 0],
                                                  box.a, box.s, box.bx, box.by)
                                : root.faceMatrix([box.w / 2, -box.w / 2, -box.t / 2], [0, 0, 1], [0, 1, 0],
                                                  box.a, box.s, box.bx, box.by)
                        }

                        // Volumen: luz en el canto delantero, sombra en el trasero.
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: spine.isLeft ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(1, 1, 1, 0.22) }
                                GradientStop { position: 0.5; color: "transparent" }
                                GradientStop { position: 1; color: spine.isLeft ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.30) }
                            }
                        }

                        // Cantos de plástico arriba y abajo.
                        Rectangle { width: parent.width; height: Math.max(1, box.w * 0.012); color: Qt.rgba(1, 1, 1, 0.18) }
                        Rectangle { y: parent.height - height; width: parent.width; height: Math.max(1, box.w * 0.012); color: Qt.rgba(0, 0, 0, 0.3) }

                        Text {
                            anchors.centerIn: parent
                            width: spine.height - box.w * 0.12
                            height: spine.width
                            rotation: 90
                            text: box.modelData.title
                            color: Theme.text
                            font.pixelSize: Math.max(8, Math.round(box.t * 0.42))
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.4
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        TapHandler { onTapped: box.select() }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: eventPoint => box.Window.window.openMenu(box.modelData, eventPoint.scenePosition)
                        }
                    }
                }

                // ---- Frontal ----
                Item {
                    id: front
                    width: box.w
                    height: box.w
                    transform: Matrix4x4 {
                        matrix: root.faceMatrix([-box.w / 2, -box.w / 2, -box.t / 2], [1, 0, 0], [0, 1, 0],
                                                box.a, box.s, box.bx, box.by)
                    }

                    // Queda tapado por la carátula.
                    TintProbe {
                        id: probe
                        thumb: box.near ? box.modelData.thumb : ""
                    }

                    Cover {
                        id: cover
                        anchors.fill: parent
                        thumb: box.modelData.thumb
                        pixels: 544
                        load: box.near
                    }

                    // Brillo del plástico: reflejo diagonal arriba a la izquierda.
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.10) }
                            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.03) }
                            GradientStop { position: 0.36; color: "transparent" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                            GradientStop { position: 0.25; color: "transparent" }
                            GradientStop { position: 0.8; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.18) }
                        }
                    }

                    // Marco de la caja, del color de la carátula.
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: Math.max(1.5, box.w * 0.014)
                        border.color: root.withAlpha(Qt.lighter(box.tint, 1.35), 0.85)
                        antialiasing: true
                    }

                    // Las de los lados, algo más oscuras.
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: 0.2 * Math.min(1, box.u)
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) Player.prefetchItem(JSON.stringify(box.modelData))
                    }

                    TapHandler { onTapped: box.select() }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: eventPoint => box.Window.window.openMenu(box.modelData, eventPoint.scenePosition)
                    }
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.centerY + root.side * root.centerScale / 2 + 22
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
