import QtQuick
import QtQuick.Shapes
import app.musicplayer

// Modo ambiente: dos focos de color suaves, uno teñido por el elemento enfocado en el
// escenario y otro por la carátula que está sonando.
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

    Rectangle {
        anchors.fill: parent
        color: Theme.ground
    }

    Item {
        anchors.fill: parent
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
        gradient: Gradient {
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0.015, 0.02, 0.035, 0.88) }
        }
    }
}
