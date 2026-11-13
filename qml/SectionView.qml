import QtQuick
import app.musicplayer

// Muestra una sección (Inicio, Explorar, Playlists, Álbumes) con la vista elegida para ella.
FocusScope {
    id: root

    property string section: "inicio"
    property string view: "muro"

    readonly property var zonas: Catalog.zonas(section)
    readonly property var currentItem: loader.item ? loader.item.currentItem : null
    readonly property var focusedArt: currentItem ? currentItem.art : 0

    signal activated(var item)

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        sourceComponent: root.view === "lomos" ? lomos : (root.view === "cubeta" ? cubeta : muro)
    }

    Component {
        id: muro
        MuroView {
            zonas: root.zonas
            focus: true
            onActivated: item => root.activated(item)
        }
    }

    Component {
        id: lomos
        LomosView {
            zonas: root.zonas
            titulo: Catalog.label(root.section)
            focus: true
            onActivated: item => root.activated(item)
        }
    }

    Component {
        id: cubeta
        CubetaView {
            zonas: root.zonas
            titulo: Catalog.label(root.section)
            focus: true
            onActivated: item => root.activated(item)
        }
    }
}
