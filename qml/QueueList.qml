import QtQuick
import app.musicplayer

// Cola de reproducción: clic para saltar a una pista, clic derecho para su menú (lleva
// `queueIndex`) y arrastrar una fila para reordenarla. La usan el panel derecho y la pantalla
// «Sonando».
//
// El modelo es el número de pistas, no la lista: así, al soltar una fila (la cola cambia pero
// no su tamaño) la vista no se reconstruye ni vuelve arriba; cada fila lee su pista de
// `Catalog.queue`.
ListView {
    id: root

    property int rowHeight: 56
    property int coverSize: 40
    property int titleSize: 14
    property real rowRadius: 10
    // Al cambiar de pista: true = la que suena arriba del todo; false = basta con que se vea.
    property bool followTop: false
    // Pone «Sonando» en lugar de la duración de la que suena.
    property bool showPlaying: false

    // Arrastre en curso: fila que se arrastra (-1 ninguna), hueco donde caería, dónde se pulsó
    // (en coordenadas del contenido) y dónde está el puntero (en las de la vista).
    property int dragFrom: -1
    property int dragTo: -1
    property real pressY: 0
    property real pointerY: 0
    readonly property real dragShift: dragFrom < 0 ? 0 : pointerY + contentY - pressY
    // Al soltar, las filas vuelven a su sitio sin animarse (ya muestran el orden nuevo).
    property bool dropping: false

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: dragFrom < 0
    model: Catalog.queue.length

    function follow() {
        if (dragFrom < 0 && count > 0)
            positionViewAtIndex(Math.max(0, Player.index), followTop ? ListView.Beginning : ListView.Contain)
    }
    onCountChanged: follow()
    onVisibleChanged: if (visible) follow()
    Connections {
        target: Player
        function onIndexChanged() { root.follow() }
    }

    function startDrag(index, y) {
        dragFrom = index
        dragTo = index
        pressY = y + contentY
        pointerY = y
    }

    onDragShiftChanged: {
        if (dragFrom >= 0)
            dragTo = Math.max(0, Math.min(count - 1, dragFrom + Math.round(dragShift / rowHeight)))
    }

    function endDrag() {
        const from = dragFrom
        const to = dragTo
        dropping = true
        if (from >= 0 && to >= 0 && from !== to)
            Player.moveInQueue(from, to)
        dragFrom = -1
        dragTo = -1
        Qt.callLater(() => root.dropping = false)
    }

    // Arrastrando cerca de un borde, la lista se desplaza sola.
    Timer {
        readonly property int edge: 40
        running: root.dragFrom >= 0 && (root.pointerY < edge || root.pointerY > root.height - edge)
        interval: 16
        repeat: true
        onTriggered: {
            const step = root.pointerY < edge ? -8 : 8
            root.contentY = Math.max(0, Math.min(root.contentHeight - root.height, root.contentY + step))
        }
    }

    delegate: Item {
        id: row
        required property int index
        readonly property var track: Catalog.queue[index] || ({ title: "", artist: "", thumb: "", duration: 0 })
        readonly property bool current: index === Player.index
        readonly property bool dragged: index === root.dragFrom
        // Desplazamiento mientras se arrastra: la fila arrastrada sigue al puntero y las que
        // quedan entre su sitio y el hueco se apartan una fila.
        readonly property real shift: dragged ? root.dragShift
            : root.dragFrom < 0 ? 0
            : root.dragFrom < root.dragTo && index > root.dragFrom && index <= root.dragTo ? -root.rowHeight
            : root.dragFrom > root.dragTo && index >= root.dragTo && index < root.dragFrom ? root.rowHeight
            : 0

        width: root.width
        height: root.rowHeight
        z: dragged ? 2 : 0

        transform: Translate {
            y: row.shift
            Behavior on y {
                enabled: !row.dragged && !root.dropping
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Accessible.role: Accessible.Button
        Accessible.name: track.title + ", " + track.artist
        Accessible.onPressAction: Player.playIndex(index)

        Rectangle {
            anchors.fill: parent
            radius: root.rowRadius
            color: row.dragged ? Theme.controlActive
                : row.current ? Theme.controlActive
                : (mouse.containsMouse && root.dragFrom < 0 ? Theme.control : "transparent")
            border.width: row.dragged ? 1 : 0
            border.color: Theme.glassBorder
        }

        Cover {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: root.coverSize
            height: root.coverSize
            thumb: row.track.thumb
            pixels: 120
        }

        Column {
            x: root.coverSize + 18
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 60
            spacing: 1

            Text {
                width: parent.width
                text: row.track.title
                color: Theme.text
                font.pixelSize: root.titleSize
                font.weight: row.current ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.track.artist
                color: Theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.current && root.showPlaying ? "Sonando" : Theme.mmss(row.track.duration)
            color: row.current && root.showPlaying ? Theme.accent : Theme.textMuted
            font.pixelSize: 12
        }

        // Un `MouseArea` y no gestores: con `preventStealing` la lista no se queda el arrastre
        // para desplazarse, y el clic no atraviesa a lo que hay debajo.
        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            preventStealing: true
            cursorShape: root.dragFrom >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property bool moved: false
            property real startY: 0

            onPressed: event => {
                moved = false
                startY = mapToItem(root, event.x, event.y).y
            }
            onPositionChanged: event => {
                if (!(event.buttons & Qt.LeftButton))
                    return
                const y = mapToItem(root, event.x, event.y).y
                if (!moved) {
                    if (Math.abs(y - startY) < 6)
                        return
                    moved = true
                    root.startDrag(row.index, startY)
                }
                root.pointerY = y
            }
            onReleased: if (moved) root.endDrag()
            onCanceled: if (moved) root.endDrag()
            onClicked: event => {
                if (moved)
                    return
                if (event.button === Qt.RightButton)
                    row.Window.window.openMenu(Object.assign({ queueIndex: row.index }, row.track),
                                               mapToItem(null, event.x, event.y))
                else
                    Player.playIndex(row.index)
            }
        }
    }
}
