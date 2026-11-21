import QtQuick
import app.musicplayer

// Aro de foco de teclado, el mismo en todos los controles: 2 px del color del texto, separado
// 3 px del control para que también se vea sobre lo que es blanco (lo elegido al navegar, el
// botón principal). Se pone dentro del control: `FocusRing { shown: root.activeFocus; corner: … }`.
Rectangle {
    property bool shown: false
    // Radio del control al que rodea; el aro lo sigue a 3 px.
    property real corner: 0

    anchors.fill: parent
    anchors.margins: -3
    radius: corner + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.text
    visible: shown
}
