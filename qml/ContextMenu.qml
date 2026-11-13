import QtQuick
import app.musicplayer

// Menú contextual (clic derecho) de una canción, álbum o playlist, y aviso breve de lo hecho.
// Se abre con `show(item, x, y)`; `item` es una tarjeta del catálogo o una pista de la cola.
Item {
    id: root

    property var item: null
    property bool opened: false
    property Item backdrop: null

    readonly property bool isSong: item !== null && (item.artist !== undefined || item.kind === "song")
    readonly property var entries: {
        if (item === null)
            return []
        const out = [{ id: "play", label: "Reproducir", icon: Theme.iconPlay }]
        out.push({ id: "temporal", label: isSong ? "Añadir a la lista temporal" : "Añadir todo a la lista temporal", icon: Theme.iconTemporal })
        return out
    }

    function show(target, px, py) {
        item = target
        opened = true
        menu.x = Math.max(8, Math.min(px, width - menu.width - 8))
        menu.y = Math.max(8, Math.min(py, height - menu.height - 8))
        menu.forceActiveFocus()
    }

    function close() {
        opened = false
    }

    function notify(text) {
        toast.text = text
        toastTimer.restart()
    }

    function run(action) {
        const target = item
        close()
        if (!target)
            return
        if (action === "play") {
            if (target.artist !== undefined)
                Player.playTracks(JSON.stringify([target]), 0, false)
            else if (target.kind === "song" || target.playlistId)
                Player.playItem(JSON.stringify(target))
        } else if (action === "temporal") {
            Player.addToTemporal(JSON.stringify(target))
            notify(isSongItem(target) ? "«" + target.title + "» añadida a la lista temporal"
                                      : "Añadiendo las canciones de «" + target.title + "» a la lista temporal")
        }
    }

    function isSongItem(target) {
        return target.artist !== undefined || target.kind === "song"
    }

    // Un clic fuera cierra el menú. Se cierra al soltar: si se ocultara al pulsar, el resto
    // del clic llegaría a lo que hay debajo.
    MouseArea {
        anchors.fill: parent
        visible: root.opened
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
    }

    Glass {
        id: menu
        visible: root.opened
        width: 300
        height: list.height + 12
        radius: 14
        tint: Theme.glassStrong
        backdrop: root.backdrop

        Keys.onEscapePressed: root.close()

        // Los clics en el menú no atraviesan a la vista de debajo.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: list
            x: 6
            y: 6
            width: parent.width - 12

            Text {
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                topPadding: 6
                bottomPadding: 6
                text: root.item ? root.item.title : ""
                color: Theme.textMuted
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Repeater {
                model: root.entries

                Item {
                    id: entry
                    required property var modelData
                    width: list.width
                    height: Theme.hit
                    activeFocusOnTab: true

                    Accessible.role: Accessible.MenuItem
                    Accessible.name: modelData.label
                    Accessible.onPressAction: root.run(modelData.id)
                    Keys.onReturnPressed: root.run(modelData.id)

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: entryHover.hovered || entry.activeFocus ? Theme.controlActive : "transparent"
                    }

                    Icon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        path: entry.modelData.icon
                        size: 18
                        filled: entry.modelData.id === "play"
                    }

                    Text {
                        x: 42
                        width: parent.width - 52
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label
                        color: Theme.text
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        id: entryHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    // Agarre exclusivo al pulsar: el clic no llega a la carátula de debajo.
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.run(entry.modelData.id)
                    }
                }
            }
        }
    }

    // Aviso breve encima de la barra de reproducción.
    Rectangle {
        id: toastBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 150
        width: toast.implicitWidth + 36
        height: 40
        radius: 20
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        opacity: toastTimer.running ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Text {
            id: toast
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 14
        }

        Timer {
            id: toastTimer
            interval: 2200
        }
    }
}
