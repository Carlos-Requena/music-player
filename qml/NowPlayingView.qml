import QtQuick
import QtQuick.Effects
import app.musicplayer

// Pantalla «Sonando»: la carátula de lo que suena en grande a la izquierda, sobre el fondo
// ambiente de sus colores, y a la derecha su letra (si la hay) y la cola. Sube desde abajo al
// elegir una canción o pulsar la de la barra de reproducción; baja con la flecha o Esc (pulsar la
// carátula la hace «latir»). La barra de reproducción queda encima.
FocusScope {
    id: root

    property bool open: false
    // Alto de la barra de reproducción (y su margen), que queda por encima.
    property real bottomInset: 100
    property color tint: Theme.neutralTint
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
    readonly property real sideMargin: Theme.margin
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
    // Esquinas de la carátula (opción `esquinas`).
    readonly property real artRadius: Theme.coverRadius(root.art)
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

    // Carátula animada de Apple Music (opción `caratulaAnimada`, desactivada por defecto): con la
    // pantalla a la vista se pide la de lo que suena (`Player.buscarAnimada`, que no repite una
    // pista ya pedida) y, si llega, un vídeo en bucle tapa la carátula fija.
    readonly property bool animated: { void AppSettings.revision; return AppSettings.opcion("caratulaAnimada") === "si" }
    readonly property bool wantsAnimated: animated && root.visible && Player.title !== ""
    onWantsAnimatedChanged: if (wantsAnimated) Player.buscarAnimada()
    Connections {
        target: Player
        enabled: root.wantsAnimated
        function onTitleChanged() { Player.buscarAnimada() }
        function onArtistChanged() { Player.buscarAnimada() }
    }

    // Arriba del todo, tapa la ventana entera: lo de debajo no hace falta pintarlo.
    readonly property bool covering: shown >= 1
    // Lo que desenfoca el vidrio de la barra de reproducción: solo el fondo, no la letra ni la
    // carátula. Si fuera toda la pantalla, cada paso del barrido de la letra obligaba a copiar y
    // desenfocar otra vez el fondo de la barra.
    readonly property Item backdrop: background

    visible: shown > 0.001
    clip: true

    Keys.onEscapePressed: root.closeRequested()
    Keys.onDownPressed: root.closeRequested()

    // El mismo fondo ambiente que el resto de secciones, teñido por la carátula. Fuera de `sheet`
    // (pero subiendo con ella) para que el vidrio de la barra lo capture solo a él.
    Item {
        id: background
        width: root.width
        height: root.height
        y: sheet.y

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

        // Pulso de luz del «latido» (`beat`): un velo del color de la carátula que sube y se apaga.
        Rectangle {
            id: beatGlow
            anchors.fill: parent
            color: Qt.lighter(tint.tint, 1.7)
            opacity: 0
            visible: opacity > 0.001
        }
    }

    // «Latido» al pulsar la carátula (elegido por el propietario): se encoge, rebota y vuelve, y
    // el fondo da un pulso de luz. Unos 450 ms; no se repite solo. Pulsar la carátula ya no cierra
    // «Sonando» (se cierra con la flecha o con Esc).
    property real beatScale: 1
    function beat() {
        beatAnimation.restart()
    }
    ParallelAnimation {
        id: beatAnimation
        SequentialAnimation {
            NumberAnimation { target: root; property: "beatScale"; to: 0.95; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "beatScale"; to: 1.03; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "beatScale"; to: 1; duration: 180; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation {
            NumberAnimation { target: beatGlow; property: "opacity"; to: 0.16; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: beatGlow; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InQuad }
        }
    }

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

        IconButton {
            x: Theme.margin
            y: 20
            icon: Theme.iconDown
            label: "Cerrar la pantalla Sonando"
            solid: true
            onClicked: root.closeRequested()
        }

        SectionLabel {
            x: root.artRight - root.art / 2 - width / 2
            y: 34
            text: "Sonando"
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
                radius: root.artRadius
                blur: root.art * 0.18
                spread: root.art * 0.02
                color: Qt.rgba(Math.min(1, tint.tint.r * 1.4), Math.min(1, tint.tint.g * 1.4), Math.min(1, tint.tint.b * 1.4), 0.85)
            }

            Item {
                id: art
                x: (parent.width - width) / 2
                width: root.art
                height: root.art
                scale: (0.94 + 0.06 * root.shown) * root.beatScale

                // Mientras llega la grande (a máxima calidad tarda hasta un segundo la primera
                // vez), la de la barra de reproducción ampliada: es la misma URL y el mismo
                // tamaño, así que ya está en memoria. Se suelta en cuanto la grande está lista.
                Cover {
                    anchors.fill: parent
                    thumb: Player.thumb
                    pixels: 120
                    load: root.visible && !cover.ready
                    visible: !cover.ready
                    radius: root.artRadius
                }

                // Redondeada con su propia forma, sin capa ni máscara: a este tamaño, dos capas
                // costaban varios MB de memoria gráfica.
                Cover {
                    id: cover
                    anchors.fill: parent
                    thumb: root.bigThumb
                    pixels: root.bigPixels
                    load: root.visible
                    radius: root.artRadius
                    placeholder: false
                }

                // Carátula animada: solo existe con la pantalla a la vista y un vídeo para lo que
                // suena; al bajar «Sonando» se destruye y suelta el decodificador. Aparece con un
                // fundido cuando ya pinta el primer fotograma, encima de la fija.
                Loader {
                    id: motion
                    anchors.fill: parent
                    active: root.wantsAnimated && Player.animada !== ""
                    // En su propio archivo: si falta Qt Multimedia, solo falla la carátula animada
                    // y «Sonando» sigue cargando.
                    source: "MotionCover.qml"
                    onLoaded: {
                        item.source = Qt.binding(() => Player.animada)
                        item.textureSide = Qt.binding(() => Math.min(960, root.art * root.dpr))
                        item.radius = Qt.binding(() => root.artRadius)
                    }
                }

                // Brillo suave arriba a la izquierda, como un vinilo bajo una luz.
                Rectangle {
                    anchors.fill: parent
                    radius: root.artRadius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.08) }
                        GradientStop { position: 0.4; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.artRadius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.glassBorder
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.beat()
                }
                // Clic derecho: también «late» y abre el menú de la canción (cola, álbum, artista,
                // «Relacionado»…). `art.Window`: dentro de un gestor, `Window.window` es nulo.
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: eventPoint => {
                        root.beat()
                        art.Window.window.openPlayingMenu(eventPoint.scenePosition)
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Carátula de " + (Player.title !== "" ? Player.title : "lo que suena")
                Accessible.onPressAction: root.beat()
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
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.displaySpacing
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Player.artist
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
                }
            }
        }

        // ---- Derecha: pestañas Letra (solo si la hay) y Cola ----

        // Pestañas de navegación (regla de dos: lo elegido, en blanco).
        Tabs {
            id: tabs
            opacity: root.sideShown
            visible: opacity > 0.01
            x: root.sideX
            y: root.sideTop
            width: root.sideWidth
            height: root.tabsHeight
            fontSize: Theme.fontBody
            navigate: true
            fill: true
            well: true
            current: root.shownTab
            tabs: root.hasLyrics
                ? [{ id: "letra", label: "Letra" }, { id: "cola", label: "Cola · " + Catalog.queue.length }]
                : [{ id: "cola", label: "Cola · " + Catalog.queue.length }]
            onPicked: id => root.tab = id
        }

        Rectangle {
            id: lyricsBox
            opacity: root.sideShown
            visible: root.shownTab === "letra" && opacity > 0.01
            x: root.sideX
            y: root.sideTop + root.tabsHeight + 12
            width: root.sideWidth
            height: root.sideBottom - y
            radius: Theme.radiusL
            // Con el fondo «Fluido», la letra y la cola van sobre él, sin recuadro (como en
            // Better Lyrics).
            color: Theme.ambientFluid ? "transparent" : Theme.well
            border.width: Theme.ambientFluid ? 0 : 1
            border.color: Theme.glassBorder

            // El ajuste de retraso es el pie discreto de la propia letra (`LyricsTiming`). Solo
            // existe mientras la pantalla está abierta o subiendo y con la letra a la derecha (ver
            // el panel lateral); se crea al pulsar, mientras sube.
            Loader {
                active: (root.open || root.visible) && root.sideShown > 0 && root.shownTab === "letra"
                asynchronous: true
                x: 24
                y: 12
                width: parent.width - 48
                height: parent.height - 12 - 6
                sourceComponent: LyricsView {
                    // Más pequeña si el recuadro es estrecho, para que quepan las palabras largas.
                    baseSize: Math.max(24, Math.min(34, width / 12))
                }
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
            radius: Theme.radiusL
            // Con el fondo «Fluido», la letra y la cola van sobre él, sin recuadro (como en
            // Better Lyrics).
            color: Theme.ambientFluid ? "transparent" : Theme.well
            border.width: Theme.ambientFluid ? 0 : 1
            border.color: Theme.glassBorder

            QueueList {
                id: queueList
                x: 12
                y: 12
                width: parent.width - 24
                height: parent.height - 24
                followTop: true
            }
        }
    }
}
