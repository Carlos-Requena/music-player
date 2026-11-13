pragma Singleton
import QtQuick
import app.musicplayer

// Datos que consume la interfaz: las secciones (JSON publicado por `Library`) y la
// letra de la pista actual (JSON publicado por `Player`), ya convertidos a objetos.
QtObject {
    readonly property var sections: [
        { id: "inicio", label: "Inicio" },
        { id: "explorar", label: "Explorar" },
        { id: "playlists", label: "Playlists", cuenta: true },
        { id: "albumes", label: "Álbumes" },
        { id: "megusta", label: "Me gusta", cuenta: true }
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

    // Detalle abierto (álbum, playlist o artista) o `null`.
    readonly property var detalle: Library.detalle === "" ? null : parse(Library.detalle)

    // Cola de reproducción: pistas `{ title, artist, thumb, videoId, duration }`.
    readonly property var queue: parse(Player.queue)

    // Lista temporal: pistas con el mismo formato que la cola.
    readonly property var temporal: parse(Player.temporal)

    // Líneas `{ t, text }` de la pista que suena; vacío si no hay letra sincronizada.
    readonly property var lyrics: parse(Player.lyrics)

    function parse(json) {
        if (json === "")
            return []
        try {
            return JSON.parse(json)
        } catch (error) {
            return []
        }
    }

    function zonas(section) {
        switch (section) {
        case "explorar": return explorar
        case "playlists": return playlists
        case "albumes": return albumes
        case "buscar": return busqueda
        case "megusta": return megusta
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
        default: return "tu biblioteca"
        }
    }

    function label(section) {
        if (section === "buscar")
            return "Búsqueda"
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

    // Fracción cantada (0–1) de la línea `line` en `position`.
    function lineProgress(line, position) {
        if (line < 0 || line >= lyrics.length)
            return 0
        const start = lyrics[line].t
        const end = line + 1 < lyrics.length ? lyrics[line + 1].t : start + 6
        return Math.max(0, Math.min(1, (position - start) / (end - start)))
    }
}
