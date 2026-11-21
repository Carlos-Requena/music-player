import QtQuick
import app.musicplayer

// Rueda del ratón con muescas para una vista que se desplaza en vertical (`view`). En Windows y
// Linux, Qt mueve una lista muy poco por cada muesca; esto la baja `notch` píxeles por muesca,
// con una animación corta, y acumula las muescas seguidas. El trackpad y la rueda de macOS traen
// `pixelDelta` (desplazamiento fino, que ya va bien) y se dejan a la propia vista.
WheelHandler {
    id: root

    property Flickable view
    property real notch: 120
    // La vista ya anima `contentY` con un `Behavior` (el Muro): basta con fijar el destino.
    property bool behaviorAnimates: false
    // Destino acumulado de las muescas seguidas.
    property real goal: 0

    target: null
    orientation: Qt.Vertical

    onWheel: event => {
        if (!view || event.pixelDelta.y !== 0 || event.angleDelta.y === 0 || (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = false
            return
        }
        const top = view.originY - view.topMargin
        const bottom = Math.max(top, view.originY + view.contentHeight + view.bottomMargin - view.height)
        const from = scroll.running || (behaviorAnimates && streak.running) ? goal : view.contentY
        goal = Math.max(top, Math.min(bottom, from - event.angleDelta.y / 120 * notch))
        view.cancelFlick()
        if (behaviorAnimates) {
            view.contentY = goal
        } else {
            scroll.to = goal
            scroll.restart()
        }
        streak.restart()
        event.accepted = true
    }

    property NumberAnimation scroll: NumberAnimation {
        target: root.view
        property: "contentY"
        duration: Theme.animFast
        easing.type: Easing.OutCubic
    }

    // Muescas seguidas (menos de un cuarto de segundo entre una y otra) acumulan el destino.
    property Timer streak: Timer { interval: 250 }
}
