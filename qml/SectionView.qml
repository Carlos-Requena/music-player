import QtQuick
import app.musicplayer

// Muestra una sección (Inicio, Explorar, Playlists, Álbumes) con la vista elegida para ella.
FocusScope {
    id: root

    property string section: "inicio"
    property string view: "muro"

    readonly property var zonas: Catalog.zonas(section)
    // Las primeras canciones sueltas de la sección quedan resueltas de antemano.
    // (Solo se envían esas cuatro, no la fila entera.)
    onZonasChanged: if (zonas.length) Player.prefetchTracks(JSON.stringify(zonas[0].items.filter(item => item.kind === "song").slice(0, 4)), 4)
    readonly property var currentItem: loader.item ? loader.item.currentItem : null
    readonly property string focusedThumb: currentItem ? currentItem.thumb : ""

    signal activated(var item)
    // Muro y Lomos avisan de lo que hay bajo el puntero (ver `Main.hint`).
    signal hinted(var item, bool on)

    // Playlists con categorías: ↑/↓ (si la vista no los usa, como Lomos) y RePág/AvPág
    // cambian de pestaña. La estantería vuelve al principio al cambiar.
    Keys.onPressed: event => {
        if (section !== "playlists" || Catalog.categorias.length === 0)
            return
        const back = event.key === Qt.Key_Up || event.key === Qt.Key_PageUp
        const forward = event.key === Qt.Key_Down || event.key === Qt.Key_PageDown
        if (back || forward) {
            Catalog.stepCategoria(back ? -1 : 1)
            event.accepted = true
        }
    }

    Connections {
        target: Catalog
        function onCategoriaChanged() {
            if (root.section === "playlists")
                root.jump(0)
        }
    }

    // Lleva la vista al elemento `n` (solo las vistas lineales tienen índice).
    function jump(n) {
        if (loader.item && loader.item.index !== undefined)
            loader.item.index = n
    }

    // Avanza o retrocede `delta` elementos, como las flechas del teclado.
    function stepBy(delta) {
        if (loader.item && loader.item.step !== undefined)
            loader.item.step(delta)
    }

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        // Explorar en Muro: una tarjeta por categoría en vez de todas sus carátulas.
        sourceComponent: root.view === "lomos" ? lomos
                       : root.view === "cubeta" ? cubeta
                       : root.section === "explorar" ? categorias : muro
    }

    Component {
        id: categorias
        CategoriasView {
            zonas: root.zonas
            focus: true
            onActivated: item => root.activated(item)
        }
    }

    Component {
        id: muro
        MuroView {
            zonas: root.zonas
            focus: true
            onActivated: item => root.activated(item)
            onHinted: (item, on) => root.hinted(item, on)
        }
    }

    Component {
        id: lomos
        LomosView {
            zonas: root.zonas
            seccion: Catalog.label(root.section)
            focus: true
            onActivated: item => root.activated(item)
            onHinted: (item, on) => root.hinted(item, on)
        }
    }

    Component {
        id: cubeta
        CubetaView {
            zonas: root.zonas
            focus: true
            onActivated: item => root.activated(item)
        }
    }
}
