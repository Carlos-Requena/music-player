import QtQuick
import QtQuick.Effects
import app.musicplayer

// Barra de reproducción flotante, en uno de tres estilos (opción `barra`, `Theme.barStyle`):
// - «islas»: tres islas de vidrio sueltas (lo que suena, controles con la posición, extras).
// - «clasica»: una barra; los botones con la posición debajo, en el centro.
// - «compacta»: una barra baja; la posición es una línea fina en el borde de arriba y el tiempo
//   va en texto junto a los extras.
// Las piezas (carátula y títulos, «Me gusta», botones, extras) son las mismas en los tres.
Item {
    id: root

    property bool lyricsOn: true
    property Item backdrop: null
    signal lyricsToggled()
    signal miniRequested()
    // Pulsar en cualquier sitio de la barra que no sea un control abre la pantalla «Sonando».
    signal expandRequested()

    // «Me gusta» de lo que suena: está en la sección «Me gusta» o se acaba de dar aquí.
    property string likedId: ""
    readonly property bool liked: {
        const id = Catalog.currentVideoId
        if (id === "")
            return false
        if (id === likedId)
            return true
        for (const zona of Catalog.megusta)
            for (const item of zona.items)
                if (item.videoId === id)
                    return true
        return false
    }

    function like() {
        const id = Catalog.currentVideoId
        if (id === "" || liked)
            return
        likedId = id
        Library.like(id, Player.title)
    }

    // El aviso del resultado lo muestra el menú contextual; aquí solo se deshace si falla.
    Connections {
        target: Library
        function onGustado(mensaje, error) {
            if (error)
                root.likedId = ""
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: Theme.barStyle === "clasica" ? classic
                       : Theme.barStyle === "compacta" ? compact : islands
    }

    // ---------------------------------------------------------------- Piezas comunes

    // Pulsar fuera de los controles abre «Sonando» (los controles se quedan su clic).
    component ExpandTap: TapHandler {
        enabled: Player.title !== ""
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.expandRequested()
    }

    // Carátula, título y artista, y el corazón de «Me gusta». `natural` es el ancho que pide.
    component NowPlaying: Item {
        id: now
        property real coverSize: 46
        property real coverRadius: 23
        readonly property real natural: coverSize + 12 + Math.min(180, Math.max(titleText.implicitWidth, artistText.implicitWidth)) + 6 + Theme.hit

        height: parent ? parent.height : 0

        HoverHandler {
            enabled: Player.title !== ""
            cursorShape: Qt.PointingHandCursor
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Abrir la pantalla Sonando"

        Cover {
            id: cover
            anchors.verticalCenter: parent.verticalCenter
            width: now.coverSize
            height: now.coverSize
            radius: now.coverRadius
            thumb: Player.thumb
            pixels: 120
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: 12
            anchors.right: heart.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                id: titleText
                width: parent.width
                text: Player.title !== "" ? Player.title : "Nada sonando"
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                id: artistText
                width: parent.width
                text: Player.error !== "" ? Player.error : (Player.loading ? "Cargando…" : Player.artist)
                color: Player.error !== "" ? Theme.accent : Theme.textMuted
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        IconButton {
            id: heart
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Catalog.currentVideoId !== ""
            icon: Theme.iconHeart
            iconSize: 20
            filled: root.liked
            foreground: root.liked ? Theme.accent : Theme.textMuted
            label: root.liked ? "Está en tus «Me gusta»" : "Me gusta"
            onClicked: root.like()
        }
    }

    component PreviousButton: IconButton {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        icon: Theme.iconPrevious
        label: "Anterior"
        filled: true
        iconSize: 18
        onClicked: Player.previous()
    }

    component NextButton: IconButton {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        icon: Theme.iconNext
        label: "Siguiente"
        filled: true
        iconSize: 18
        onClicked: Player.next()
    }

    component PlayButton: IconButton {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 46
        height: 46
        icon: Player.playing ? Theme.iconPause : Theme.iconPlay
        label: Player.playing ? "Pausa" : "Reproducir"
        filled: true
        active: true
        onClicked: Player.toggle()

        // Late mientras la pista se está resolviendo.
        SequentialAnimation on opacity {
            running: Player.loading
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    // Aleatorio: baraja lo que queda de la cola detrás de la que suena.
    component ShuffleButton: IconButton {
        readonly property bool usable: Player.index + 2 < Catalog.queue.length
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        icon: Theme.iconShuffle
        label: "Barajar lo que queda de la cola"
        iconSize: 18
        foreground: Theme.textMuted
        opacity: usable ? 1 : 0.4
        onClicked: if (usable) Player.shuffleQueue()
    }

    component RepeatButton: IconButton {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        icon: Player.repetirUna ? Theme.iconRepeatOne : Theme.iconRepeat
        label: Player.repetirUna ? "Repetir esta canción (pulsa para desactivar)"
             : Player.repetir ? "Repetir la cola (pulsa para repetir solo esta canción)"
             : "Repetir"
        iconSize: 18
        foreground: Player.repetir || Player.repetirUna ? Theme.accent : Theme.textMuted
        onClicked: Player.cycleRepeat()
    }

    // Aleatorio, anterior, reproducir, siguiente y repetir (clásica y compacta).
    component Transport: Row {
        spacing: 6
        ShuffleButton {}
        PreviousButton {}
        PlayButton {}
        NextButton {}
        RepeatButton {}
    }

    component Time: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 38
        color: Theme.textMuted
        font.pixelSize: 12
        font.features: { "tnum": 1 }
    }

    // Tiempo, deslizador de la posición y duración.
    component Seek: Row {
        height: 20
        spacing: 10

        Time {
            horizontalAlignment: Text.AlignRight
            text: Theme.mmss(Player.position)
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * (38 + 10)
            label: "Posición"
            fill: Theme.text
            value: Player.duration > 0 ? Player.position / Player.duration : 0
            onMoved: value => Player.seek(value * Player.duration)
        }

        Time {
            text: Theme.mmss(Player.duration)
        }
    }

    // Mini reproductor, panel de letra y cola, y volumen.
    component Extras: Row {
        spacing: 6

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Theme.iconMini
            label: "Mini reproductor"
            onClicked: root.miniRequested()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Theme.iconLyrics
            label: "Panel de letra y cola"
            solid: root.lyricsOn
            onClicked: root.lyricsToggled()
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            path: Theme.iconVolume
            color: Theme.textMuted
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            label: "Volumen"
            fill: Theme.text
            value: Player.volume / 100
            onMoved: value => Player.changeVolume(value * 100)
        }
    }

    // ---------------------------------------------------------------- Islas

    Component {
        id: islands

        Item {
            id: bar
            readonly property int islandGap: Theme.gap

            // Un solo desenfoque para las tres islas: se captura la franja de la barra y se
            // recorta con su forma. Con un desenfoque por isla costaba ~6 MB más.
            ShaderEffectSource {
                id: grab
                anchors.fill: parent
                visible: false
                live: bar.visible && Theme.blur
                sourceItem: root.backdrop
                sourceRect: {
                    if (!root.backdrop)
                        return Qt.rect(0, 0, 0, 0)
                    // Dependencias explícitas: mapToItem no es reactivo por sí solo.
                    void (root.x + root.y + root.width + root.height + root.backdrop.width + root.backdrop.height)
                    const origin = bar.mapToItem(root.backdrop, 0, 0)
                    return Qt.rect(origin.x, origin.y, bar.width, bar.height)
                }
            }

            Item {
                id: shapes
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Repeater {
                    model: [left, middle, right]

                    Rectangle {
                        required property Item modelData
                        x: modelData.x
                        width: modelData.width
                        height: shapes.height
                        radius: height / 2
                        color: "black"
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                visible: root.backdrop !== null && Theme.blur
                source: grab
                blurEnabled: true
                blur: 1
                blurMax: 48
                saturation: 0.25
                maskEnabled: true
                maskSource: shapes
            }

            // Isla: solo el tinte y el borde del vidrio (el desenfoque va debajo, común).
            component Island: Glass {
                height: bar.height
                radius: height / 2
                tint: Theme.glassStrong
                ExpandTap {}
            }

            Island {
                id: left
                width: Math.min(320, 9 + now.natural + 8)

                NowPlaying {
                    id: now
                    x: 9
                    width: parent.width - 9 - 8
                }
            }

            Island {
                id: middle
                // Centrada en la ventana mientras quepa entre las otras dos; si no, ocupa el hueco.
                readonly property real room: bar.width - 2 * Math.max(left.width, right.width) - 2 * bar.islandGap
                readonly property real between: bar.width - left.width - right.width - 2 * bar.islandGap
                width: room >= 420 ? Math.min(760, room) : between
                x: room >= 420 ? (bar.width - width) / 2 : left.width + bar.islandGap

                Row {
                    id: buttons
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    PreviousButton {}
                    PlayButton {}
                    NextButton {}
                }

                Seek {
                    anchors.left: buttons.right
                    anchors.leftMargin: 10
                    anchors.right: modes.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    id: modes
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    ShuffleButton {}
                    RepeatButton {}
                }
            }

            Island {
                id: right
                anchors.right: parent.right
                width: extras.implicitWidth + 30

                Extras {
                    id: extras
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ---------------------------------------------------------------- Clásica

    Component {
        id: classic

        Glass {
            id: bar
            tint: Theme.glassStrong
            radius: 22
            backdrop: root.backdrop

            ExpandTap {}

            NowPlaying {
                id: now
                x: 14
                width: Math.min(300, now.natural)
                coverSize: 56
                coverRadius: 8
            }

            Column {
                anchors.left: now.right
                anchors.right: extras.left
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Transport {
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Seek {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 600)
                }
            }

            Extras {
                id: extras
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---------------------------------------------------------------- Compacta

    Component {
        id: compact

        Glass {
            id: bar
            tint: Theme.glassStrong
            radius: 20
            backdrop: root.backdrop

            ExpandTap {}

            // Posición: una línea fina en el borde de arriba, del color de acento. Se puede
            // pulsar o arrastrar (la zona sensible es más alta que la línea) y, con el foco,
            // las flechas mueven 5 s.
            Item {
                id: progress
                x: bar.radius
                width: bar.width - 2 * bar.radius
                height: 12
                activeFocusOnTab: true

                readonly property real ratio: Player.duration > 0 ? Math.min(1, Player.position / Player.duration) : 0

                Accessible.role: Accessible.Slider
                Accessible.name: "Posición"
                Keys.onLeftPressed: Player.seek(Math.max(0, Player.position - 5))
                Keys.onRightPressed: Player.seek(Math.min(Player.duration, Player.position + 5))

                Rectangle {
                    y: 1
                    width: parent.width
                    height: progressArea.containsMouse || progressArea.pressed || progress.activeFocus ? 5 : 3
                    radius: height / 2
                    color: Theme.control

                    Rectangle {
                        width: parent.width * progress.ratio
                        height: parent.height
                        radius: height / 2
                        color: Theme.accent
                    }
                }

                MouseArea {
                    id: progressArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function report(mouse) {
                        if (Player.duration > 0)
                            Player.seek(Math.max(0, Math.min(1, mouse.x / width)) * Player.duration)
                    }

                    onPressed: mouse => report(mouse)
                    onPositionChanged: mouse => { if (pressed) report(mouse) }
                }
            }

            NowPlaying {
                id: now
                x: 10
                width: Math.min(300, now.natural)
                coverSize: 46
                coverRadius: 8
            }

            Transport {
                id: transport
                anchors.verticalCenter: parent.verticalCenter
                // Centrado en la barra mientras no pise lo de los lados.
                x: Math.max(now.x + now.width + 8, Math.min((bar.width - width) / 2, side.x - width - 8))
            }

            Row {
                id: side
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.mmss(Player.position) + " / " + Theme.mmss(Player.duration)
                    color: Theme.textMuted
                    font.pixelSize: 13
                    font.features: { "tnum": 1 }
                }

                Extras {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
