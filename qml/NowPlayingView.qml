import QtQuick
import QtQuick.Effects
import app.musicplayer

// Pantalla «Sonando»: la carátula de lo que suena en grande a la izquierda, sobre el fondo
// ambiente de sus colores, y a la derecha su letra (si la hay) y la cola. Sube desde abajo al
// elegir una canción o pulsar la de la barra de reproducción; baja con la carátula, la flecha
// o Esc. La barra de reproducción queda encima.
FocusScope {
    id: root

    property bool open: false
    // Alto de la barra de reproducción (y su margen), que queda por encima.
    property real bottomInset: 100
    property color tint: "#3A3F4B"
    // Letra y cola a la derecha. El botón del panel de la barra las quita y la carátula se
    // centra.
    property bool side: true
    property real sideShown: side ? 1 : 0
    Behavior on sideShown { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    signal closeRequested()

    // 0 = escondida abajo, 1 = arriba del todo.
    property real shown: open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

    // Dos disposiciones (opción `sonando`):
    // - «grande» (por defecto): carátula sola, todo lo grande que deje el alto (entre «Sonando» y
    //   la barra) y, a su derecha, la letra o la cola, estrechas y a la misma altura que ella. El
    //   conjunto va centrado: el margen exterior es el mismo a los dos lados.
    // - «clasica»: carátula con su título debajo, con el borde derecho algo pasado el centro, y
    //   la letra o la cola anchas, del borde de arriba a la barra.
    readonly property bool big: { void AppSettings.revision; return AppSettings.opcion("sonando") !== "clasica" }
    // Título y artista bajo la carátula (opción `sonandoTitulo`): «auto» (por defecto) los pone
    // solo en la Clásica; «si» y «no», en las dos disposiciones.
    readonly property bool showTitle: {
        void AppSettings.revision
        const mode = AppSettings.opcion("sonandoTitulo")
        return mode === "si" ? true : mode === "no" ? false : !big
    }
    // Alto que ocupa el título bajo la carátula (en «grande», se le quita a la carátula).
    readonly property real titleSpace: showTitle ? 28 + info.height : 0
    readonly property real edge: 48
    readonly property real gutter: 56
    readonly property real artTop: 76
    // Mismo hueco hasta la barra (que empieza un `Theme.gap` por encima de `bottomInset`) que
    // hasta el borde de arriba.
    readonly property real sideMargin: 32
    readonly property real bottomEdge: height - bottomInset + Theme.gap - sideMargin
    readonly property real sideWidth: big ? Math.max(380, Math.min(460, width * 0.3)) : width * 0.55 - 200
    readonly property real art: big
        ? Math.max(200, Math.min(bottomEdge - artTop - titleSpace, width - 2 * edge - gutter - sideWidth, 1000))
        : Math.max(200, Math.min((height - bottomInset) * 0.68, width * 0.45 - 80, 680))
    readonly property real groupLeft: Math.max(edge, (width - root.art - gutter - sideWidth) / 2)
    // Sin letra ni cola, la carátula va al centro.
    // (`root.art`: dentro de este archivo, `art` a secas es la carátula, que tiene ese id.)
    readonly property real artLeft: (big ? groupLeft : width * 0.45 - root.art) * sideShown
                                    + (width - root.art) / 2 * (1 - sideShown)
    readonly property real artRight: artLeft + root.art
    readonly property real sideX: (big ? groupLeft + root.art + gutter : width * 0.45 + 100) + 60 * (1 - sideShown)
    readonly property real tabsHeight: Theme.hit + 8
    // Pestaña de la derecha. Sin letra solo existe «Cola».
    property string tab: "letra"
    readonly property string shownTab: hasLyrics ? tab : "cola"
    // Letra/Cola: en «grande», a la altura de la carátula; en «clásica», del borde a la barra.
    readonly property real sideTop: big ? artTop : sideMargin
    readonly property real sideBottom: big ? artTop + root.art : bottomEdge
    readonly property bool hasLyrics: Catalog.lyrics.length > 0
    // Carátula grande (opción `caratulaCalidad`): «Máxima» (por defecto) la pide al tamaño que
    // ocupa en pantalla, en píxeles físicos, entre 1200 y 2400 y en escalones de 400 para no
    // pedir otra a cada paso al redimensionar la ventana; «Alta», a 1200. El servidor no la
    // agranda: si el original es menor, llega el original. Los vídeos (i.ytimg.com) no tienen
    // carátula cuadrada: en vez de su miniatura pequeña (con bandas negras), su fotograma a
    // 1280×720 (`hq720`); si no lo tiene, se queda la miniatura de debajo.
    readonly property bool maxCover: { void AppSettings.revision; return AppSettings.opcion("caratulaCalidad") !== "alta" }
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property int bigPixels: maxCover
        ? Math.max(1200, Math.min(2400, Math.ceil(root.art * dpr / 400) * 400))
        : 1200
    readonly property string bigThumb: {
        const video = Player.thumb.match(/^https:\/\/i\.ytimg\.com\/vi\/([^\/]+)\//)
        if (video)
            return "https://i.ytimg.com/vi/" + video[1] + "/hq720.jpg"
        return Player.thumb.replace("w544-h544", "w" + bigPixels + "-h" + bigPixels)
    }

    visible: shown > 0.001
    clip: true

    Keys.onEscapePressed: root.closeRequested()
    Keys.onDownPressed: root.closeRequested()

    Item {
        id: sheet
        width: root.width
        height: root.height
        y: (1 - root.shown) * root.height

        // Color dominante de la carátula (lo calcula la ventana: una sonda aquí, fuera de la
        // zona visible, no llega a pintarse y se queda en gris).
        QtObject {
            id: tint
            readonly property color tint: root.tint
        }

        // Los clics y la rueda no atraviesan la pantalla. Un `MouseArea` no basta: los gestores
        // de clic de lo de debajo (las tarjetas) seguían recibiéndolos; un gestor con agarre
        // exclusivo sí los corta.
        TapHandler {
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => wheel.accepted = true
        }

        // El mismo fondo ambiente que el resto de secciones, teñido por la carátula.
        Ambient {
            anchors.fill: parent
            intensity: Theme.ambient
            stageTint: tint.tint
            playingTint: Qt.lighter(tint.tint, 1.25)
            stageCenter: parent.width / 2
            playingCenter: parent.width * 0.85
            moving: Theme.ambientMotion !== "no"
            thumb: Player.thumb
            fluidDarken: 0.35
        }

        IconButton {
            x: 24
            y: 20
            icon: Theme.iconDown
            label: "Cerrar la pantalla Sonando"
            solid: true
            onClicked: root.closeRequested()
        }

        Text {
            x: root.artRight - root.art / 2 - width / 2
            y: 32
            text: "Sonando"
            color: Theme.textMuted
            font.pixelSize: 12
            font.letterSpacing: 2.4
            font.capitalization: Font.AllUppercase
            font.weight: Font.DemiBold
        }

        Item {
            id: column
            // En «grande», la carátula sola (el título ya está en la barra de reproducción); en
            // «clásica», con su título debajo, centrada en vertical.
            x: root.artLeft
            width: root.art
            height: root.art + root.titleSpace
            y: root.big ? root.artTop : Math.max(96, (root.height - root.bottomInset - height) / 2 + 42)

            // Halo del color de la carátula detrás de ella. En el ambiente «Plano» no: es un
            // degradado más.
            RectangularShadow {
                visible: !Theme.ambientFlat
                x: art.x
                y: art.y + root.art * 0.04
                width: root.art
                height: root.art
                radius: 18
                blur: root.art * 0.18
                spread: root.art * 0.02
                color: Qt.rgba(Math.min(1, tint.tint.r * 1.4), Math.min(1, tint.tint.g * 1.4), Math.min(1, tint.tint.b * 1.4), 0.85)
            }

            Item {
                id: art
                x: (parent.width - width) / 2
                width: root.art
                height: root.art
                scale: 0.94 + 0.06 * root.shown

                // Mientras llega la grande (a máxima calidad tarda hasta un segundo la primera
                // vez), la de la barra de reproducción ampliada: es la misma URL y el mismo
                // tamaño, así que ya está en memoria. Se suelta en cuanto la grande está lista.
                Cover {
                    anchors.fill: parent
                    thumb: Player.thumb
                    pixels: 120
                    load: root.visible && !cover.ready
                    visible: !cover.ready
                    radius: 18
                }

                // Redondeada con su propia forma, sin capa ni máscara: a este tamaño, dos capas
                // costaban varios MB de memoria gráfica.
                Cover {
                    id: cover
                    anchors.fill: parent
                    thumb: root.bigThumb
                    pixels: root.bigPixels
                    load: root.visible
                    radius: 18
                    placeholder: false
                }

                // Brillo suave arriba a la izquierda, como un vinilo bajo una luz.
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                        GradientStop { position: 0.4; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.closeRequested()
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Cerrar la pantalla Sonando"
            }

            Column {
                id: info
                visible: root.showTitle
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.art + 28
                width: parent.width + 56
                spacing: 6

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Player.title !== "" ? Player.title : "Nada sonando"
                    color: Theme.text
                    font.pixelSize: 34
                    font.weight: Font.Bold
                    font.letterSpacing: -0.4
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Player.artist
                    color: Theme.textMuted
                    font.pixelSize: 17
                    elide: Text.ElideRight
                }
            }
        }

        // ---- Derecha: pestañas Letra (solo si la hay) y Cola ----

        Rectangle {
            id: tabs
            opacity: root.sideShown
            visible: opacity > 0.01
            x: root.sideX
            y: root.sideTop
            width: root.sideWidth
            height: root.tabsHeight
            radius: 16
            color: Qt.rgba(0, 0, 0, 0.25)

            Row {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Repeater {
                    model: root.hasLyrics
                        ? [{ id: "letra", label: "Letra" }, { id: "cola", label: "Cola · " + Catalog.queue.length }]
                        : [{ id: "cola", label: "Cola · " + Catalog.queue.length }]

                    Item {
                        id: tabButton
                        required property var modelData
                        required property int index
                        readonly property bool chosen: modelData.id === root.shownTab

                        width: (tabs.width - 8 - 4 * (root.hasLyrics ? 1 : 0)) / (root.hasLyrics ? 2 : 1)
                        height: Theme.hit
                        activeFocusOnTab: true

                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.label
                        Accessible.onPressAction: root.tab = modelData.id
                        Keys.onReturnPressed: root.tab = modelData.id

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: tabButton.chosen ? Theme.controlActive : (tabHover.hovered ? Theme.control : "transparent")
                            border.width: tabButton.activeFocus ? 2 : 0
                            border.color: Theme.text
                        }

                        Text {
                            anchors.centerIn: parent
                            text: tabButton.modelData.label
                            color: tabButton.chosen ? Theme.text : Theme.textMuted
                            font.pixelSize: 15
                            font.weight: tabButton.chosen ? Font.DemiBold : Font.Normal
                        }

                        HoverHandler {
                            id: tabHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.tab = tabButton.modelData.id
                        }
                    }
                }
            }
        }

        Rectangle {
            id: lyricsBox
            opacity: root.sideShown
            visible: root.shownTab === "letra" && opacity > 0.01
            x: root.sideX
            y: root.sideTop + root.tabsHeight + 12
            width: root.sideWidth
            height: root.sideBottom - y
            radius: 22
            // Con el fondo «Fluido», la letra y la cola van sobre él, sin recuadro (como en
            // Better Lyrics).
            color: Theme.ambientFluid ? "transparent" : Qt.rgba(0, 0, 0, 0.22)
            border.width: Theme.ambientFluid ? 0 : 1
            border.color: Theme.glassBorder

            // El ajuste de retraso es el pie discreto de la propia letra (`LyricsTiming`).
            LyricsView {
                x: 24
                y: 12
                width: parent.width - 48
                height: parent.height - 12 - 6
                // Más pequeña si el recuadro es estrecho, para que quepan las palabras largas.
                baseSize: Math.max(24, Math.min(34, width / 12))
            }
        }

        Rectangle {
            id: queueBox
            opacity: root.sideShown
            visible: root.shownTab === "cola" && opacity > 0.01
            x: root.sideX
            y: root.sideTop + root.tabsHeight + 12
            width: root.sideWidth
            height: root.sideBottom - y
            radius: 22
            // Con el fondo «Fluido», la letra y la cola van sobre él, sin recuadro (como en
            // Better Lyrics).
            color: Theme.ambientFluid ? "transparent" : Qt.rgba(0, 0, 0, 0.22)
            border.width: Theme.ambientFluid ? 0 : 1
            border.color: Theme.glassBorder

            QueueList {
                id: queueList
                x: 12
                y: 12
                width: parent.width - 24
                height: parent.height - 24
                rowHeight: 46
                coverSize: 42
                titleSize: 15
                rowRadius: 12
                followTop: true
                showPlaying: true
            }
        }
    }
}
