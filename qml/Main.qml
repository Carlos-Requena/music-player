import QtQuick
import QtQuick.Window
import QtQuick.Dialogs
import app.musicplayer

Window {
    id: win

    // Sección visible: una de `Catalog.sections` o "buscar" (resultados de búsqueda).
    property string section: "inicio"
    // El historial cambia al escuchar: se vuelve a pedir cada vez que se abre su sección.
    onSectionChanged: if (section === "historial") Library.loadHistorial()
    // Fuente de Explorar (ListenBrainz o YouTube Music): al cambiarla se vuelve a cargar.
    readonly property string explorarFuente: AppSettings.opcion("explorarFuente", AppSettings.revision)
    onExplorarFuenteChanged: Library.load()
    property bool settingsOpen: false
    property bool inspecting: false
    readonly property bool detailOpen: Catalog.detalle !== null
    // Panel de letra y cola: arranca oculto (lo pidió el propietario) y se abre con su botón de la
    // barra. Depuración: `--panel` arranca con él abierto.
    property bool lyricsOn: Qt.application.arguments.indexOf("--panel") >= 0
    // Pantalla «Sonando» (sube desde la barra de reproducción).
    property bool nowOpen: args.indexOf("--now") >= 0

    // En ventanas estrechas el panel se oculta para que quepa la navegación.
    readonly property bool showPanel: lyricsOn && width >= 1280
    readonly property real panelWidth: 344
    // Opciones › Disposición: el panel de letra a la derecha (por defecto) o a la izquierda.
    readonly property bool panelLeft: AppSettings.opcion("panel", AppSettings.revision) === "izquierda"
    readonly property real panelX: panelLeft ? Theme.gap : width - panelWidth - Theme.gap
    readonly property real stageX: showPanel && panelLeft ? panelWidth + 2 * Theme.gap : 0
    readonly property real stageWidth: showPanel ? width - panelWidth - 2 * Theme.gap : width
    readonly property real barHeight: Theme.barHeight
    readonly property string view: {
        return AppSettings.vista(section, AppSettings.revision)
    }

    // Depuración: `--shot ruta.png [--delay ms] [--section id] [--index n] [--search texto]
    // [--settings] [--autoplay]` prepara la ventana, guarda una captura y sale.
    readonly property var args: Qt.application.arguments
    property bool autoplayPending: args.indexOf("--autoplay") >= 0
    // `--index n` sin `--autoplay`: solo coloca la vista (para capturas).
    property bool indexPending: args.indexOf("--index") >= 0

    Connections {
        id: playIndexOnce
        target: null
        function onQueueChanged() {
            const index = parseInt(win.arg("--play-index"))
            if (Catalog.queue.length > index) {
                playIndexOnce.target = null
                Player.playIndex(index)
            }
        }
    }

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
        if (mascotLoader.item && item.kind !== "song")
            mascotLoader.item.browsed()
        // Una categoría de Explorar se abre como detalle con sus elementos.
        if (item.kind === "zona") {
            Library.openZona(JSON.stringify(item.zona))
            return
        }
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

    // Menú de la canción que suena (clic derecho en la carátula de «Sonando»): la pista de la cola,
    // marcada con su índice para que el menú la trate como la actual.
    function openPlayingMenu(point) {
        const track = Catalog.queue[Player.index]
        if (track)
            openMenu(Object.assign({ queueIndex: Player.index }, track), point)
    }

    // Elemento que se precargará si sigue enfocado o bajo el puntero 250 ms (`prefetchTimer`).
    property var prefetchTarget: null
    function hint(item) {
        prefetchTarget = item
        if (item)
            prefetchTimer.restart()
        else
            prefetchTimer.stop()
    }
    function unhint(item) {
        if (prefetchTarget === item) {
            prefetchTimer.stop()
            prefetchTarget = null
        }
    }

    // «Ir al álbum» o «Ver artista» del menú: baja «Sonando» para que se vea el detalle.
    function openRelated(item, que) {
        nowOpen = false
        inspecting = false
        Library.openRelated(JSON.stringify(item), que)
    }

    function closeDetail() {
        inspecting = false
        Library.closeDetail()
        sectionView.forceActiveFocus()
    }

    function inspect(item) {
        // Una categoría de Explorar no es una caja que se pueda girar.
        if (item && item.kind === "zona")
            item = null
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

    // Lo último que se buscó, para la cabecera de los resultados.
    property string lastQuery: ""

    function search(query) {
        if (query.trim() === "")
            return
        lastQuery = query.trim()
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
        // Depuración: `--play ID [--play-title texto]` reproduce esa canción al arrancar.
        if (arg("--play") !== "")
            Player.playItem(JSON.stringify({ kind: "song", videoId: arg("--play"), title: arg("--play-title"), subtitle: "" }))
        // Depuración: `--related ID [--related-title texto] [--detail-at y]` abre «Relacionado» de
        // esa canción (como el clic derecho) y, con `--detail-at`, lo baja a los 5 s.
        if (arg("--related") !== "") {
            openRelated({ kind: "song", videoId: arg("--related"), title: arg("--related-title"), subtitle: "" }, "related")
            if (arg("--detail-at") !== "")
                detailScroll.start()
        }
        // Depuración: `--play-index N` (con `--play`) salta a la pista N en cuanto llega la cola
        // (probar que la radio trae más canciones al acercarse al final).
        if (arg("--play-index") !== "")
            playIndexOnce.target = Player
        settingsOpen = args.indexOf("--settings") >= 0 || args.indexOf("--settings-end") >= 0
            || args.indexOf("--settings-at") >= 0 || args.indexOf("--settings-cat") >= 0
        if (arg("--settings-cat") !== "")
            settingsSheet.category = arg("--settings-cat")
        // Con un retraso: la hoja recoloca su contenido al hacerse visible.
        if (args.indexOf("--settings-end") >= 0)
            settingsScroll.start()
        if (arg("--settings-at") !== "") {
            settingsScroll.at = parseInt(arg("--settings-at"))
            settingsScroll.start()
        }
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

    // Depuración: `--set clave valor` cambia esa opción al segundo de arrancar, como en Opciones
    // (comprobar que se aplica sin reiniciar). `--set-vista vista` hace lo mismo con la vista de
    // la sección.
    Timer {
        interval: 1000
        running: win.arg("--set") !== "" || win.arg("--set-vista") !== ""
        onTriggered: {
            const at = win.args.indexOf("--set")
            if (at >= 0 && at + 2 < win.args.length)
                AppSettings.setOpcion(win.args[at + 1], win.args[at + 2])
            if (win.arg("--set-vista") !== "")
                AppSettings.setVista(win.section, win.arg("--set-vista"))
        }
    }

    Timer {
        interval: win.arg("--delay") !== "" ? parseInt(win.arg("--delay")) : 1500
        running: win.arg("--shot") !== ""
        onTriggered: {
            console.log("estado:", Player.title, "|", Player.artist, "| pos", Player.position.toFixed(1),
                        "| dur", Player.duration, "| cargando", Player.loading, "| sonando", Player.playing,
                        "| error", Player.error, "| tinte", playingProbe.tint, "| letra", Catalog.lyrics.length, "| cola", Catalog.parse(Player.queue).length, "| calidad", Player.calidad)
            console.log("opciones: clic", Theme.singleClick ? "uno" : "doble", "| esquinas", Theme.roundCovers ? "redondeadas" : "cuadradas",
                        "| barra", Theme.barStyle, "| vista", win.view, "| panel", win.panelLeft ? "izquierda" : "derecha")
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
    // Con «Sonando» arriba del todo queda tapado entero y no se pinta (los vidrios que lo
    // desenfocan, como Opciones, lo siguen capturando aunque esté oculto). Al volver, la sección
    // recupera el foco del teclado, que pierde al ocultarse.
    Item {
        id: stage
        anchors.fill: parent
        visible: !nowPlayingView.covering
        onVisibleChanged: {
            if (visible && !win.settingsOpen && !win.detailOpen && !win.inspecting && !searchField.editing)
                sectionView.forceActiveFocus()
        }

        Ambient {
            anchors.fill: parent
            intensity: Theme.ambient
            stageTint: stageProbe.tint
            playingTint: playingProbe.tint
            stageCenter: win.stageX + win.stageWidth / 2
            playingCenter: win.showPanel ? win.panelX + win.panelWidth / 2 : win.width * 0.9
            // Con «Sonando» abierta se mueve el suyo; este, tapado, se queda quieto.
            moving: Theme.ambientMotion === "siempre" && !win.nowOpen
            thumb: stageProbe.thumb
            // Detrás de las carátulas de la sección: más oscuro que en «Sonando».
            fluidDarken: 0.5
        }

        // Fondo de imagen de la skin (si lo trae), sobre el modo ambiente. Se decodifica al
        // tamaño de la ventana, no al de la imagen original, en escalones de 256 px: al
        // redimensionar la ventana no se vuelve a decodificar a cada píxel.
        Image {
            readonly property int step: 256
            anchors.fill: parent
            visible: Theme.backdrop !== ""
            source: Theme.backdrop
            sourceSize: Qt.size(Math.ceil(win.width * Screen.devicePixelRatio / step) * step,
                                Math.ceil(win.height * Screen.devicePixelRatio / step) * step)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: Theme.backdropOpacity

            Rectangle {
                anchors.fill: parent
                visible: Theme.backdropVeil > 0
                color: Theme.ground
                opacity: Theme.backdropVeil
            }
        }

        SectionView {
            id: sectionView
            x: win.stageX
            y: categoryBar.visible ? 84 + categoryBar.height + 8 : searchHeading.visible ? 84 + searchHeading.height + 8 : 84
            width: win.stageWidth
            height: win.height - y - win.barHeight - 2 * Theme.gap
            section: win.section
            view: win.view
            focus: true
            // Oculta bajo el detalle: no se pinta ni se transparenta.
            visible: !win.detailOpen

            onActivated: item => win.choose(item)
            onHinted: (item, on) => on ? win.hint(item) : win.unhint(item)

            onCurrentItemChanged: {
                win.hint(currentItem)
                if (mascotLoader.item)
                    mascotLoader.item.browsed()
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

            // Precarga lo que el usuario deja enfocado o bajo el puntero un momento, para que al
            // elegirlo suene al instante. La espera evita una petición por cada tecla o cada
            // carátula por la que pasa el ratón; si el puntero sale antes, no se pide nada.
            Timer {
                id: prefetchTimer
                interval: 250
                onTriggered: if (win.prefetchTarget) Player.prefetchItem(JSON.stringify(win.prefetchTarget))
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
                        if (win.arg("--detail-at") !== "")
                            detailScroll.start()
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

            // Depuración: `--open --detail-at y` baja el detalle `y` píxeles cuando ha cargado.
            Timer {
                id: detailScroll
                interval: 5000
                onTriggered: detailView.scrollTo(parseInt(win.arg("--detail-at")))
            }

            Timer {
                id: nextTimer
                interval: parseInt(win.arg("--then-next"))
                onTriggered: Player.next()
            }

            Behavior on width { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
        }

        // Cabecera de los resultados de búsqueda. Las secciones no llevan cabecera (la navegación
        // ya dice dónde estás); la búsqueda sí, porque ninguna pestaña está elegida (ADR-23).
        Text {
            id: searchHeading
            visible: win.section === "buscar" && win.lastQuery !== "" && !win.detailOpen
            x: win.stageX + Theme.margin
            y: 84
            width: win.stageWidth - 2 * Theme.margin
            height: visible ? 36 : 0
            verticalAlignment: Text.AlignVCenter
            text: "Resultados de «" + win.lastQuery + "»"
            color: Theme.text
            font.pixelSize: Theme.fontHeading
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        // Velo bajo el detalle: deja ver el modo ambiente pero lo separa del contenido. Cubre toda
        // la ventana (también tras la navegación), sin el corte recto que quedaba bajo ella.
        Rectangle {
            anchors.fill: parent
            visible: win.detailOpen
            color: Theme.scrim
        }

        // Estado de la sección cuando aún no hay nada que mostrar.
        EmptyState {
            readonly property bool needsLogin: Catalog.needsAccount(win.section) && !Account.signedIn
            visible: sectionView.zonas.length === 0 && !win.detailOpen
            x: win.stageX + (win.stageWidth - width) / 2
            y: win.height * 0.36
            width: Math.min(480, win.stageWidth - 2 * Theme.margin)
            icon: needsLogin ? Theme.iconAccount : win.section === "buscar" && !Library.searching ? Theme.iconSearch : ""
            text: needsLogin
                ? "Inicia sesión para ver " + Catalog.ownLabel(win.section) + "."
                : win.section === "playlists" && Catalog.categoria !== "" && Catalog.playlists.length > 0
                ? "«" + Catalog.categoria + "» está vacía. En «Todas», haz clic derecho en una playlist y elige «Añadir a " + Catalog.categoria + "»."
                : Library.loading || Library.searching ? "Cargando…"
                : Library.error !== "" ? Library.error
                : "No hay nada que mostrar aquí."
            action: needsLogin ? "Iniciar sesión" : ""
            actionIcon: Theme.iconAccount
            onTriggered: {
                settingsSheet.category = "cuenta"
                win.settingsOpen = true
            }
        }
    }

    IconButton {
        x: win.stageX + Theme.margin
        y: 20
        icon: Theme.iconSettings
        label: "Opciones de apariencia"
        solid: true
        onClicked: win.settingsOpen = true
    }

    SearchField {
        id: searchField
        x: win.stageX + Theme.margin + Theme.hit + 8
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

    // Categorías de playlists (OST, Gym…), bajo la navegación y solo en Playlists.
    CategoryBar {
        id: categoryBar
        x: win.stageX + (win.stageWidth - width) / 2
        y: nav.y + nav.height + 8
        visible: win.section === "playlists" && Account.signedIn && !win.detailOpen && !win.nowOpen
        onDone: sectionView.forceActiveFocus()

        Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
    }

    // Cambiar la portada de una playlist: se elige una imagen, se comprueba su tamaño (YouTube
    // pide al menos 360×360) y se sube a la cuenta. El selector solo existe mientras se usa.
    property var coverTarget: null

    function changeCover(item) {
        coverTarget = item
        coverDialogLoader.active = true
        coverDialogLoader.item.open()
    }

    Loader {
        id: coverDialogLoader
        active: false
        sourceComponent: FileDialog {
            title: "Portada de «" + (win.coverTarget ? win.coverTarget.title : "") + "»"
            nameFilters: ["Imágenes (*.jpg *.jpeg *.png)"]
            onAccepted: coverCheck.source = selectedFile
            onRejected: coverDialogLoader.active = false
        }
    }

    // Solo mide la imagen elegida (no se dibuja).
    Image {
        id: coverCheck
        visible: false
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Null || status === Image.Loading)
                return
            const file = source
            const target = win.coverTarget
            const small = status === Image.Ready && Math.min(implicitWidth, implicitHeight) < 360
            source = ""
            coverDialogLoader.active = false
            if (!target)
                return
            if (status === Image.Error)
                contextMenu.notify("No se pudo abrir la imagen.")
            else if (small)
                contextMenu.notify("La imagen es pequeña: YouTube pide al menos 360 × 360 píxeles.")
            else {
                contextMenu.notify("Subiendo la portada de «" + target.title + "»…")
                win.coverFiles[target.playlistId] = file.toString()
                Library.setPlaylistCover(target.playlistId, file.toString())
            }
        }
    }
    property var coverFiles: ({})

    Connections {
        target: Library
        function onPortadaLista(playlistId, error) {
            if (error === "") {
                Catalog.setPortada(playlistId, win.coverFiles[playlistId])
                contextMenu.notify("Portada cambiada en tu cuenta de YouTube Music")
            } else {
                contextMenu.notify(error)
            }
        }
    }

    // Cuenta: abre las opciones; relleno cuando hay sesión.
    IconButton {
        id: accountButton
        // Junto al selector de vista; sin él (con un detalle abierto), en su sitio.
        x: win.stageX + win.stageWidth - Theme.margin - width - (viewSwitcher.visible ? viewSwitcher.width + 12 : 0)
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
        // Explorar muestra las recomendaciones del usuario de ListenBrainz conectado.
        function onListenbrainzUserChanged() { Library.load() }
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
        x: win.stageX + win.stageWidth - width - Theme.margin
        y: 16
        // Con un detalle abierto no cambia nada que se vea: se oculta.
        visible: !win.detailOpen
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
        // Tapado por «Sonando» tampoco se pinta (con su letra en marcha costaba tanto como la de
        // «Sonando»).
        visible: opacity > 0 && !nowPlayingView.covering

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    NowPlayingView {
        id: nowPlayingView
        anchors.fill: parent
        z: 5
        open: win.nowOpen
        tint: playingProbe.tint
        side: win.lyricsOn
        bottomInset: win.barHeight + 2 * Theme.gap
        onCloseRequested: win.nowOpen = false
    }

    // Mascota (Opciones › Mascota), asomada sobre el borde izquierdo de la barra. Con las
    // opciones abiertas se pasa a la esquina inferior izquierda de su panel, bajo las
    // categorías (la misma mascota: no pierde lo que estaba haciendo).
    Loader {
        id: mascotLoader
        z: win.settingsOpen ? 11 : 6
        active: Theme.mascotOn
        x: win.settingsOpen ? settingsSheet.panel.x + 28 : playerBar.x + 18
        y: win.settingsOpen ? settingsSheet.panel.y + settingsSheet.panel.height - height : playerBar.y - height
        sourceComponent: Mascot {}
    }

    PlayerBar {
        id: playerBar
        z: 6

        width: win.width - 2 * Theme.gap
        height: win.barHeight
        x: (win.width - width) / 2
        y: win.height - height - Theme.gap
        backdrop: win.nowOpen ? nowPlayingView.backdrop : stage
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
        height: win.height - y - win.barHeight - 2 * Theme.gap
        visible: win.detailOpen && !win.inspecting && !nowPlayingView.covering
        focus: visible
        onVisibleChanged: if (visible) forceActiveFocus()
        onClosed: win.closeDetail()
        onInspect: win.inspect(null)
        onOpened: item => win.choose(item)
        tint: stageProbe.tint
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
        onNewCategoryRequested: playlistId => {
            win.section = "playlists"
            categoryBar.create(playlistId)
        }
        onRenameCategoryRequested: name => categoryBar.rename(name)
        onCoverRequested: item => win.changeCover(item)
        onRelatedRequested: (item, que) => win.openRelated(item, que)
    }

    // Depuración: `--settings-end` / `--settings-at y` desplazan las opciones ya abiertas.
    Timer {
        id: settingsScroll
        property real at: -1
        interval: 500
        onTriggered: at < 0 ? settingsSheet.scrollToEnd() : settingsSheet.scrollTo(at)
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
