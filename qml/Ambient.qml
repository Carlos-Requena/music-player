import QtQuick
import QtQuick.Shapes
import app.musicplayer

// Modo ambiente: dos focos de color suaves, uno teñido por el elemento enfocado en el
// escenario y otro por la carátula que está sonando; en «Plano», un solo color sólido.
Item {
    id: root

    property color stageTint: "#1D3F8A"
    property color playingTint: "#F2553D"
    // Centro horizontal del escenario y del foco de "sonando", en píxeles.
    property real stageCenter: width * 0.37
    property real playingCenter: width * 0.88
    property real intensity: 1

    Behavior on stageTint { ColorAnimation { duration: 700 } }
    Behavior on playingTint { ColorAnimation { duration: 700 } }
    Behavior on stageCenter { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }

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

    Item {
        anchors.fill: parent
        visible: !Theme.ambientFlat
        opacity: root.intensity

        Glow {
            tint: root.stageTint
            cx: root.stageCenter
            cy: root.height * 0.36
            reach: root.width * (Theme.ambientSingle ? 0.6 : 0.46)
            strength: 0.85
        }

        // En modo «Suave» solo queda el foco del escenario: un único color.
        Glow {
            visible: !Theme.ambientSingle
            tint: root.playingTint
            cx: root.playingCenter
            cy: root.height * 0.2
            reach: root.width * 0.36
            strength: 0.6
        }

        Glow {
            visible: !Theme.ambientSingle
            tint: root.playingTint
            cx: root.width * 0.12
            cy: root.height * 1.05
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
