import QtQuick
import QtQuick.Shapes
import app.musicplayer

// Modo ambiente: dos focos de color suaves, uno teñido por el elemento enfocado en el
// escenario y otro por la carátula que está sonando; en «Plano», un solo color sólido; en
// «Fluido», la propia carátula (`thumb`) muy desenfocada y deformada.
Item {
    id: root

    property color stageTint: "#1D3F8A"
    property color playingTint: "#F2553D"
    // Centro horizontal del escenario y del foco de "sonando", en píxeles.
    property real stageCenter: width * 0.37
    property real playingCenter: width * 0.88
    property real intensity: 1
    // Carátula del fondo «Fluido»: la del elemento enfocado o la de lo que suena.
    property string thumb: ""
    // Cuánto se oscurece el fondo «Fluido» hacia el color de la skin para que el texto se lea.
    property real fluidDarken: 0.45

    Behavior on stageTint { ColorAnimation { duration: 700 } }
    Behavior on playingTint { ColorAnimation { duration: 700 } }
    Behavior on stageCenter { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }

    // Deriva lenta (opción `ambienteMovimiento`): los focos pasean despacio, cada uno por su
    // camino, mientras suena música. Lo enciende quien usa el fondo (`moving`). Se avanza con un
    // temporizador a 10 Hz y no con una animación a 60: con un paseo tan lento no se notan los
    // saltos y cuesta ~5 % de CPU en vez de ~30 % (cada vidrio vuelve a desenfocar el fondo en
    // cada fotograma). Se para en pausa, con la ventana oculta o minimizada (mini reproductor),
    // en «Plano» y sin ambiente; al parar, los focos se quedan donde estaban.
    property bool moving: false
    readonly property bool windowShown: Window.visibility !== Window.Hidden && Window.visibility !== Window.Minimized
    readonly property bool drifting: moving && visible && windowShown && Player.playing
                                     && Theme.ambientOn && !Theme.ambientFlat
    // Ángulo de la deriva: una vuelta cada ~40 s. Crece sin volver a cero para que los caminos
    // con otros multiplicadores no salten.
    property real phase: 0
    Timer {
        interval: 100
        repeat: true
        running: root.drifting
        onTriggered: root.phase += 2 * Math.PI / 400
    }

    component Glow: Shape {
        id: glow
        property color tint
        property real cx
        property real cy
        property real reach
        property real strength: 0.8

        anchors.fill: parent

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.cx
                centerY: glow.cy
                focalX: glow.cx
                focalY: glow.cy
                centerRadius: glow.reach
                GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, glow.strength) }
                GradientStop { position: 1; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
            }
            startX: 0
            startY: 0
            PathLine { x: glow.width; y: 0 }
            PathLine { x: glow.width; y: glow.height }
            PathLine { x: 0; y: glow.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // En modo «Plano», el color de fondo mezclado con el de lo enfocado: un solo color sólido,
    // oscuro para que el texto se lea, y sin focos ni suelo (los degradados son lo que sale con
    // escalones en algunas pantallas).
    Rectangle {
        anchors.fill: parent
        color: Theme.ambientFlat
            ? Qt.tint(Theme.ground, Qt.rgba(root.stageTint.r, root.stageTint.g, root.stageTint.b, 0.42 * Math.min(1, root.intensity)))
            : Theme.ground
    }

    // ---- «Fluido» ----
    // La carátula, pedida diminuta (32 px), la desenfoca y deforma `shaders/fluido.frag`. Al
    // cambiar de carátula se funde con la anterior en un segundo. Se dibuja a la mitad de la
    // resolución lógica (un cuarto en Retina) y se amplía: el resultado es tan suave que no se
    // nota y el sombreador trabaja con 16 veces menos píxeles. La animación avanza a 15 Hz con la
    // misma condición que la deriva (`drifting`); sin movimiento queda quieta.
    Loader {
        anchors.fill: parent
        active: Theme.ambientFluid && Theme.ambientOn
        sourceComponent: Item {
            id: fluid

            // Carátula en cada lado del fundido; `front` es la que se ve con `mixAmount` a 0.
            property int front: 0
            property real mixAmount: 0
            property real time: 0
            readonly property var covers: [coverA, coverB]

            function small(url) {
                return url.replace("w544-h544", "w60-h60")
            }

            // Espera un poco antes de cambiar: al recorrer la estantería deprisa no se encadenan
            // fundidos.
            Timer {
                id: settle
                interval: 150
                onTriggered: {
                    const url = fluid.small(root.thumb)
                    const back = fluid.covers[1 - fluid.front]
                    if (url === fluid.covers[fluid.front].source.toString())
                        return
                    fade.stop()
                    fluid.mixAmount = 0
                    back.source = url
                    if (back.status === Image.Ready)
                        fade.restart()
                }
            }
            Connections {
                target: root
                function onThumbChanged() { settle.restart() }
            }
            Component.onCompleted: coverA.source = small(root.thumb)

            component Tiny: Image {
                visible: false
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
            // Cuando la de detrás termina de cargar, empieza el fundido.
            Tiny { id: coverA; onStatusChanged: if (status === Image.Ready && fluid.front === 1) fade.restart() }
            Tiny { id: coverB; onStatusChanged: if (status === Image.Ready && fluid.front === 0) fade.restart() }

            NumberAnimation {
                id: fade
                target: fluid
                property: "mixAmount"
                from: 0
                to: 1
                duration: 1000
                easing.type: Easing.InOutSine
                onFinished: {
                    fluid.front = 1 - fluid.front
                    fluid.mixAmount = 0
                }
            }

            Timer {
                interval: 66
                repeat: true
                running: root.drifting
                onTriggered: fluid.time += 0.066
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))

                ShaderEffect {
                    anchors.fill: parent
                    property var source0: fluid.covers[fluid.front]
                    property var source1: fluid.covers[1 - fluid.front]
                    property real time: fluid.time
                    property real mixAmount: fluid.mixAmount
                    property real warp: 1.0
                    property real saturation: 1.5
                    property real darken: 1 - (1 - root.fluidDarken) * Math.min(1, root.intensity)
                    property real aspect: width / Math.max(1, height)
                    property color ground: Theme.ground
                    fragmentShader: "qrc:/qt/qml/app/musicplayer/shaders/fluido.frag.qsb"
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !Theme.ambientFlat && !Theme.ambientFluid
        opacity: root.intensity

        Glow {
            tint: root.stageTint
            cx: root.stageCenter + root.width * 0.1 * Math.sin(root.phase)
            cy: root.height * (0.36 + 0.09 * Math.cos(1.3 * root.phase))
            reach: root.width * (Theme.ambientSingle ? 0.6 : 0.46)
            strength: 0.85
        }

        // En modo «Suave» solo queda el foco del escenario: un único color.
        Glow {
            visible: !Theme.ambientSingle
            tint: root.playingTint
            cx: root.playingCenter - root.width * 0.08 * Math.cos(0.8 * root.phase)
            cy: root.height * (0.2 + 0.12 * Math.sin(root.phase))
            reach: root.width * 0.36
            strength: 0.6
        }

        Glow {
            visible: !Theme.ambientSingle
            tint: root.playingTint
            cx: root.width * (0.12 + 0.07 * Math.sin(0.6 * root.phase))
            cy: root.height * (1.05 - 0.06 * Math.cos(0.9 * root.phase))
            reach: root.width * 0.3
            strength: 0.35
        }
    }

    // Suelo oscuro: da contraste al texto inferior y recoge los reflejos de la estantería.
    Rectangle {
        anchors.fill: parent
        visible: !Theme.ambientFlat
        gradient: Gradient {
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0.015, 0.02, 0.035, 0.88) }
        }
    }
}
