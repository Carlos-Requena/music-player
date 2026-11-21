import QtQuick
import QtQuick.Effects
import app.musicplayer

// Ficha de canción de la cuadrícula del detalle (artista, álbum, playlist): una carátula
// pequeña, como las del Muro, con el título debajo. En un álbum o playlist, según la opción
// `fichas`, la carátula lleva el número de pista en una esquina o se sustituye por el número en
// grande sobre el color del álbum (`tint`): en un álbum todas las carátulas son la misma.
// Solo dibuja, como `TrackRow`: los gestos los pone quien la usa.
Item {
    id: root

    property string title
    property string artist
    property string thumb: ""
    // Mayor que 0: el número de pista (en la esquina, o en grande con `numberOnly`).
    property int number: 0
    property bool numberOnly: false
    // Color del álbum, para el fondo de las fichas con número.
    property color tint: Theme.neutralTint
    property real side: 110
    property bool playing: false
    // Elegida con el clic o el teclado: aro blanco, como en el Muro.
    property bool chosen: false
    // Solo descargan las carátulas de las filas a la vista o cerca.
    property bool load: true
    readonly property bool hovered: hover.hovered
    // Bajo el ratón, con la opción `brillo`: crece y brilla con el color de su carátula.
    readonly property bool lit: hover.hovered && Theme.hoverGlow
    readonly property real corner: Theme.coverRadius(side)

    width: side
    height: side + 6 + caption.height
    z: chosen ? 3 : lit ? 2 : 1

    Accessible.role: Accessible.Button
    Accessible.name: title + (artist !== "" ? ", " + artist : "")

    Item {
        id: art
        width: root.side
        height: root.side
        scale: root.chosen ? 1.06 : root.lit ? 1.04 : 1

        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        // Halo y sonda de color: solo en la ficha bajo el ratón (una sonda por ficha serían
        // decenas de lienzos). Con el número en grande, el color es el del álbum.
        Loader {
            id: glowBack
            anchors.fill: parent
            active: root.lit
            readonly property color glow: Theme.glow(root.numberOnly || !item ? root.tint : item.tint)
            sourceComponent: Item {
                property alias tint: probe.tint

                RectangularShadow {
                    anchors.fill: parent
                    radius: root.corner
                    blur: 28
                    spread: 2
                    color: glowBack.glow
                    opacity: 0.7
                }

                TintProbe {
                    id: probe
                    anchors.centerIn: parent
                    thumb: root.numberOnly ? "" : root.thumb
                }
            }
        }

        Cover {
            anchors.fill: parent
            visible: !root.numberOnly
            radius: root.corner
            thumb: root.thumb
            pixels: 226
            load: root.load && !root.numberOnly
        }

        // Número en grande sobre el color del álbum, de más claro arriba a más oscuro abajo.
        Rectangle {
            anchors.fill: parent
            visible: root.numberOnly
            radius: root.corner
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(root.tint, 1.35) }
                GradientStop { position: 1.0; color: Qt.darker(root.tint, 1.6) }
            }

            Text {
                anchors.centerIn: parent
                text: root.playing ? "▸" : root.number
                color: Theme.text
                font.pixelSize: Theme.fontDisplay
                font.weight: Font.Bold
            }
        }

        // Número de pista en la esquina de la carátula.
        Rectangle {
            visible: !root.numberOnly && root.number > 0
            x: 6
            y: 6
            width: Math.max(height, cornerNumber.implicitWidth + 10)
            height: cornerNumber.implicitHeight + 4
            radius: height / 2
            color: Theme.scrim

            Text {
                id: cornerNumber
                anchors.centerIn: parent
                text: root.number
                color: Theme.text
                font.pixelSize: Theme.fontMini
                font.weight: Font.DemiBold
            }
        }

        // Las demás, un poco apagadas, como en el Muro.
        Rectangle {
            anchors.fill: parent
            radius: root.corner
            color: "black"
            opacity: root.chosen || root.lit || root.playing ? 0 : 0.2
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: root.corner + 4
            color: "transparent"
            border.width: Theme.cursorWidth
            border.color: Theme.text
            visible: root.chosen
        }

        // Brillo: reflejo de luz arriba y borde del color de la carátula.
        Rectangle {
            anchors.fill: parent
            radius: root.corner
            visible: root.lit && !root.chosen
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(glowBack.glow.r, glowBack.glow.g, glowBack.glow.b, 0.2) }
                GradientStop { position: 0.45; color: Qt.rgba(glowBack.glow.r, glowBack.glow.g, glowBack.glow.b, 0) }
            }
            border.width: 1.5
            border.color: Qt.rgba(glowBack.glow.r, glowBack.glow.g, glowBack.glow.b, 0.85)
        }
    }

    // Título; la que suena, en acento y con ▸ (salvo con el número en grande, que ya lo lleva).
    Text {
        id: caption
        y: root.side + 6
        width: root.side
        text: (root.playing && !root.numberOnly ? "▸ " : "") + root.title
        color: root.playing ? Theme.accent : Theme.text
        font.pixelSize: Theme.fontSmall
        font.weight: root.playing || root.chosen ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
