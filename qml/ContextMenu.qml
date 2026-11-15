import QtQuick
import QtQuick.Effects
import app.musicplayer

// Menú contextual (clic derecho) de una canción, álbum o playlist, y aviso breve de lo hecho.
// Se abre con `show(item, x, y)`; `item` es una tarjeta del catálogo, una pista de la cola
// (lleva `queueIndex`) o una pestaña de categoría. Las listas largas (playlists donde guardar,
// categorías) van en una subpágina para que el menú principal no crezca.
Item {
    id: root

    property var item: null
    property bool opened: false
    property Item backdrop: null
    // "" el menú principal, "listas" las playlists donde guardar, "categorias" las categorías.
    property string page: ""

    // Lo que el menú pide a la ventana (necesita el selector de archivos o la barra de
    // categorías, que viven allí).
    signal newCategoryRequested(string playlistId)
    signal renameCategoryRequested(string name)
    signal coverRequested(var item)

    readonly property bool isSong: item !== null && isSongItem(item)
    readonly property bool inQueue: item !== null && item.queueIndex !== undefined
    readonly property bool canSave: Account.signedIn && Catalog.editablePlaylists.length > 0

    readonly property var entries: {
        if (item === null)
            return []
        // Pestaña de categoría (clic derecho en la barra de Playlists).
        if (item.kind === "categoria")
            return [
                { id: "renombrar", label: "Renombrar", icon: Theme.iconEdit },
                { id: "borrar", label: "Borrar la categoría", icon: Theme.iconTrash }
            ]
        const back = { id: "volver", label: "Volver", icon: Theme.iconBack }
        if (page === "listas") {
            const out = [back]
            for (const list of Catalog.editablePlaylists)
                if (list.playlistId !== item.playlistId || isSong)
                    out.push({ id: "lista:" + list.playlistId, label: list.title, icon: Theme.iconPlus, extra: list.title })
            return out
        }
        if (page === "categorias") {
            const out = [back]
            for (const cat of Catalog.categorias) {
                const inside = cat.ids.indexOf(item.playlistId) >= 0
                out.push({ id: "cat:" + cat.nombre, label: cat.nombre,
                           icon: inside ? Theme.iconCheck : Theme.iconPlus, checked: inside })
            }
            out.push({ id: "nueva", label: "Nueva categoría…", icon: Theme.iconFolder })
            return out
        }

        const out = [{ id: "play", label: "Reproducir", icon: Theme.iconPlay }]
        if (inQueue) {
            // Pista de la cola: se reordena o se quita (la que suena se queda).
            const current = item.queueIndex === Player.index
            if (!current && item.queueIndex !== Player.index + 1)
                out.push({ id: "subir", label: "Reproducir a continuación", icon: Theme.iconPlayNext })
            if (!current)
                out.push({ id: "quitar", label: "Quitar de la cola", icon: Theme.iconClose })
        } else {
            out.push({ id: "siguiente", label: "Reproducir a continuación", icon: Theme.iconPlayNext })
            out.push({ id: "cola", label: "Añadir a la cola", icon: Theme.iconAddQueue })
        }
        out.push({ id: "temporal", label: isSong ? "Añadir a la lista temporal" : "Añadir todo a la lista temporal", icon: Theme.iconTemporal })
        if (canSave)
            out.push({ id: "page:listas", label: "Guardar en una playlist", icon: Theme.iconSaveList, more: true })
        // Playlists de la cuenta: categorías y portada.
        if (Catalog.isOwnPlaylist(item)) {
            const count = Catalog.categorias.filter(c => c.ids.indexOf(item.playlistId) >= 0).length
            out.push({ id: "page:categorias", label: count ? "Categorías · " + count : "Categorías", icon: Theme.iconFolder, more: true })
            out.push({ id: "portada", label: "Cambiar portada…", icon: Theme.iconImage })
        }
        return out
    }

    function show(target, px, py) {
        item = target
        page = ""
        opened = true
        place(px, py)
        menu.forceActiveFocus()
    }

    // Coloca el menú junto al punto, sin salirse de la ventana.
    function place(px, py) {
        menu.x = Math.max(8, Math.min(px, width - menu.width - 8))
        menu.y = Math.max(8, Math.min(py, height - menu.height - 8))
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
        if (!target)
            return
        // Cambiar de página no cierra el menú.
        if (action.startsWith("page:") || action === "volver") {
            page = action === "volver" ? "" : action.slice(5)
            scroller.contentY = 0
            // La subpágina puede ser más alta: se recoloca para que quepa.
            Qt.callLater(() => root.place(menu.x, menu.y))
            menu.forceActiveFocus()
            return
        }
        close()
        if (action === "renombrar") {
            root.renameCategoryRequested(target.title)
        } else if (action === "borrar") {
            Catalog.removeCategoria(target.title)
            notify("Categoría «" + target.title + "» borrada")
        } else if (action.startsWith("cat:")) {
            const name = action.slice(4)
            const inside = Catalog.inCategoria(name, target.playlistId)
            Catalog.toggleInCategoria(name, target.playlistId)
            notify(inside ? "«" + target.title + "» fuera de «" + name + "»" : "«" + target.title + "» añadida a «" + name + "»")
        } else if (action.startsWith("lista:")) {
            const id = action.slice(6)
            const list = Catalog.editablePlaylists.find(l => l.playlistId === id)
            Library.addToPlaylist(id, list ? list.title : "", JSON.stringify(target))
        } else if (action === "nueva") {
            root.newCategoryRequested(target.playlistId)
        } else if (action === "portada") {
            root.coverRequested(target)
        } else if (action === "play") {
            if (inQueueItem(target))
                Player.playIndex(target.queueIndex)
            else if (target.artist !== undefined)
                Player.playTracks(JSON.stringify([target]), 0, false)
            else if (target.kind === "song" || target.playlistId)
                Player.playItem(JSON.stringify(target))
        } else if (action === "siguiente" || action === "cola") {
            const next = action === "siguiente"
            const nothing = Catalog.queue.length === 0
            Player.enqueue(JSON.stringify(target), next)
            if (nothing)
                notify("Reproduciendo «" + target.title + "»")
            else if (isSongItem(target))
                notify(next ? "«" + target.title + "» sonará a continuación" : "«" + target.title + "» añadida a la cola")
            else
                notify(next ? "«" + target.title + "» sonará a continuación" : "Añadiendo «" + target.title + "» a la cola")
        } else if (action === "subir") {
            const to = target.queueIndex < Player.index ? Player.index : Player.index + 1
            Player.moveInQueue(target.queueIndex, to)
            notify("«" + target.title + "» sonará a continuación")
        } else if (action === "quitar") {
            Player.removeFromQueue(target.queueIndex)
            notify("«" + target.title + "» quitada de la cola")
        } else if (action === "temporal") {
            Player.addToTemporal(JSON.stringify(target))
            notify(isSongItem(target) ? "«" + target.title + "» añadida a la lista temporal"
                                      : "Añadiendo las canciones de «" + target.title + "» a la lista temporal")
        }
    }

    function isSongItem(target) {
        return target.artist !== undefined || target.kind === "song"
    }

    function inQueueItem(target) {
        return target.queueIndex !== undefined
    }

    // Resultado de «Guardar en una playlist» y del «Me gusta» de la mascota (van por la red).
    Connections {
        target: Library
        function onGuardado(mensaje, error) {
            root.notify(mensaje)
        }
        function onGustado(mensaje, error) {
            root.notify(mensaje)
        }
    }

    // Un clic fuera cierra el menú. Se cierra al soltar: si se ocultara al pulsar, el resto
    // del clic llegaría a lo que hay debajo.
    MouseArea {
        anchors.fill: parent
        visible: root.opened
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
    }

    // Sombra suave bajo el menú.
    RectangularShadow {
        visible: root.opened
        x: menu.x
        y: menu.y + 6
        width: menu.width
        height: menu.height
        radius: 14
        blur: 28
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    // Sin desenfoque de fondo: en un panel tan pequeño el desenfoque asomaba por fuera del
    // borde como un rectángulo borroso. Fondo casi opaco del color de la skin.
    Glass {
        id: menu
        visible: root.opened
        width: 300
        // Las listas largas (muchas playlists) se desplazan dentro del menú.
        height: Math.min(list.height + 12, root.height - 16)
        radius: 14
        tint: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.94)

        Keys.onEscapePressed: {
            if (root.page !== "")
                root.run("volver")
            else
                root.close()
        }

        // Los clics en el menú no atraviesan a la vista de debajo.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 6
            contentHeight: list.height
            clip: contentHeight > height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: scroller.width

                Text {
                    width: parent.width
                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 6
                    bottomPadding: 6
                    text: !root.item ? ""
                        : root.page === "listas" ? "Guardar «" + root.item.title + "» en…"
                        : root.page === "categorias" ? "Categorías de «" + root.item.title + "»"
                        : root.item.title
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
                        onActiveFocusChanged: if (activeFocus) scroller.contentY = Math.max(0, Math.min(y - 40, scroller.contentHeight - scroller.height))

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
                            color: entry.modelData.checked ? Theme.accent : Theme.text
                        }

                        Text {
                            x: 42
                            width: parent.width - 52 - (entry.modelData.more ? 20 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label
                            color: Theme.text
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        // Flecha de las entradas que abren una subpágina.
                        Icon {
                            visible: entry.modelData.more === true
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            path: Theme.iconForward
                            size: 14
                            color: Theme.textMuted
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
