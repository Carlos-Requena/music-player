import QtQuick
import QtQuick.Shapes
import app.musicplayer

// Cabecera «Órbita» del detalle de un artista (elegida por el propietario): su foto en círculo
// en el centro, un anillo de rayas del color de la foto alrededor y sus tres canciones más
// escuchadas flotando junto al anillo. Debajo, el nombre, los oyentes y Reproducir y Aleatorio.
// Todo es estático: ninguna animación cuesta fotogramas mientras se mira.
Item {
    id: root

    property var detail: null
    property var tracks: []
    // Color dominante de la foto (la sonda de la ventana): tiñe el anillo.
    property color tint: Theme.neutralTint

    signal play(int index, bool shuffle)

    // Medidas: el anillo y el bloque del nombre tienen que caber en el alto disponible.
    readonly property real textBlock: 150
    readonly property real photo: Math.max(150, Math.min(300, width * 0.24, height - textBlock - 260))
    readonly property real ringInner: photo / 2 + 16
    readonly property real ringOuter: Math.max(ringInner + 50, Math.min(photo / 2 + 150, (height - textBlock - 30) / 2))
    readonly property real cx: width / 2
    readonly property real cy: 24 + ringOuter

    // Color de las rayas: el tono de la foto, con saturación y luz suficientes para verse aunque
    // la foto sea gris u oscura.
    function shade(lightness, alpha) {
        const hue = root.tint.hslHue < 0 ? 0.6 : root.tint.hslHue
        return Qt.hsla(hue, Math.max(0.45, root.tint.hslSaturation), lightness, alpha)
    }

    // Rayas del anillo, repartidas en tres trazos (tres tonos). Cada raya sale del borde
    // interior con una longitud que ondula alrededor del círculo, como en la muestra.
    function rays(group) {
        const out = []
        const count = 168
        const band = ringOuter - ringInner
        for (let i = group; i < count; i += 3) {
            const angle = i / count * Math.PI * 2
            const wave = 0.5 + 0.3 * Math.sin(angle * 3 + 0.7) + 0.2 * Math.sin(angle * 7)
            const length = band * Math.max(0.18, Math.min(1, wave))
            const cos = Math.cos(angle), sin = Math.sin(angle)
            out.push([Qt.point(cx + cos * ringInner, cy + sin * ringInner),
                      Qt.point(cx + cos * (ringInner + length), cy + sin * (ringInner + length))])
        }
        return out
    }

    // Las `Shape` con CurveRenderer no se redibujan solas tras ocultar la ventana: se recrean al
    // cambiar `Theme.renderEpoch`, como los iconos.
    Loader {
        id: ring
        anchors.fill: parent
        readonly property int epoch: Theme.renderEpoch
        onEpochChanged: {
            active = false
            active = true
        }

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.shade(0.62, 0.75)
                strokeWidth: 1.6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathMultiline { paths: root.rays(0) }
            }
            ShapePath {
                strokeColor: root.shade(0.48, 0.55)
                strokeWidth: 1.6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathMultiline { paths: root.rays(1) }
            }
            ShapePath {
                strokeColor: root.shade(0.78, 0.4)
                strokeWidth: 1.6
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathMultiline { paths: root.rays(2) }
            }
        }
    }

    Cover {
        x: root.cx - width / 2
        y: root.cy - height / 2
        width: root.photo
        height: root.photo
        radius: root.photo / 2
        thumb: root.detail ? root.detail.thumb : ""
        pixels: 544
    }

    // Las tres más escuchadas, alrededor del anillo: arriba a la izquierda, abajo a la
    // izquierda y a la derecha (como la muestra). Con una ventana estrecha se acercan al anillo.
    Repeater {
        model: Math.min(3, root.tracks.length)

        Glass {
            id: card
            required property int index
            readonly property var track: root.tracks[index]
            // Posición: ángulo alrededor del centro y distancia algo mayor que el anillo.
            readonly property real angle: [-2.45, 2.55, 0.28][index]
            readonly property real reach: root.ringOuter * 0.92 + width / 2

            width: 268
            height: 76
            radius: Theme.radiusM
            x: Math.max(16, Math.min(root.width - width - 16, root.cx + Math.cos(angle) * reach - width / 2))
            y: Math.max(8, root.cy + Math.sin(angle) * root.ringOuter * 0.82 - height / 2)
            tint: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.72)

            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Reproducir " + track.title
            Accessible.onPressAction: root.play(index, false)
            Keys.onReturnPressed: root.play(index, false)
            Keys.onSpacePressed: root.play(index, false)

            Rectangle {
                anchors.fill: parent
                radius: card.radius
                color: "transparent"
                border.width: 1
                border.color: cardHover.hovered ? Theme.glassBorder : Qt.rgba(1, 1, 1, 0.08)
            }

            FocusRing {
                shown: card.activeFocus
                corner: card.radius
            }

            Cover {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                radius: Theme.coverRadius(width)
                thumb: card.track.thumb
                pixels: 120
            }

            Column {
                x: 76
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 76 - 58
                spacing: 2

                Text {
                    width: parent.width
                    text: card.track.title
                    color: Theme.text
                    font.pixelSize: Theme.fontBase
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "Nº " + (card.index + 1) + " · más escuchada"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }
            }

            // Botón de reproducir, redondo y del color de la foto.
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: height / 2
                color: root.shade(0.42, 1)

                Icon {
                    anchors.centerIn: parent
                    path: Theme.iconPlay
                    filled: true
                    size: 16
                    color: Theme.text
                }
            }

            HoverHandler {
                id: cardHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: eventPoint => card.Window.window.openMenu(card.track, eventPoint.scenePosition)
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.play(card.index, false)
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + root.ringOuter + 6
        width: Math.min(parent.width - 2 * Theme.margin, 720)
        spacing: 10

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.detail ? root.detail.title : ""
            color: Theme.text
            font.pixelSize: Theme.fontDisplay
            font.weight: Font.Bold
            font.letterSpacing: Theme.displaySpacing
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: root.detail && root.detail.subtitle ? root.detail.subtitle : ""
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            PillButton {
                text: "Reproducir"
                icon: Theme.iconPlay
                primary: true
                enabled: root.tracks.length > 0
                onClicked: root.play(0, false)
            }

            PillButton {
                text: "Aleatorio"
                icon: Theme.iconShuffle
                enabled: root.tracks.length > 0
                onClicked: root.play(0, true)
            }
        }
    }
}
