pragma Singleton
import QtQuick
import app.musicplayer

// Tokens visuales. Los colores, el radio y la intensidad del modo ambiente salen de la skin
// activa (`AppSettings.skinData`, JSON); lo que falte toma el valor de la skin Vidrio.
QtObject {
    id: theme

    readonly property var skin: {
        try {
            return AppSettings.skinData === "" ? {} : JSON.parse(AppSettings.skinData)
        } catch (error) {
            return {}
        }
    }
    readonly property var colors: skin.colores || {}

    function pick(key, fallback) {
        return colors[key] !== undefined ? colors[key] : fallback
    }

    readonly property color ground: pick("fondo", "#0A0C11")
    readonly property color text: pick("texto", "#FFFFFF")
    readonly property color textMuted: pick("textoSecundario", "#BDFFFFFF")
    readonly property color textFaint: pick("textoTenue", "#80FFFFFF")
    readonly property color glass: pick("vidrio", "#12FFFFFF")
    readonly property color glassStrong: pick("vidrioDenso", "#94121419")
    readonly property color glassBorder: pick("bordeVidrio", "#1FFFFFFF")
    readonly property color control: pick("control", "#1AFFFFFF")
    readonly property color controlActive: pick("controlActivo", "#2EFFFFFF")
    readonly property color accent: pick("acento", "#FFB070")
    // Errores (reproducción, cuenta). El acento queda para «activado» y «suena».
    readonly property color error: pick("error", "#FF6B6B")

    // Opciones de disposición que afectan al aspecto (Opciones › Disposición).
    readonly property bool blur: AppSettings.opcion("desenfoque", AppSettings.revision) !== "no"
    // Letra: tamaño (factor), familia y grosor, de Opciones › Letra.
    readonly property real lyricsScale: {
        const size = AppSettings.opcion("letraTamano", AppSettings.revision)
        return size === "pequena" ? 0.8 : size === "grande" ? 1.25 : size === "enorme" ? 1.5 : 1
    }
    readonly property string lyricsFamily: {
        const family = AppSettings.opcion("letraFuente", AppSettings.revision)
        if (family === "serif")
            return Qt.platform.os === "osx" ? "Georgia" : "serif"
        if (family === "mono")
            return Qt.platform.os === "osx" ? "Menlo" : "monospace"
        return Qt.application.font.family
    }
    readonly property int lyricsWeight: AppSettings.opcion("letraPeso", AppSettings.revision) === "normal" ? Font.Medium : Font.Bold

    // Estilo de la barra de reproducción (Opciones › Apariencia): «islas» (tres piezas
    // sueltas), «clasica» (una barra, la posición bajo los botones) o «compacta» (más baja, la
    // posición como una línea arriba). La usan `PlayerBar` y el alto que reserva `Main`.
    readonly property string barStyle: {
        const style = AppSettings.opcion("barra", AppSettings.revision)
        return style === "clasica" || style === "compacta" ? style : "islas"
    }
    readonly property int barHeight: barStyle === "clasica" ? 84 : 64

    // Brillo al pasar el ratón por el Muro y las tarjetas de Explorar (opción `brillo`).
    readonly property bool hoverGlow: AppSettings.opcion("brillo", AppSettings.revision) !== "no"
    // Color del brillo: el de la carátula (`TintProbe.tint`), aclarado para que brille también en
    // las oscuras; blanco si es gris.
    function glow(tint) {
        return tint.hslHue < 0 ? Qt.hsla(0, 0, 0.9, 1)
                               : Qt.hsla(tint.hslHue, Math.max(0.5, tint.hslSaturation), Math.max(0.62, tint.hslLightness), 1)
    }

    readonly property string ambientMode: AppSettings.opcion("ambiente", AppSettings.revision) || "si"
    readonly property bool ambientOn: ambientMode !== "no"
    // «Suave»: un solo color (el del elemento enfocado) y menos intensidad. Se ve mejor en
    // pantallas que muestran con escalones los degradados de varios colores.
    // «Tenue»: igual que «Suave» pero apenas un velo de color.
    readonly property bool ambientSingle: ambientMode === "suave" || ambientMode === "tenue"
    // «Plano»: todo el fondo de un solo color sólido (el del elemento enfocado), sin ningún
    // degradado. Para pantallas antiguas, donde hasta un solo foco sale con escalones.
    readonly property bool ambientFlat: ambientMode === "plano"
    // «Fluido»: la carátula muy desenfocada y deformada como fondo, al estilo Better Lyrics
    // Shaders (`Ambient.qml`, `shaders/fluido.frag`).
    readonly property bool ambientFluid: ambientMode === "fluido"
    // Movimiento del ambiente (opción `ambienteMovimiento`): «no» (por defecto), «sonando» (solo
    // en la pantalla «Sonando») o «siempre». Ver `Ambient.drifting`.
    readonly property string ambientMotion: AppSettings.opcion("ambienteMovimiento", AppSettings.revision) || "no"
    readonly property real ambient: ambientOn
        ? (skin.ambiente !== undefined ? skin.ambiente : 1) * (ambientMode === "tenue" ? 0.3 : ambientSingle ? 0.7 : 1)
        : 0

    // Skins en carpeta (`<config>/musicplayer/skins/<id>/skin.json`): sus imágenes van con
    // ruta relativa a la carpeta, que Rust añade como `carpeta`.
    function skinImage(name) {
        return name && skin.carpeta ? skin.carpeta + name : ""
    }
    // Imagen de fondo del escenario, su opacidad y un velo del color de fondo encima (0–1)
    // para que el texto se lea sobre imágenes claras.
    readonly property string backdrop: skinImage(skin.fondo)
    readonly property real backdropOpacity: skin.fondoOpacidad !== undefined ? skin.fondoOpacidad : 1
    readonly property real backdropVeil: skin.fondoVelo !== undefined ? skin.fondoVelo : 0
    // Mascota elegida en Opciones › Mascota, independiente de la skin
    // (`<config>/musicplayer/mascotas/<id>/mascota.json`); `null` si no hay ninguna.
    readonly property var mascot: {
        try {
            const data = AppSettings.mascotaData === "" ? null : JSON.parse(AppSettings.mascotaData)
            return data && data.poses ? data : null
        } catch (error) {
            return null
        }
    }
    readonly property bool mascotOn: mascot !== null
    function mascotImage(name) {
        return name && mascot && mascot.carpeta ? mascot.carpeta + name : ""
    }

    readonly property int radius: skin.radio !== undefined ? skin.radio : 20
    // Borde de los paneles de vidrio pegados a la ventana (barra de reproducción, panel lateral).
    readonly property int gap: 12
    readonly property int hit: 44
    readonly property int animFast: 160
    readonly property int animMove: 320

    // ── Medidas comunes (ADR-23) ─────────────────────────────────────────────────────────
    // Ningún componente escribe a mano un tamaño de letra, un radio ni un color: los toma de
    // aquí (lo comprueba `docs.py check`).

    // Tipografía en ocho niveles. La letra de las canciones tiene su propia escala (`lyricsScale`).
    readonly property int fontDisplay: 40   // nombre de lo enfocado (Muro, Lomos, Cubeta), artista
    readonly property int fontTitle: 28     // título de una pantalla: detalle, Opciones, Sonando
    readonly property int fontHeading: 20   // título del panel, tarjetas de Explorar
    readonly property int fontBody: 15      // título de una fila, nombre de una opción
    readonly property int fontBase: 14      // botones, pestañas, menú, campos
    readonly property int fontSmall: 13     // artista, duración, descripciones
    readonly property int fontLabel: 12     // etiquetas de sección, en mayúsculas
    readonly property int fontMini: 11      // calidad del audio, atajos de teclado
    readonly property real labelSpacing: 1.8
    readonly property real displaySpacing: -0.5

    // Borde del contenido y de los botones sueltos, igual en todas las pantallas.
    readonly property int margin: 32

    // Esquinas, sacadas del `radio` de la skin: así Grafito (6) y Neón (26) se notan en toda la
    // app. S: filas, entradas del menú, miniaturas. M: tarjetas, menú, segmentos, campos.
    // L: paneles de vidrio. Los botones y la navegación son píldoras (`height / 2`).
    readonly property int radiusS: Math.round(radius * 0.4)
    readonly property int radiusM: Math.round(radius * 0.7)
    readonly property int radiusL: radius

    // Carátulas (opción `esquinas`): «redondeadas» (por defecto) o «cuadradas». Las pequeñas
    // (filas, barra, mini) toman S y las grandes, M. Los artistas van siempre en círculo y los
    // objetos físicos (cajas de Lomos y Cubeta, Inspeccionar) siempre cuadrados.
    readonly property bool roundCovers: AppSettings.opcion("esquinas", AppSettings.revision) !== "cuadradas"
    function coverRadius(side) {
        return roundCovers ? (side >= 120 ? radiusM : radiusS) : 0
    }

    // Clic en una fila de canción (opción `clic`): «doble» (por defecto: un clic la elige y el
    // doble la hace sonar) o «uno» (un clic la hace sonar). Detalle, cola y temporal.
    readonly property bool singleClick: AppSettings.opcion("clic", AppSettings.revision) === "uno"

    // Hoja de Opciones compacta (su interruptor «Compacto»): sin descripciones a la vista.
    readonly property bool compactSettings: AppSettings.opcion("compacto", AppSettings.revision) === "si"

    // Velo de lo que tapa el escenario (detalle, Opciones, Inspeccionar) y pozo oscuro de las
    // pestañas, los segmentos y los campos de texto.
    readonly property color scrim: Qt.rgba(ground.r, ground.g, ground.b, 0.62)
    readonly property color well: Qt.rgba(0, 0, 0, 0.3)
    // Fondo de una carátula mientras carga, y tinte de una carátula de la que aún no hay color.
    readonly property color placeholder: Qt.tint(ground, Qt.rgba(1, 1, 1, 0.07))
    readonly property color neutralTint: "#3A3F4B"

    // Fila de canción (`TrackRow`): alto y lado de su miniatura.
    readonly property int rowHeight: 56
    readonly property int rowCover: 40
    // Aro del elemento elegido en una rejilla (Muro): más grueso que el de foco de un control.
    readonly property int cursorWidth: 3

    // Sube cada vez que una ventana vuelve tras ocultarse o minimizarse. Al ocultarla se
    // liberan sus gráficos (window.cpp) y las `Shape` con CurveRenderer no se vuelven a
    // dibujar solas: los iconos se recrean al cambiar este número.
    property int renderEpoch: 0

    // Trazos SVG (caja 24×24) de los iconos de la interfaz.
    readonly property string iconSearch: "M18 11a7 7 0 1 1-14 0a7 7 0 0 1 14 0z M20 20l-3.5-3.5"
    readonly property string iconSettings: "M4 7h10 M18 7h2 M4 17h2 M10 17h10 M18 7a2 2 0 1 1-4 0a2 2 0 0 1 4 0z M10 17a2 2 0 1 1-4 0a2 2 0 0 1 4 0z"
    readonly property string iconPlay: "M8 5v14l11-7z"
    readonly property string iconPause: "M7 5h3.5v14H7z M13.5 5H17v14h-3.5z"
    readonly property string iconNext: "M5 5.5v13L15 12z M17 5h2v14h-2z"
    readonly property string iconPrevious: "M19 5.5v13L9 12z M5 5h2v14H5z"
    readonly property string iconHeart: "M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"
    readonly property string iconLyrics: "M4 5h16v11H9l-5 4z M8 9h8 M8 12h5"
    readonly property string iconVolume: "M4 9.5h3l5-4v13l-5-4H4z M16 9a4 4 0 0 1 0 6"
    readonly property string iconQueue: "M4 7h16 M4 12h16 M4 17h10"
    readonly property string iconAccount: "M16 8a4 4 0 1 1-8 0a4 4 0 0 1 8 0z M4 21c0-4 3.6-6.5 8-6.5s8 2.5 8 6.5"
    readonly property string iconBack: "M15 5l-7 7 7 7"
    readonly property string iconShuffle: "M3 7h3.5c2 0 3.2 1 4.3 2.6l2.4 4.8c1.1 1.6 2.3 2.6 4.3 2.6H21 M3 17h3.5c1.3 0 2.3-.4 3.1-1.2 M21 7h-3.5c-1.3 0-2.3.4-3.1 1.2 M18 4l3 3-3 3 M18 14l3 3-3 3"
    readonly property string iconInspect: "M4 5h11v14H4z M15 7l4 1v8l-4 1 M7 9h5 M7 12h5"
    readonly property string iconMini: "M3 5h18v14H3z M12 12h7v5h-7z"
    readonly property string iconExpand: "M14 4h6v6 M10 20H4v-6 M20 4l-7 7 M4 20l7-7"
    readonly property string iconClose: "M6 6l12 12 M18 6L6 18"
    readonly property string iconDown: "M6 9l6 6 6-6"
    readonly property string iconRepeat: "M17 3l3 3-3 3 M4 12V10a4 4 0 0 1 4-4h12 M7 21l-3-3 3-3 M20 12v2a4 4 0 0 1-4 4H4"
    // Repetir una: el mismo bucle con un «1» en medio.
    readonly property string iconRepeatOne: iconRepeat + " M11 10.5l1.5-1v5"
    readonly property string iconCheck: "M5 12.5l4.5 4.5L19 7"
    readonly property string iconImage: "M4 5h16v14H4z M4 16l5-5 4 4 2-2 5 5 M15.5 9a1 1 0 1 1-2 0a1 1 0 0 1 2 0z"
    readonly property string iconEdit: "M4 20h4L19 9l-4-4L4 16z M13.5 6.5l4 4"
    readonly property string iconTrash: "M5 7h14 M10 7V4h4v3 M7 7l1 13h8l1-13"
    readonly property string iconPlus: "M12 5v14 M5 12h14"
    readonly property string iconTemporal: "M4 7h11 M4 12h11 M4 17h7 M18 14v6 M15 17h6"
    // Menú contextual: poner a continuación, añadir al final de la cola, guardar en una
    // playlist (marcapáginas con «+»), entrar en una subpágina y categorías.
    readonly property string iconPlayNext: "M4 4.5v6l5-3z M12 7.5h8 M4 13h16 M4 18h16"
    readonly property string iconAddQueue: "M4 6h16 M4 11h16 M4 16h9 M18 12v9 M15 18l3 3 3-3"
    readonly property string iconSaveList: "M5 4h14v16l-7-4-7 4z M12 8v6 M9 11h6"
    readonly property string iconForward: "M9 5l7 7-7 7"
    // Recargar: una vuelta casi entera con la punta arriba a la derecha.
    readonly property string iconReload: "M19.5 12a7.5 7.5 0 1 1-2.2-5.3 M18 3v4h-4"
    readonly property string iconFolder: "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
    readonly property string iconPlug: "M9 3v5 M15 3v5 M6 8h12v3a6 6 0 0 1-12 0z M12 17v4"
    readonly property string iconLomos: "M4 5v14 M8 5v14 M11 5h9v14h-9z"
    readonly property string iconCubeta: "M4 9h16v11H4z M6 6h12 M8 3h8"
    readonly property string iconMuro: "M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z"
    readonly property string iconAlbum: "M21 12a9 9 0 1 1-18 0a9 9 0 0 1 18 0z M14 12a2 2 0 1 1-4 0a2 2 0 0 1 4 0z"
    // Ondas desde un punto: «Relacionado» (lo que se parece a esta canción).
    readonly property string iconRelated: "M13.5 12a1.5 1.5 0 1 1-3 0a1.5 1.5 0 0 1 3 0z M8.5 15.5a5 5 0 0 1 0-7 M15.5 8.5a5 5 0 0 1 0 7 M5.6 18.4a9 9 0 0 1 0-12.8 M18.4 5.6a9 9 0 0 1 0 12.8"
    readonly property string iconArtist: "M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z M6 11a6 6 0 0 0 12 0 M12 17v4"

    function mmss(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        const s = total % 60
        return Math.floor(total / 60) + ":" + (s < 10 ? "0" + s : s)
    }
}
