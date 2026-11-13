import QtQuick
import QtQuick.Effects
import app.musicplayer

// Pantalla «Sonando»: la carátula de lo que suena en grande, centrada, sobre un fondo hecho
// con sus propios colores. Sube desde abajo al pulsar la canción en la barra de reproducción
// y baja al pulsar la carátula, la flecha o Esc. La barra de reproducción queda encima.
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

    readonly property real art: Math.max(160, Math.min((height - bottomInset) * 0.56, width * 0.42, 620))
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

        // Los clics no atraviesan la pantalla: sin esto, cerrarla con la flecha pulsaba
        // también el botón de opciones que queda debajo, en el mismo sitio.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        // El mismo fondo ambiente que el resto de secciones, teñido por la carátula.
        Ambient {
            anchors.fill: parent
            intensity: 1
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
            anchors.horizontalCenter: parent.horizontalCenter
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
            width: parent.width
            height: root.art + 24 + info.height
            y: Math.max(76, (root.height - root.bottomInset - height) / 2 + 10)

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
                width: Math.min(parent.width - 80, 860)
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

                // Línea de la letra que suena, si la hay.
                Text {
                    readonly property int line: Catalog.lineAt(Player.position)
                    width: parent.width
                    topPadding: 10
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    text: line >= 0 ? Catalog.lyrics[line].text : ""
                    color: Theme.text
                    opacity: 0.85
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
    }
}
