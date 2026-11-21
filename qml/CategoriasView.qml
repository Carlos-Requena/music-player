import QtQuick
import QtQuick.Effects
import app.musicplayer

// Explorar en Muro: una tarjeta por categoría (cada zona: «Recomendados», «Álbumes y singles
// nuevos»…) con su primera carátula a sangre y el nombre encima, sobre un degradado. Más
// separadas que las carátulas del Muro; al pasar el ratón la tarjeta crece un poco y brilla con
// el color de su carátula, y la del teclado lleva el aro blanco, como en el Muro (ADR-23). Al
// pulsarla se abre como un detalle.
FocusScope {
    id: root

    property var zonas: []
    // Tarjeta elegida con el teclado (y la que abre Intro). `index` para `--index` y `jump`.
    property int index: 0
    // Tarjeta bajo el ratón, o -1: solo brilla esa. Sin el brillo al pasar el ratón (opción
    // `brillo`), no cuenta.
    property int hovered: -1
    readonly property int pointed: Theme.hoverGlow ? hovered : -1

    // Una tarjeta por zona con algo dentro; el elemento lleva la zona entera para abrirla.
    readonly property var cards: zonas.filter(zona => zona.items.length > 0).map(zona => ({
        kind: "zona",
        title: zona.titulo,
        subtitle: count(zona.items),
        thumb: zona.items[0].thumb,
        zona: zona
    }))
    readonly property var currentItem: cards.length ? cards[Math.min(index, cards.length - 1)] : null

    // Opciones › Carátulas del Muro, con tarjetas más grandes que las carátulas del Muro.
    readonly property int cols: {
        const size = AppSettings.opcion("caratulas", AppSettings.revision)
        return size === "pequenas" ? 5 : size === "grandes" ? 3 : 4
    }
    readonly property real margin: Theme.margin
    readonly property real gap: 40
    readonly property real tile: Math.floor((width - 2 * margin - (cols - 1) * gap) / cols)

    signal activated(var item)

    onCardsChanged: index = Math.min(index, Math.max(0, cards.length - 1))
    onIndexChanged: reveal()

    // «20 canciones», «24 álbumes»; si mezcla tipos, «12 elementos».
    function count(items) {
        const names = { song: ["canción", "canciones"], album: ["álbum", "álbumes"],
                        playlist: ["lista", "listas"], artist: ["artista", "artistas"] }
        const kind = items.every(item => item.kind === items[0].kind) ? items[0].kind : ""
        const name = names[kind] || ["elemento", "elementos"]
        return items.length + " " + name[items.length === 1 ? 0 : 1]
    }

    function step(delta) {
        if (cards.length)
            index = Math.max(0, Math.min(cards.length - 1, index + delta))
    }

    // Lleva la fila de la tarjeta elegida a la vista.
    function reveal() {
        const top = Math.floor(index / cols) * (tile + gap) - flick.topMargin
        const bottom = top + tile + flick.topMargin + flick.bottomMargin
        if (top < flick.contentY)
            flick.contentY = Math.max(-flick.topMargin, top)
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onUpPressed: step(-cols)
    Keys.onDownPressed: step(cols)
    Keys.onReturnPressed: if (currentItem) activated(currentItem)
    Keys.onEnterPressed: if (currentItem) activated(currentItem)

    Flickable {
        id: flick
        anchors.fill: parent
        // Hueco arriba y abajo para que el brillo y el aumento no se corten.
        topMargin: 28
        bottomMargin: 48
        contentWidth: width
        contentHeight: grid.height
        clip: true

        WheelScroll { view: flick; behaviorAnimates: true }
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }

        Grid {
            id: grid
            x: root.margin
            columns: root.cols
            spacing: root.gap

            Repeater {
                model: root.cards

                Item {
                    id: card
                    required property var modelData
                    required property int index

                    readonly property bool lit: root.pointed === index
                    // La del teclado.
                    readonly property bool focused: root.activeFocus && root.index === index
                    readonly property color glow: Theme.glow(probe.tint)
                    // Opción `esquinas`.
                    readonly property real corner: Theme.coverRadius(width)

                    width: root.tile
                    height: root.tile
                    z: lit || focused ? 2 : 1
                    scale: lit || focused ? 1.045 : 1

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title + ", " + modelData.subtitle
                    Accessible.onPressAction: root.activated(modelData)

                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                    // Debajo de la carátula: debe pintarse para dar el color, aunque no se vea. En el
                    // centro, porque por las esquinas redondeadas asomaba.
                    TintProbe {
                        id: probe
                        anchors.centerIn: parent
                        thumb: card.modelData.thumb
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        radius: card.corner
                        blur: 44
                        spread: 4
                        color: card.glow
                        opacity: card.lit ? 0.75 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    Cover {
                        anchors.fill: parent
                        thumb: card.modelData.thumb
                        pixels: 544
                        radius: card.corner
                    }

                    // Degradado del fondo de la skin para que el nombre se lea sobre cualquier carátula.
                    Rectangle {
                        anchors.fill: parent
                        radius: card.corner
                        gradient: Gradient {
                            GradientStop { position: 0.3; color: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0) }
                            GradientStop { position: 0.68; color: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.6) }
                            GradientStop { position: 1.0; color: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.94) }
                        }
                    }

                    // Brillo: un reflejo de luz arriba y el borde del color de la carátula.
                    Rectangle {
                        anchors.fill: parent
                        radius: card.corner
                        opacity: card.lit ? 1 : 0
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(card.glow.r, card.glow.g, card.glow.b, 0.22) }
                            GradientStop { position: 0.45; color: Qt.rgba(card.glow.r, card.glow.g, card.glow.b, 0) }
                        }
                        border.width: 1.5
                        border.color: Qt.rgba(card.glow.r, card.glow.g, card.glow.b, 0.85)
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    // Aro de la tarjeta del teclado, como el del Muro.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: card.corner + 4
                        color: "transparent"
                        border.width: Theme.cursorWidth
                        border.color: Theme.text
                        visible: card.focused
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Math.round(root.tile * 0.075)
                        spacing: 4

                        Text {
                            width: parent.width
                            text: card.modelData.title
                            color: Theme.text
                            font.pixelSize: Theme.fontHeading
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            font.capitalization: Font.AllUppercase
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            lineHeight: 1.05
                        }

                        Text {
                            width: parent.width
                            text: card.modelData.subtitle
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered)
                                root.hovered = card.index
                            else if (root.hovered === card.index)
                                root.hovered = -1
                        }
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            root.index = card.index
                            root.forceActiveFocus()
                            root.activated(card.modelData)
                        }
                    }
                }
            }
        }
    }
}
