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

    signal closeRequested()

    // 0 = escondida abajo, 1 = arriba del todo.
    property real shown: open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

    // Carátula grande con su borde derecho algo pasado el centro de la pantalla; a la derecha,
    // más estrecha, la letra o la cola (pestañas).
    readonly property real artRight: width * 0.505
    readonly property real art: Math.max(200, Math.min((height - bottomInset) * 0.68, artRight - 80, 680))
    readonly property real sideX: artRight + 44
    readonly property real sideWidth: width - sideX - 32
    readonly property real tabsHeight: Theme.hit + 8
    // Pestaña de la derecha. Sin letra solo existe «Cola».
    property string tab: "letra"
    readonly property string shownTab: hasLyrics ? tab : "cola"
    readonly property real sideTop: 84
    readonly property real sideBottom: height - bottomInset - 12
    readonly property bool hasLyrics: Catalog.lyrics.length > 0
    readonly property string bigThumb: Player.thumb.replace("w544-h544", "w1080-h1080")

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
            // Centrada en la carátula, que acaba en `artRight`.
            x: root.artRight - root.art - 60
            width: root.art + 120
            height: root.art + 24 + info.height
            y: Math.max(96, (root.height - root.bottomInset - height) / 2 + 42)

            // Halo del color de la carátula detrás de ella.
            RectangularShadow {
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

                Cover {
                    id: cover
                    anchors.fill: parent
                    thumb: root.bigThumb
                    pixels: 1080
                    load: root.visible
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: roundMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
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

            Item {
                id: roundMask
                width: root.art
                height: root.art
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "black"
                }
            }

            Column {
                id: info
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.art + 28
                width: parent.width - 64
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
            visible: root.shownTab === "letra"
            x: root.sideX
            y: root.sideTop + root.tabsHeight + 12
            width: root.sideWidth
            height: root.sideBottom - y
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.22)
            border.width: 1
            border.color: Theme.glassBorder

            LyricsTiming {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 8
            }

            LyricsView {
                x: 24
                y: 62
                width: parent.width - 48
                height: parent.height - 62 - 12
                baseSize: 30
                showTiming: false
            }
        }

        Rectangle {
            id: queueBox
            visible: root.shownTab === "cola"
            x: root.sideX
            y: root.sideTop + root.tabsHeight + 12
            width: root.sideWidth
            height: root.sideBottom - y
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.22)
            border.width: 1
            border.color: Theme.glassBorder

            ListView {
                id: queueList
                x: 12
                y: 12
                width: parent.width - 24
                height: parent.height - 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Catalog.queue

                // Mantiene a la vista la pista que suena, arriba del todo.
                function follow() {
                    positionViewAtIndex(Math.max(0, Player.index), ListView.Beginning)
                }
                onCountChanged: follow()
                onVisibleChanged: if (visible) follow()
                Connections {
                    target: Player
                    function onIndexChanged() { queueList.follow() }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: index === Player.index

                    width: queueList.width
                    height: 58

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title + ", " + modelData.artist
                    Accessible.onPressAction: Player.playIndex(index)

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: row.current ? Theme.controlActive : (rowHover.hovered ? Theme.control : "transparent")
                    }

                    Cover {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42
                        height: 42
                        thumb: row.modelData.thumb
                        pixels: 120
                    }

                    Column {
                        x: 64
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 64 - 60
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: Theme.text
                            font.pixelSize: 15
                            font.weight: row.current ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: row.modelData.artist
                            color: Theme.textMuted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.current ? "Sonando" : Theme.mmss(row.modelData.duration)
                        color: row.current ? Theme.accent : Theme.textMuted
                        font.pixelSize: 12
                    }

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Player.playIndex(row.index)
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: eventPoint => row.Window.window.openMenu(row.modelData, eventPoint.scenePosition)
                    }
                }
            }
        }
    }
}
