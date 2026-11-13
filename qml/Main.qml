import QtQuick
import QtQuick.Window
import app.musicplayer

Window {
    id: win

    property string section: "inicio"
    property bool settingsOpen: false
    property bool lyricsOn: true

    readonly property bool vidrio: AppSettings.ventana !== "escenario"
    readonly property bool showPanel: vidrio && lyricsOn
    readonly property real panelWidth: 344
    readonly property real stageWidth: showPanel ? width - panelWidth - 2 * Theme.gap : width
    readonly property real barHeight: vidrio ? 84 : 80
    readonly property real stageLyricHeight: vidrio ? 0 : 118
    readonly property string view: {
        switch (section) {
        case "explorar": return AppSettings.vistaExplorar
        case "playlists": return AppSettings.vistaPlaylists
        case "albumes": return AppSettings.vistaAlbumes
        default: return AppSettings.vistaInicio
        }
    }

    function cycleView() {
        const order = ["lomos", "cubeta", "muro"]
        AppSettings.setVista(section, order[(order.indexOf(view) + 1) % order.length])
    }

    function closeSettings() {
        settingsOpen = false
        sectionView.forceActiveFocus()
    }

    width: 1440
    height: 900
    minimumWidth: 1120
    minimumHeight: 720
    visible: true
    color: Theme.ground
    title: "Reproductor de música"

    // Depuración: `--shot ruta.png [--section id] [--settings]` guarda una captura y sale.
    readonly property var args: Qt.application.arguments

    function arg(name) {
        const at = args.indexOf(name)
        return at >= 0 && at + 1 < args.length ? args[at + 1] : ""
    }

    Timer {
        interval: 1500
        running: win.arg("--shot") !== ""
        onTriggered: win.contentItem.grabToImage(result => {
            result.saveToFile(win.arg("--shot"))
            Qt.quit()
        })
    }

    Component.onCompleted: {
        if (arg("--section") !== "")
            section = arg("--section")
        settingsOpen = args.indexOf("--settings") >= 0
        if (!settingsOpen)
            sectionView.forceActiveFocus()
    }

    // Reloj de la reproducción simulada; lo sustituirá el backend de audio.
    Timer {
        interval: 100
        repeat: true
        running: Player.playing
        onTriggered: Player.tick(0.1)
    }

    Shortcut { sequence: "Space"; enabled: !win.settingsOpen; onActivated: Player.toggle() }
    Shortcut { sequence: "V"; enabled: !win.settingsOpen; onActivated: win.cycleView() }
    Shortcut { sequences: [StandardKey.Preferences]; onActivated: win.settingsOpen = true }
    Shortcut { sequence: "Escape"; enabled: win.settingsOpen; onActivated: win.closeSettings() }

    // Escenario: fondo ambiente y contenido de la sección. Es la capa que desenfocan los vidrios.
    Item {
        id: stage
        anchors.fill: parent

        Ambient {
            anchors.fill: parent
            stageTint: Catalog.tint(sectionView.focusedArt)
            playingTint: Catalog.tint(Player.cover)
            stageCenter: win.stageWidth / 2
            playingCenter: win.showPanel ? win.width - win.panelWidth / 2 : win.width * 0.9
        }

        SectionView {
            id: sectionView
            y: 84
            width: win.stageWidth
            height: win.height - y - win.barHeight - 2 * Theme.gap - win.stageLyricHeight
            section: win.section
            view: win.view
            focus: true

            Behavior on width { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
        }
    }

    IconButton {
        x: 24
        y: 20
        icon: Theme.iconSettings
        label: "Opciones de apariencia"
        solid: true
        onClicked: win.settingsOpen = true
    }

    TopNav {
        x: (win.stageWidth - width) / 2
        y: 16
        current: win.section
        onSelected: section => {
            win.section = section
            sectionView.forceActiveFocus()
        }

        Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
    }

    ViewSwitcher {
        x: win.stageWidth - width - 24
        y: 16
        view: win.view
        onPicked: view => {
            AppSettings.setVista(win.section, view)
            sectionView.forceActiveFocus()
        }

        Behavior on x { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
    }

    NowPlayingPanel {
        x: win.width - width - Theme.gap
        y: Theme.gap
        width: win.panelWidth
        height: win.height - win.barHeight - 3 * Theme.gap
        opacity: win.showPanel ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // Estilo "Escenario": la letra vive sobre el escenario, encima del reproductor.
    Column {
        visible: !win.vidrio
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - win.barHeight - 2 * Theme.gap - win.stageLyricHeight + 8
        width: parent.width - 160
        spacing: 6

        readonly property int line: Catalog.lineAt(Player.position)
        readonly property real progress: Catalog.lineProgress(line, Player.position)
        readonly property var words: Catalog.lyrics[line].text.split(" ")

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sonando · " + Player.title + " — " + Player.artist
            color: Theme.textMuted
            font.pixelSize: 11
            font.letterSpacing: 1.8
            font.capitalization: Font.AllUppercase
        }

        Row {
            id: stageLine
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 9

            Repeater {
                model: stageLine.parent.words

                Text {
                    required property string modelData
                    required property int index
                    readonly property real sung: Math.max(0, Math.min(1, stageLine.parent.progress * stageLine.parent.words.length - index))

                    text: modelData
                    color: Qt.rgba(1, 1, 1, 0.5 + 0.5 * sung)
                    font.pixelSize: 34
                    font.weight: Font.Bold
                    font.letterSpacing: -0.4
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stageLine.parent.line + 1 < Catalog.lyrics.length ? Catalog.lyrics[stageLine.parent.line + 1].text : ""
            color: Theme.textFaint
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }

    PlayerBar {
        readonly property real fullWidth: win.width - 2 * Theme.gap

        width: win.vidrio ? fullWidth : Math.min(920, fullWidth)
        height: win.barHeight
        x: (win.width - width) / 2
        y: win.height - height - Theme.gap
        compact: !win.vidrio
        backdrop: stage
        lyricsOn: win.lyricsOn
        onLyricsToggled: win.lyricsOn = !win.lyricsOn
    }

    SettingsSheet {
        anchors.fill: parent
        visible: win.settingsOpen
        focus: win.settingsOpen
        backdrop: stage
        onClosed: win.closeSettings()
    }
}
