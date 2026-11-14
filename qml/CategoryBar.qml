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

            Item {
                id: tab
                required property string modelData
                readonly property bool active: modelData === Catalog.categoria
                readonly property bool renaming: modelData !== "" && root.editing === modelData
                readonly property string label: modelData === "" ? "Todas" : modelData

                width: renaming ? 180 : text.implicitWidth + 26
                height: Theme.hit
                activeFocusOnTab: !renaming

                Accessible.role: Accessible.PageTab
                Accessible.name: "Categoría " + label
                Accessible.onPressAction: Catalog.chooseCategoria(modelData)
                Keys.onReturnPressed: Catalog.chooseCategoria(modelData)

                Rectangle {
                    anchors.fill: parent
                    visible: !tab.renaming
                    radius: height / 2
                    color: tab.active ? Theme.text : (tabHover.hovered ? Theme.control : "transparent")
                    border.width: tab.activeFocus ? 2 : 0
                    border.color: Theme.text

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    id: text
                    anchors.centerIn: parent
                    visible: !tab.renaming
                    text: tab.label
                    color: tab.active ? Theme.ground : Theme.textMuted
                    font.pixelSize: 14
                    font.weight: tab.active ? Font.DemiBold : Font.Normal
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

                HoverHandler {
                    id: tabHover
                    enabled: !tab.renaming
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: !tab.renaming
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Catalog.chooseCategoria(tab.modelData)
                }

                // «Todas» no se puede renombrar ni borrar.
                TapHandler {
                    enabled: !tab.renaming && tab.modelData !== ""
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: eventPoint => tab.Window.window.openMenu({ kind: "categoria", title: tab.modelData },
                                                                       eventPoint.scenePosition)
                }
            }
        }

        // «+»: crea una categoría; mientras se escribe el nombre, es un campo de texto.
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
