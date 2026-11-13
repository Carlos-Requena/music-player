pragma Singleton
import QtQuick

// Datos de ejemplo hasta que exista el cliente de YouTube Music.
// `art` es un índice de `covers` o una lista de cuatro índices (collage de playlist).
QtObject {
    readonly property var covers: [
        { kind: "sun", c: ["#E8472F", "#FFE7B8", "#0E6470", "#FFB070"], tint: "#F2553D", spine: "#E8472F", ink: "#151515" },
        { kind: "rings", c: ["#1E3A1A", "#C6F24E"], tint: "#2E6224", spine: "#1E3A1A", ink: "#C6F24E" },
        { kind: "stripes", c: ["#1A1210", "#C8743A"], tint: "#8A4A22", spine: "#1A1210", ink: "#E9A26B" },
        { kind: "dot", c: ["#EDE6D8", "#151515", "#E23B2E"], tint: "#8C8578", spine: "#EDE6D8", ink: "#151515" },
        { kind: "moon", c: ["#1D3F8A", "#F3EBD2", "#0B1B3A"], tint: "#1D3F8A", spine: "#16306C", ink: "#F3EBD2" },
        { kind: "half", c: ["#F6C945", "#D4246E"], tint: "#D4246E", spine: "#F6C945", ink: "#151515" },
        { kind: "bars", c: ["#111111", "#EDEDED"], tint: "#55585E", spine: "#1B1B1B", ink: "#FFFFFF" },
        { kind: "arch", c: ["#B5532E", "#E8D3B0", "#2B1A12"], tint: "#B5532E", spine: "#B5532E", ink: "#FFFFFF" },
        { kind: "checker", c: ["#F4A7B9", "#FCE8D8"], tint: "#C76A84", spine: "#F4A7B9", ink: "#151515" },
        { kind: "cross", c: ["#C2261C", "#F4F1EA"], tint: "#C2261C", spine: "#C2261C", ink: "#FFFFFF" },
        { kind: "waves", c: ["#0F4C5C", "#2A7F8E"], tint: "#12607A", spine: "#0F4C5C", ink: "#FFFFFF" },
        { kind: "orbit", c: ["#0B0B0F", "#FFFFFF", "#FF7A3D"], tint: "#3A3A46", spine: "#0B0B0F", ink: "#FFFFFF" }
    ]

    function first(art) {
        return typeof art === "number" ? art : art[0]
    }

    function cover(art) {
        return covers[first(art) % covers.length]
    }

    function tint(art) {
        return cover(art).tint
    }

    function it(title, subtitle, art) {
        return { title: title, subtitle: subtitle, art: art }
    }

    readonly property var inicio: [
        { titulo: "Volver a escuchar", items: [
            it("Me gusta", "Playlist automática", [9, 0, 5, 2]),
            it("Jardín eléctrico", "Álbum · Órbita Baja", 1),
            it("Azul casi negro", "Álbum · Vera Luján", 4),
            it("Noche de cobre", "Álbum · Sal y Cobre", 2),
            it("Domingo lento", "Playlist", [10, 4, 8, 3]),
            it("Para programar", "Playlist", [6, 11, 10, 4])
        ] },
        { titulo: "Mixes para ti", items: [
            it("Mi supermix", "Vera Luján, Órbita Baja…", [4, 1, 0, 11]),
            it("Mix de descubrimiento", "Música nueva cada lunes", [11, 8, 5, 7]),
            it("Mix para concentrarse", "Mar de Fondo, Nébula Sur…", [10, 6, 4, 3]),
            it("Mix de energía", "Los Días Raros, Metro Sur…", [5, 9, 1, 0]),
            it("Mix de tarde", "Coral Lento, Río Abajo…", [0, 7, 8, 2]),
            it("Mix de carretera", "Sal y Cobre, Metro Sur…", [2, 9, 7, 6])
        ] },
        { titulo: "Novedades", items: [
            it("Tierra", "Álbum · Río Abajo", 7),
            it("Papel", "Álbum · Trenes de Papel", 3),
            it("Satélites", "Álbum · Órbita Baja", 11),
            it("Lento", "Álbum · Mar de Fondo", 10),
            it("Verano en diferido", "Álbum · Aurora Club", 8),
            it("Mediodía", "Álbum · Los Días Raros", 5)
        ] }
    ]

    readonly property var explorar: [
        { titulo: "Novedades", items: [
            it("Tierra", "Álbum · Río Abajo", 7),
            it("Satélites", "Álbum · Órbita Baja", 11),
            it("Papel", "Álbum · Trenes de Papel", 3),
            it("Hora punta", "Álbum · Metro Sur", 9),
            it("Estática", "Álbum · Nébula Sur", 6),
            it("Marea alta", "Álbum · Coral Lento", 0)
        ] },
        { titulo: "Listas de éxitos", items: [
            it("Top canciones", "Lista", [0, 5, 9, 1]),
            it("Top álbumes", "Lista", [4, 7, 2, 11]),
            it("Tendencias", "Lista", [8, 6, 10, 3]),
            it("Top vídeos", "Lista", [5, 1, 0, 9])
        ] },
        { titulo: "Estados de ánimo", items: [
            it("Relax", "Selección", 10),
            it("Energía", "Selección", 5),
            it("Concentración", "Selección", 6),
            it("Trayecto", "Selección", 2),
            it("Fiesta", "Selección", 8),
            it("Dormir", "Selección", 4)
        ] }
    ]

    readonly property var playlists: [
        { titulo: "Playlists", items: [
            it("Entrenar", "Playlist · 36 canciones", [9, 5, 1, 0]),
            it("Años 2010", "Playlist · 80 canciones", [5, 8, 3, 6]),
            it("Carretera norte", "Playlist · 52 canciones", [2, 7, 9, 0]),
            it("Para programar", "Playlist · 64 canciones", [6, 11, 10, 4]),
            it("Me gusta", "Playlist automática", [7, 9, 0, 5]),
            it("Domingo lento", "Playlist · 48 canciones", [10, 4, 8, 3]),
            it("Descubrimiento semanal", "Playlist · 30 canciones", [11, 1, 6, 2]),
            it("Cocinar con calma", "Playlist · 41 canciones", [1, 3, 8, 10]),
            it("Verano 2024", "Playlist · 58 canciones", [8, 0, 5, 9]),
            it("Lluvia", "Playlist · 27 canciones", [10, 6, 4, 11]),
            it("Directos", "Playlist · 19 canciones", [3, 2, 7, 6])
        ] }
    ]

    readonly property var albumes: [
        { titulo: "Álbumes", items: [
            it("Azul casi negro", "Vera Luján · 2022", 4),
            it("Estática", "Nébula Sur · 2020", 6),
            it("Hora punta", "Metro Sur · 2023", 9),
            it("Jardín eléctrico", "Órbita Baja · 2021", 1),
            it("Lento", "Mar de Fondo · 2019", 10),
            it("Marea alta", "Coral Lento · 2024", 0),
            it("Mediodía", "Los Días Raros · 2019", 5),
            it("Noche de cobre", "Sal y Cobre · 2018", 2),
            it("Papel", "Trenes de Papel · 2022", 3),
            it("Satélites", "Órbita Baja · 2024", 11),
            it("Tierra", "Río Abajo · 2023", 7),
            it("Verano en diferido", "Aurora Club · 2021", 8)
        ] }
    ]

    readonly property var sections: [
        { id: "inicio", label: "Inicio" },
        { id: "explorar", label: "Explorar" },
        { id: "playlists", label: "Playlists" },
        { id: "albumes", label: "Álbumes" }
    ]

    readonly property var views: [
        { id: "lomos", label: "Lomos" },
        { id: "cubeta", label: "Cubeta" },
        { id: "muro", label: "Muro" }
    ]

    function zonas(section) {
        switch (section) {
        case "explorar": return explorar
        case "playlists": return playlists
        case "albumes": return albumes
        default: return inicio
        }
    }

    function label(section) {
        for (const s of sections)
            if (s.id === section)
                return s.label
        return ""
    }

    // Letra de ejemplo (texto propio), una línea cada seis segundos.
    readonly property var verse: [
        "Se apaga la ciudad detrás del cristal",
        "y el eco de tu voz se queda a vivir",
        "Sube la marea, no sé nadar",
        "pero contigo aprendo a flotar",
        "Luces de neón sobre el mar",
        "dibujan el camino para volver",
        "Y si amanece y no estás",
        "guardaré la noche en un papel"
    ]

    readonly property var lyrics: buildLyrics()

    // Índice de la línea que suena en `position` (segundos).
    function lineAt(position) {
        let current = 0
        for (let i = 0; i < lyrics.length && lyrics[i].t <= position; ++i)
            current = i
        return current
    }

    // Fracción cantada (0–1) de la línea `line` en `position`.
    function lineProgress(line, position) {
        const start = lyrics[line].t
        const end = line + 1 < lyrics.length ? lyrics[line + 1].t : start + 6
        return Math.max(0, Math.min(1, (position - start) / (end - start)))
    }

    function buildLyrics() {
        const lines = []
        for (let i = 0; i < 48; ++i)
            lines.push({ t: 6 * i, text: verse[i % verse.length] })
        return lines
    }
}
