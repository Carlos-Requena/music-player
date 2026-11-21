import QtQuick
import app.musicplayer

// Pestañas de categorías de la sección Playlists: «Todas», las del usuario y «+» para crear
// una. Clic derecho en una pestaña: renombrarla o borrarla (desde `ContextMenu`). ↑/↓ y
// RePág/AvPág cambian de pestaña desde la estantería (`SectionView`).
Glass {
    id: root

    // Pestaña en edición: "" ninguna, "+" una nueva, o el nombre de la que se renombra.
    property string editing: ""
    // Playlist que entra en la categoría nueva al crearla (desde el menú de una playlist).
    property string pendingPlaylist: ""

    signal done()

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.hit + 8
    radius: height / 2

    // Abre el campo para crear una categoría (con `playlistId` dentro, si se da).
    function create(playlistId) {
        pendingPlaylist = playlistId || ""
        editing = "+"
    }

    function rename(name) {
        pendingPlaylist = ""
        editing = name
    }

    function commit(text) {
        const was = editing
        if (was === "")
            return
        editing = ""
        if (was === "+") {
            const name = Catalog.createCategoria(text, pendingPlaylist)
            if (name !== "")
                Catalog.chooseCategoria(name)
        } else {
            Catalog.renameCategoria(was, text)
        }
        pendingPlaylist = ""
        root.done()
    }

    function cancel() {
        editing = ""
        pendingPlaylist = ""
        root.done()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: [""].concat(Catalog.categorias.map(c => c.nombre))

            // Una pestaña por categoría (regla de dos: la elegida, en blanco). Al renombrarla, su
            // sitio lo ocupa un campo de texto.
            Item {
                id: tab
                required property string modelData
                readonly property bool renaming: modelData !== "" && root.editing === modelData
                readonly property string label: modelData === "" ? "Todas" : modelData

                width: renaming ? 180 : button.implicitWidth
                height: Theme.hit

                TabButton {
                    id: button
                    anchors.fill: parent
                    visible: !tab.renaming
                    activeFocusOnTab: !tab.renaming
                    text: tab.label
                    chosen: tab.modelData === Catalog.categoria
                    navigate: true
                    Accessible.name: "Categoría " + tab.label
                    onClicked: Catalog.chooseCategoria(tab.modelData)
                    onContextRequested: scenePoint => {
                        if (tab.modelData !== "")
                            tab.Window.window.openMenu({ kind: "categoria", title: tab.modelData }, scenePoint)
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: tab.renaming
                    sourceComponent: nameField
                    onLoaded: {
                        item.text = tab.modelData
                        item.start()
                    }
                }
            }
        }

        Item {
            id: add
            width: root.editing === "+" ? 180 : Theme.hit
            height: Theme.hit

            IconButton {
                anchors.centerIn: parent
                visible: root.editing !== "+"
                icon: Theme.iconPlus
                iconSize: 18
                label: "Nueva categoría de playlists"
                onClicked: root.create("")
            }

            Loader {
                anchors.fill: parent
                active: root.editing === "+"
                sourceComponent: nameField
                onLoaded: item.start()
            }
        }
    }

    Component {
        id: nameField

        TextField {
            radius: height / 2
            placeholder: "Nombre de la categoría"

            function start() {
                forceFocus()
            }

            onCommitted: text => {
                // Al salir del campo sin escribir nada se cancela.
                if (root.editing === "")
                    return
                if (text.trim() === "")
                    root.cancel()
                else
                    root.commit(text)
            }

            Keys.onEscapePressed: root.cancel()
        }
    }
}
