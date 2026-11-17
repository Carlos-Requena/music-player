pragma Singleton
import QtQuick
import app.musicplayer

// Datos que consume la interfaz: las secciones (JSON publicado por `Library`) y la
// letra de la pista actual (JSON publicado por `Player`), ya convertidos a objetos.
QtObject {
    id: catalog

    readonly property var sections: [
        { id: "inicio", label: "Inicio" },
        { id: "explorar", label: "Explorar" },
        { id: "playlists", label: "Playlists", cuenta: true },
        { id: "albumes", label: "Álbumes" },
        { id: "megusta", label: "Me gusta", cuenta: true },
        { id: "historial", label: "Historial", cuenta: true }
    ]

    readonly property var views: [
        { id: "lomos", label: "Lomos" },
        { id: "cubeta", label: "Cubeta" },
        { id: "muro", label: "Muro" }
    ]

    readonly property var inicio: parse(Library.inicio)
    readonly property var explorar: parse(Library.explorar)
    readonly property var playlists: parse(Library.playlists)
    readonly property var albumes: parse(Library.albumes)
    readonly property var busqueda: parse(Library.busqueda)
    readonly property var megusta: parse(Library.megusta)
    readonly property var historial: parse(Library.historial)

    // Detalle abierto (álbum, playlist o artista) o `null`.
    readonly property var detalle: Library.detalle === "" ? null : parse(Library.detalle)

    // Cola de reproducción: pistas `{ title, artist, thumb, videoId, duration }`.
    readonly property var queue: parse(Player.queue)

    // Pista que suena (de la cola) y su retraso de letra, en segundos, guardado por canción en
    // las opciones (`retraso:<videoId>`). Positivo: la letra va más tarde.
    readonly property string currentVideoId: Player.index >= 0 && Player.index < queue.length ? queue[Player.index].videoId : ""
    readonly property real lyricsDelay: {
        void AppSettings.revision
        const stored = currentVideoId !== "" ? AppSettings.opcion("retraso:" + currentVideoId) : ""
        return stored !== "" ? parseFloat(stored) : 0
    }
    // Momento de la letra: la posición de la canción corregida con el retraso.
    readonly property real lyricsTime: Player.position - lyricsDelay

    function setLyricsDelay(seconds) {
        if (currentVideoId === "")
            return
        const rounded = Math.round(seconds * 10) / 10
        AppSettings.setOpcion("retraso:" + currentVideoId, Math.abs(rounded) < 0.05 ? "" : rounded.toFixed(1))
    }

    // Lista temporal: pistas con el mismo formato que la cola.
    readonly property var temporal: parse(Player.temporal)

    // Letras de la pista que suena, una por fuente y de mejor a peor:
    // `[{ id, label, words, lines }]` (`words`: trae el tiempo de cada palabra).
    readonly property var lyricsSources: parse(Player.lyrics)
    // Fuente que se muestra: la elegida para esta canción (`origen:<videoId>`, pulsando el pie
    // de la letra), si no la preferida en Opciones (`letraOrigen`) y, si no, la mejor.
    //
    // Se guarda y solo se sustituye si cambia la fuente: cada fuente que llega vuelve a publicar
    // todas, y cada opción que cambia (el retraso de la letra, por ejemplo) sube
    // `AppSettings.revision`; con un enlace, cada vez salía un objeto nuevo y la letra se
    // reconstruía entera aunque fuera la misma.
    property var lyricsChosen: null
    function chooseLyrics() {
        const sources = lyricsSources
        let best = sources.length ? sources[0] : null
        const wanted = [currentVideoId !== "" ? AppSettings.opcion("origen:" + currentVideoId) : "",
                        AppSettings.opcion("letraOrigen")]
        search: for (const id of wanted)
            for (const source of sources)
                if (id !== "" && source.id === id) {
                    best = source
                    break search
                }
        if (best === null || lyricsChosen === null || best.id !== lyricsChosen.id)
            lyricsChosen = best
    }
    onLyricsSourcesChanged: chooseLyrics()
    onCurrentVideoIdChanged: chooseLyrics()
    readonly property Connections settingsWatch: Connections {
        target: AppSettings
        function onRevisionChanged() { catalog.chooseLyrics() }
    }
    // Líneas `{ t, text, w }` de la letra que se muestra; vacío si no hay letra sincronizada.
    readonly property var lyrics: lyricsChosen ? lyricsChosen.lines : []

    // Pasa a la siguiente fuente que tenga letra de esta canción y lo recuerda para ella.
    function nextLyricsSource() {
        if (lyricsSources.length < 2 || currentVideoId === "" || !lyricsChosen)
            return
        const at = lyricsSources.findIndex(source => source.id === lyricsChosen.id)
        const next = lyricsSources[(at + 1) % lyricsSources.length]
        AppSettings.setOpcion("origen:" + currentVideoId, next.id)
    }

    function parse(json) {
        if (json === "")
            return []
        try {
            return JSON.parse(json)
        } catch (error) {
            return []
        }
    }

    // Categorías de playlists (OST, Gym…): `[{ nombre, ids: [playlistId…] }]`. YouTube Music
    // no tiene carpetas, así que viven en las opciones locales (`categorias`). `categoria` es
    // la pestaña elegida; vacía = «Todas».
    //
    // Se analiza desde el texto guardado (`categoriasJson`) y no desde `AppSettings.revision`:
    // una propiedad de texto solo avisa si cambia, y cualquier otra opción (el retraso de la letra,
    // por ejemplo) ya no reconstruye la sección de Playlists.
    readonly property string categoriasJson: { void AppSettings.revision; return AppSettings.opcion("categorias") }
    readonly property var categorias: {
        const list = parse(categoriasJson)
        return Array.isArray(list) ? list : []
    }
    readonly property string categoria: {
        void AppSettings.revision
        const name = AppSettings.opcion("categoria")
        return categorias.some(c => c.nombre === name) ? name : ""
    }

    // Portadas cambiadas en esta sesión (`playlistId` → imagen local), hasta que YouTube
    // Music devuelva la nueva.
    property var portadas: ({})

    function setPortada(playlistId, source) {
        const copy = Object.assign({}, portadas)
        copy[playlistId] = source
        portadas = copy
    }

    // Playlists de la sección con la categoría elegida y las portadas nuevas aplicadas.
    readonly property var playlistsVista: {
        const covers = portadas
        const withCover = item => covers[item.playlistId] ? Object.assign({}, item, { thumb: covers[item.playlistId] }) : item
        const all = playlists.map(zona => ({ titulo: zona.titulo, items: zona.items.map(withCover) }))
        if (categoria === "")
            return all
        const cat = categorias.find(c => c.nombre === categoria)
        const byId = {}
        for (const zona of all)
            for (const item of zona.items)
                byId[item.playlistId] = item
        return [{ titulo: categoria, items: cat.ids.filter(id => byId[id]).map(id => byId[id]) }]
    }

    // Playlist de la biblioteca de la cuenta (solo esas se pueden categorizar).
    function isOwnPlaylist(item) {
        if (!item || item.kind !== "playlist" || !item.playlistId)
            return false
        return playlists.some(zona => zona.items.some(i => i.playlistId === item.playlistId))
    }

    // Playlists en las que se puede guardar música: las de la biblioteca menos «Me gusta»
    // (va por otro camino) y, si se sabe el nombre de la cuenta, solo las suyas: las guardadas
    // de otras personas no se pueden editar.
    readonly property var editablePlaylists: {
        const all = []
        for (const zona of playlists)
            for (const item of zona.items)
                if (item.playlistId && item.playlistId !== "LM" && !all.some(i => i.playlistId === item.playlistId))
                    all.push(item)
        const owner = Account.name
        const mine = owner !== "" ? all.filter(i => i.subtitle.startsWith(owner + " •")) : []
        return mine.length ? mine : all
    }

    function saveCategorias(list) {
        AppSettings.setOpcion("categorias", list.length ? JSON.stringify(list) : "")
    }

    function chooseCategoria(name) {
        AppSettings.setOpcion("categoria", name)
    }

    // Pasa a la pestaña vecina (`delta` = ±1), con «Todas» como la primera.
    function stepCategoria(delta) {
        const names = [""].concat(categorias.map(c => c.nombre))
        const at = names.indexOf(categoria)
        chooseCategoria(names[(at + delta + names.length) % names.length])
    }

    // Crea la categoría `name` (con `playlistId` dentro, si se da). Devuelve el nombre final
    // o "" si no vale (vacío o repetido).
    function createCategoria(name, playlistId) {
        name = name.trim()
        if (name === "" || categorias.some(c => c.nombre.toLowerCase() === name.toLowerCase()))
            return ""
        saveCategorias(categorias.concat([{ nombre: name, ids: playlistId ? [playlistId] : [] }]))
        return name
    }

    function renameCategoria(oldName, newName) {
        newName = newName.trim()
        if (newName === "" || newName === oldName
                || categorias.some(c => c.nombre !== oldName && c.nombre.toLowerCase() === newName.toLowerCase()))
            return false
        const wasCurrent = categoria === oldName
        saveCategorias(categorias.map(c => c.nombre === oldName ? { nombre: newName, ids: c.ids } : c))
        if (wasCurrent)
            chooseCategoria(newName)
        return true
    }

    function removeCategoria(name) {
        saveCategorias(categorias.filter(c => c.nombre !== name))
    }

    function inCategoria(name, playlistId) {
        const cat = categorias.find(c => c.nombre === name)
        return cat !== undefined && cat.ids.indexOf(playlistId) >= 0
    }

    // Mete o saca `playlistId` de la categoría `name`.
    function toggleInCategoria(name, playlistId) {
        saveCategorias(categorias.map(c => {
            if (c.nombre !== name)
                return c
            const ids = c.ids.indexOf(playlistId) >= 0 ? c.ids.filter(id => id !== playlistId) : c.ids.concat([playlistId])
            return { nombre: c.nombre, ids: ids }
        }))
    }

    // Los elementos de todas las zonas, seguidos (las vistas de uno en uno: Lomos y Cubeta).
    function allItems(zonas) {
        return [].concat(...zonas.map(zona => zona.items))
    }

    function zonas(section) {
        switch (section) {
        case "explorar": return explorar
        case "playlists": return playlistsVista
        case "albumes": return albumes
        case "buscar": return busqueda
        case "megusta": return megusta
        case "historial": return historial
        default: return inicio
        }
    }

    // Secciones que solo tienen contenido con sesión iniciada.
    function needsAccount(section) {
        for (const s of sections)
            if (s.id === section)
                return s.cuenta === true
        return false
    }

    // Nombre de una sección personal dentro de una frase («tus playlists»).
    function ownLabel(section) {
        switch (section) {
        case "playlists": return "tus playlists"
        case "megusta": return "tus «Me gusta»"
        case "historial": return "tu historial de escucha"
        default: return "tu biblioteca"
        }
    }

    function label(section) {
        if (section === "buscar")
            return "Búsqueda"
        if (section === "playlists" && categoria !== "")
            return categoria
        for (const s of sections)
            if (s.id === section)
                return s.label
        return ""
    }

    // Índice de la línea que suena en `position` (segundos); -1 si no hay letra.
    function lineAt(position) {
        let current = -1
        for (let i = 0; i < lyrics.length && lyrics[i].t <= position; ++i)
            current = i
        return lyrics.length ? Math.max(0, current) : -1
    }
}
