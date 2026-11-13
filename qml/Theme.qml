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

    // Opciones de disposición que afectan al aspecto (Opciones › Disposición).
    readonly property int revision: AppSettings.revision
    readonly property bool blur: { void revision; return AppSettings.opcion("desenfoque") !== "no" }
    readonly property string ambientMode: { void revision; return AppSettings.opcion("ambiente") || "si" }
    readonly property bool ambientOn: ambientMode !== "no"
    // «Suave»: un solo color (el del elemento enfocado) y menos intensidad. Se ve mejor en
    // pantallas que muestran con escalones los degradados de varios colores.
    readonly property bool ambientSingle: ambientMode === "suave"
    readonly property real ambient: ambientOn ? (skin.ambiente !== undefined ? skin.ambiente : 1) * (ambientSingle ? 0.7 : 1) : 0

    readonly property int radius: skin.radio !== undefined ? skin.radio : 20
    readonly property int gap: 12
    readonly property int hit: 44
    readonly property int animFast: 160
    readonly property int animMove: 320

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
    readonly property string iconPlus: "M12 5v14 M5 12h14"
    readonly property string iconTemporal: "M4 7h11 M4 12h11 M4 17h7 M18 14v6 M15 17h6"
    readonly property string iconLomos: "M4 5v14 M8 5v14 M11 5h9v14h-9z"
    readonly property string iconCubeta: "M4 9h16v11H4z M6 6h12 M8 3h8"
    readonly property string iconMuro: "M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z"

    function mmss(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        const s = total % 60
        return Math.floor(total / 60) + ":" + (s < 10 ? "0" + s : s)
    }
}
