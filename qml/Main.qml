import QtQuick
import QtQuick.Window
import app.musicplayer

Window {
    id: win

    // Sección visible: una de `Catalog.sections` o "buscar" (resultados de búsqueda).
    property string section: "inicio"
    property bool settingsOpen: false
    property bool inspecting: false
    readonly property bool detailOpen: Catalog.detalle !== null
    property bool lyricsOn: Qt.application.arguments.indexOf("--no-panel") < 0
    // Pantalla «Sonando» (sube desde la barra de reproducción).
    property bool nowOpen: args.indexOf("--now") >= 0

    readonly property bool vidrio: AppSettings.ventana !== "escenario"
    // En ventanas estrechas el panel se oculta para que quepa la navegación.
    readonly property bool showPanel: vidrio && lyricsOn && width >= 1280
    readonly property real panelWidth: 344
    // Opciones › Disposición: el panel de letra a la derecha (por defecto) o a la izquierda.
    readonly property bool panelLeft: { void AppSettings.revision; return AppSettings.opcion("panel") === "izquierda" }
    readonly property real panelX: panelLeft ? Theme.gap : width - panelWidth - Theme.gap
    readonly property real stageX: showPanel && panelLeft ? panelWidth + 2 * Theme.gap : 0
    readonly property real stageWidth: showPanel ? width - panelWidth - 2 * Theme.gap : width
    readonly property real barHeight: vidrio ? 84 : 80
    readonly property real stageLyricHeight: vidrio ? 0 : 118
    readonly property string view: {
        void AppSettings.revision
        return AppSettings.vista(section)
    }

    // Depuración: `--shot ruta.png [--delay ms] [--section id] [--index n] [--search texto]
    // [--settings] [--autoplay]` prepara la ventana, guarda una captura y sale.
    readonly property var args: Qt.application.arguments
    property bool autoplayPending: args.indexOf("--autoplay") >= 0
    // `--index n` sin `--autoplay`: solo coloca la vista (para capturas).
    property bool indexPending: args.indexOf("--index") >= 0

    function arg(name) {
        const at = args.indexOf(name)
        return at >= 0 && at + 1 < args.length ? args[at + 1] : ""
    }

    function setView(view) {
        AppSettings.setVista(section, view)
        sectionView.forceActiveFocus()
    }

    // Elegir algo: una canción suena; un álbum, playlist o artista abre su detalle.
    function choose(item) {
        if (!item)
            return
        // Una canción suena y abre la pantalla «Sonando» con su letra y su cola.
        if (item.kind === "song") {
            Player.playItem(JSON.stringify(item))
            nowOpen = true
        }
        else
            Library.openDetail(JSON.stringify(item))
    }

    // Clic derecho en una canción, álbum o playlist (`point` en coordenadas de la ventana).
    function openMenu(item, point) {
        if (item && item.kind !== "artist")
            contextMenu.show(item, point.x, point.y)
    }

    function closeDetail() {
        inspecting = false
        Library.closeDetail()
        sectionView.forceActiveFocus()
    }

    function inspect(item) {
        if (item && item.kind !== "song" && item.kind !== "artist")
            Library.openDetail(JSON.stringify(item))
        if (detailOpen || item) {
            inspecting = true
            inspectView.forceActiveFocus()
        }
    }

    function cycleView() {
        const order = ["lomos", "cubeta", "muro"]
        setView(order[(order.indexOf(view) + 1) % order.length])
    }

    // Mini reproductor: la ventana grande se oculta (y libera su memoria gráfica).
    function showMini() {
        miniPlayer.x = win.x + win.width - miniPlayer.width - 24
        miniPlayer.y = win.y + 24
        miniPlayer.show()
        win.hide()
    }

    function restoreFromMini() {
        win.show()
        win.raise()
        win.requestActivate()
        miniPlayer.hide()
    }

    function closeSettings() {
        settingsOpen = false
        sectionView.forceActiveFocus()
    }

    function search(query) {
        if (query.trim() === "")
            return
        Library.search(query)
        if (detailOpen)
            closeDetail()
        section = "buscar"
        sectionView.forceActiveFocus()
    }

    // Al volver de oculta o minimizada, recrea los iconos (ver `Theme.renderEpoch`).
    property bool wasAway: false
    onVisibilityChanged: state => {
        if (state === Window.Hidden || state === Window.Minimized)
            wasAway = true
        else if (wasAway) {
            wasAway = false
            Theme.renderEpoch++
        }
    }

    width: 1440
    height: 900
    minimumWidth: 1120
    minimumHeight: 720
    visible: true
    color: Theme.ground
    title: "Reproductor de música"

    Component.onCompleted: {
        Library.load()
        Plugins.start()
        Player.warmUp()
        Account.verify()
        // Depuración: `--minimize ms` minimiza la ventana tras ese tiempo (medir memoria).
        if (arg("--minimize") !== "")
            minimizeTimer.start()
        if (arg("--section") !== "")
            section = arg("--section")
        if (arg("--search") !== "")
            search(arg("--search"))
        settingsOpen = args.indexOf("--settings") >= 0 || args.indexOf("--settings-end") >= 0
        if (args.indexOf("--settings-end") >= 0)
            Qt.callLater(settingsSheet.scrollToEnd)
        if (!settingsOpen)
            sectionView.forceActiveFocus()
    }

    Timer {
        id: minimizeTimer
        interval: parseInt(win.arg("--minimize"))
        onTriggered: {
            if (win.args.indexOf("--mini") >= 0)
                win.showMini()
            else if (win.args.indexOf("--hide") >= 0)
                win.hide()
            else
                win.showMinimized()
            if (win.arg("--restore") !== "")
                restoreTimer.start()
        }
    }

    // Depuración: `--restore ms` vuelve a la ventana grande tras minimizar u ocultar.
    Timer {
        id: restoreTimer
        interval: parseInt(win.arg("--restore"))
        onTriggered: win.args.indexOf("--mini") >= 0 ? win.restoreFromMini() : win.showNormal()
    }

    Timer {
        interval: win.arg("--delay") !== "" ? parseInt(win.arg("--delay")) : 1500
        running: win.arg("--shot") !== ""
        onTriggered: {
            console.log("estado:", Player.title, "|", Player.artist, "| pos", Player.position.toFixed(1),
                        "| dur", Player.duration, "| cargando", Player.loading, "| sonando", Player.playing,
                        "| error", Player.error, "| tinte", playingProbe.tint, "| letra", Catalog.lyrics.length, "| cola", Catalog.parse(Player.queue).length, "| calidad", Player.calidad)
            const target = miniPlayer.visible ? miniPlayer.contentItem : win.contentItem
            target.grabToImage(result => {
                result.saveToFile(win.arg("--shot"))
                Qt.quit()
            })
        }
    }

    Shortcut { sequence: "Space"; enabled: !win.settingsOpen && !searchField.editing; onActivated: Player.toggle() }
    Shortcut { sequence: "V"; enabled: !win.settingsOpen && !win.detailOpen && !searchField.editing; onActivated: win.cycleView() }
    Shortcut { sequence: "M"; enabled: !win.settingsOpen && !searchField.editing; onActivated: win.showMini() }
    Shortcut { sequence: "I"; enabled: !win.settingsOpen && !win.detailOpen && !searchField.editing; onActivated: win.inspect(sectionView.currentItem) }
    Shortcut { sequences: [StandardKey.Find]; enabled: !win.settingsOpen; onActivated: searchField.edit() }
    Shortcut { sequences: [StandardKey.Preferences]; onActivated: win.settingsOpen = true }
    Shortcut { sequence: "Escape"; enabled: win.settingsOpen; onActivated: win.closeSettings() }
    Shortcut { sequence: "Escape"; enabled: win.nowOpen && !win.settingsOpen; onActivated: win.nowOpen = false }

    // Sondas de color para el modo ambiente; quedan tapadas por el fondo.
    TintProbe {
        id: stageProbe
        thumb: win.detailOpen ? Catalog.detalle.thumb : sectionView.focusedThumb
    }

    TintProbe {
        id: playingProbe
        thumb: Player.thumb
    }

    // Escenario: fondo ambiente y contenido de la sección. Es la capa que desenfocan los vidrios.
    Item {
        id: stage
        anchors.fill: parent

        Ambient {
            anchors.fill: parent
            intensity: Theme.ambient
            stageTint: stageProbe.tint
            playingTint: playingProbe.tint
            stageCenter: win.stageX + win.stageWidth / 2
            playingCenter: win.showPanel ? win.panelX + win.panelWidth / 2 : win.width * 0.9
        }

        SectionView {
            id: sectionView
            x: win.stageX
            y: 84
            width: win.stageWidth
            height: win.height - y - win.barHeight - 2 * Theme.gap - win.stageLyricHeight
            section: win.section
            view: win.view
            focus: true
            // Oculta bajo el detalle: no se pinta ni se transparenta.
            visible: !win.detailOpen

            onActivated: item => win.choose(item)

            onCurrentItemChanged: {
                prefetchTimer.restart()
                if ((win.autoplayPending || win.indexPending) && currentItem) {
                    const play = win.autoplayPending
                    win.autoplayPending = false
                    win.indexPending = false
                    // Fuera de este aviso: cambiar el índice dentro de él deja el título sin actualizar.
                    Qt.callLater(() => {
                        if (win.arg("--index") !== "")
                            sectionView.jump(parseInt(win.arg("--index")))
                        if (play)
                            autoplayTimer.start()
                        if (win.arg("--step") !== "")
                            stepTimer.start()
                    })
                }
            }

            // Precarga lo que el usuario deja enfocado un momento, para que al elegirlo
            // suene al instante. La espera evita lanzar yt-dlp en cada tecla al pasar.
            Timer {
                id: prefetchTimer
                interval: 250
                onTriggered: if (sectionView.currentItem) Player.prefetchItem(JSON.stringify(sectionView.currentItem))
            }

            // Depuración: `--step n [--step-delay ms]` mueve la vista n elementos (negativo =
            // izquierda) tras ese tiempo; con `--delay` se captura en mitad del movimiento.
            Timer {
                id: stepTimer
                interval: win.arg("--step-delay") !== "" ? parseInt(win.arg("--step-delay")) : 1500
                onTriggered: sectionView.stepBy(parseInt(win.arg("--step")))
            }

            // Depuración: `--autoplay [--autoplay-delay ms] [--then-next ms]`.
            Timer {
                id: autoplayTimer
                interval: win.arg("--autoplay-delay") !== "" ? parseInt(win.arg("--autoplay-delay")) : 0
                onTriggered: {
                    // `--open` abre el detalle; `--inspect [flip|open|disc]` lo inspecciona.
                    if (win.args.indexOf("--open") >= 0) {
                        win.choose(sectionView.currentItem)
                        if (win.args.indexOf("--shuffle") >= 0)
                            shuffleTimer.start()
                        return
                    }
                    if (win.args.indexOf("--inspect") >= 0) {
                        win.inspect(sectionView.currentItem)
                        const mode = win.arg("--inspect")
                        Qt.callLater(() => {
                            if (mode === "flip")
                                inspectView.turn()
                            else if (mode === "open")
                                inspectView.toggleOpen()
                            else if (mode === "disc")
                                inspectView.toggleDisc()
                        })
                        return
                    }
                    // `--temporal`: añade a la lista temporal el elemento y abre el menú sobre él.
                    if (win.args.indexOf("--temporal") >= 0) {
                        Player.addToTemporal(JSON.stringify(sectionView.currentItem))
                        win.openMenu(sectionView.currentItem, Qt.point(win.width * 0.35, win.height * 0.45))
                        return
                    }
                    Player.playItem(JSON.stringify(sectionView.currentItem))
                    if (win.arg("--then-next") !== "")
                        nextTimer.start()
                }
            }

            // Depuración: `--open --shuffle` pulsa «Aleatorio» cuando ha cargado el detalle.
            Timer {
                id: shuffleTimer
                interval: 5000
                onTriggered: detailView.play(0, true)
            }

            Timer {
                id: nextTimer
                interval: parseInt(win.arg("--then-next"))
                onTriggered: Player.next()
            }

            Behavior on width { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
        }

        // Estado de la sección cuando aún no hay nada que mostrar.
        Text {
            visible: sectionView.zonas.length === 0 && !win.detailOpen
            x: win.stageX + (win.stageWidth - width) / 2
            y: win.height * 0.4
            width: Math.min(560, win.stageWidth - 80)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Catalog.needsAccount(win.section) && !Account.signedIn
                ? "Inicia sesión con el botón de cuenta (arriba a la derecha) para ver " + Catalog.ownLabel(win.section) + "."
                : Library.loading || Library.searching ? "Cargando…"
                : Library.error !== "" ? Library.error
                : "No hay nada que mostrar aquí."
            color: Theme.textMuted
            font.pixelSize: 16
        }
    }

    IconButton {
        x: win.stageX + 24
        y: 20
        icon: Theme.iconSettings
        label: "Opciones de apariencia"
        solid: true
        onClicked: win.settingsOpen = true
    }

    SearchField {
        id: searchField
        x: win.stageX + 76
        y: 20
        width: Math.max(120, Math.min(240, nav.x - x - 16))
        onSubmitted: query => win.search(query)
        onDismissed: sectionView.forceActiveFocus()
    }

    TopNav {
        id: nav
        x: win.stageX + (win.stageWidth - width) / 2
        y: 16
        current: win.section
        onSelected: section => {
            // Desde un álbum o playlist abierto, cambiar de sección lo cierra.
            if (win.detailOpen)
                win.closeDetail()
            win.nowOpen = false
            win.section = section
            sectionView.forceActiveFocus()
        }

        Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
    }

    // Cuenta: abre las opciones; relleno cuando hay sesión.
    IconButton {
        id: accountButton
        x: win.stageX + win.stageWidth - viewSwitcher.width - 24 - width - 12
        y: 20
        icon: Theme.iconAccount
        label: Account.signedIn ? "Cuenta: " + Account.name : "Iniciar sesión"
        solid: true
        active: Account.signedIn
        onClicked: win.settingsOpen = true

        Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
    }

    Connections {
        target: Plugins
        function onMediaOnChanged() { Player.applyMediaControls() }
    }

    // Al iniciar o cerrar sesión cambia todo el contenido y las cookies de yt-dlp.
    Connections {
        target: Account
        function onSignedInChanged() {
            Player.restartEngine()
            Library.load()
        }
    }

    ViewSwitcher {
        id: viewSwitcher
        x: win.stageX + win.stageWidth - width - 24
        y: 16
        view: win.view
        onPicked: view => win.setView(view)

        Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
    }

    NowPlayingPanel {
        id: panel
        // Depuración: `--tab temporal` abre esa pestaña.
        tab: win.arg("--tab") !== "" ? win.arg("--tab") : "letra"
        x: win.panelX
        y: Theme.gap
        width: win.panelWidth
        height: win.height - win.barHeight - 3 * Theme.gap
        opacity: win.showPanel ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // Estilo "Escenario": la letra vive sobre el escenario, encima del reproductor.
    Column {
        id: stageLyric

        readonly property int line: Catalog.lineAt(Catalog.lyricsTime)
        readonly property real progress: Catalog.lineProgress(line, Catalog.lyricsTime)
        readonly property var words: line >= 0 ? Catalog.lyrics[line].text.split(" ") : []
        readonly property string upcoming: line >= 0 && line + 1 < Catalog.lyrics.length ? Catalog.lyrics[line + 1].text : ""

        visible: !win.vidrio && Player.title !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - win.barHeight - 2 * Theme.gap - win.stageLyricHeight + 8
        width: parent.width - 160
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sonando · " + Player.title + " — " + Player.artist
            color: Theme.textMuted
            font.pixelSize: 11
            font.letterSpacing: 1.8
            font.capitalization: Font.AllUppercase
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 9

            Repeater {
                model: stageLyric.words

                Text {
                    required property string modelData
                    required property int index
                    readonly property real sung: Math.max(0, Math.min(1, stageLyric.progress * stageLyric.words.length - index))

                    text: modelData
                    color: Qt.rgba(1, 1, 1, 0.5 + 0.5 * sung)
                    font.pixelSize: Math.round(34 * Theme.lyricsScale)
                    font.family: Theme.lyricsFamily
                    font.weight: Theme.lyricsWeight
                    font.letterSpacing: -0.4
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stageLyric.upcoming
            color: Theme.textFaint
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }

    NowPlayingView {
        id: nowPlayingView
        anchors.fill: parent
        z: 5
        open: win.nowOpen
        tint: playingProbe.tint
        bottomInset: win.barHeight + 2 * Theme.gap
        onCloseRequested: win.nowOpen = false
    }

    PlayerBar {
        readonly property real fullWidth: win.width - 2 * Theme.gap
        z: 6

        width: win.vidrio ? fullWidth : Math.min(920, fullWidth)
        height: win.barHeight
        x: (win.width - width) / 2
        y: win.height - height - Theme.gap
        compact: !win.vidrio
        backdrop: win.nowOpen ? nowPlayingView : stage
        lyricsOn: win.lyricsOn
        onExpandRequested: win.nowOpen = !win.nowOpen
        onLyricsToggled: win.lyricsOn = !win.lyricsOn
        onMiniRequested: win.showMini()
    }

    DetailView {
        id: detailView
        x: win.stageX
        y: 84
        width: win.stageWidth
        height: win.height - y - win.barHeight - 2 * Theme.gap - win.stageLyricHeight
        visible: win.detailOpen && !win.inspecting
        focus: visible
        onVisibleChanged: if (visible) forceActiveFocus()
        onClosed: win.closeDetail()
        onInspect: win.inspect(null)
        onOpened: item => win.choose(item)
    }

    InspectView {
        id: inspectView
        anchors.fill: parent
        z: 7
        visible: win.inspecting
        backdrop: stage
        onClosed: {
            win.inspecting = false
            detailView.forceActiveFocus()
        }
    }

    MiniPlayer {
        id: miniPlayer
        visible: false
        onRestore: win.restoreFromMini()
    }

    ContextMenu {
        id: contextMenu
        anchors.fill: parent
        z: 9
        backdrop: stage
    }

    SettingsSheet {
        id: settingsSheet
        anchors.fill: parent
        z: 10
        visible: win.settingsOpen
        focus: win.settingsOpen
        backdrop: stage
        onClosed: win.closeSettings()
    }
}
