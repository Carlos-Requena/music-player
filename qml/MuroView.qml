import QtQuick
import QtQuick.Effects
import app.musicplayer

// Vista "Muro": cuadrícula de carátulas agrupada por zonas, con la enfocada ampliada.
FocusScope {
    id: root

    property var zonas: []
    // Opciones › Disposición › Carátulas del Muro.
    property int cols: {
        const size = AppSettings.opcion("caratulas", AppSettings.revision)
        return size === "pequenas" ? 8 : size === "grandes" ? 4 : 6
    }
    property int row: 0
    property int col: 0

    // Borde izquierdo y derecho (en una categoría de Explorar abierta, medio margen: ya va tras su carátula).
    property real margin: Theme.margin
    readonly property real gap: 18
    readonly property real tile: (width - 2 * margin - (cols - 1) * gap) / cols

    // Cada zona se parte en filas de `cols`; solo la primera fila lleva el título.
    readonly property var rows: {
        const out = []
        for (const zona of zonas)
            for (let i = 0; i < zona.items.length; i += cols)
                out.push({ titulo: i === 0 ? zona.titulo : "", items: zona.items.slice(i, i + cols) })
        return out
    }

    readonly property var currentItem: {
        if (rows.length === 0)
            return null
        const items = rows[Math.min(row, rows.length - 1)].items
        return items[Math.min(col, items.length - 1)]
    }

    // Bajo el ratón: con la opción `clic` en «uno» su nombre sale abajo, como el de la elegida
    // (un clic ya la abre, así que no hay que elegirla para leerlo).
    property var hoverItem: null
    readonly property var shownItem: Theme.singleClick && hoverItem ? hoverItem : currentItem

    signal activated(var item)
    // El puntero entra (`on`) o sale de un elemento: la ventana lo precarga si se queda en él.
    signal hinted(var item, bool on)

    onZonasChanged: {
        hoverItem = null
        row = 0
        col = 0
    }
    onRowChanged: reveal()

    function moveRow(delta) {
        if (rows.length === 0)
            return
        row = Math.max(0, Math.min(rows.length - 1, row + delta))
        col = Math.min(col, rows[row].items.length - 1)
    }

    function moveCol(delta) {
        if (rows.length === 0)
            return
        col = Math.max(0, Math.min(rows[row].items.length - 1, col + delta))
    }

    function reveal() {
        const target = flick.itemAtIndex(row)
        // Una fila lejana aún no existe (la lista solo crea las cercanas): se lleva a la vista
        // sin animar y la siguiente vez ya existe.
        if (!target) {
            flick.positionViewAtIndex(row, ListView.Contain)
            return
        }
        const top = target.y - 16
        const bottom = target.y + target.height + root.tile * 0.2 + 16
        if (top < flick.contentY)
            flick.contentY = Math.max(flick.originY - flick.topMargin, top)
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height
    }

    Keys.onLeftPressed: moveCol(-1)
    Keys.onRightPressed: moveCol(1)
    Keys.onUpPressed: moveRow(-1)
    Keys.onDownPressed: moveRow(1)
    Keys.onReturnPressed: if (currentItem) activated(currentItem)
    Keys.onEnterPressed: if (currentItem) activated(currentItem)

    // Una lista y no una columna con todas las filas: solo existen las filas a la vista y unas
    // pocas más (`cacheBuffer`), no las de toda la sección.
    ListView {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: info.height
        // Una lista vertical pone cada fila en x = 0: el margen va en la lista.
        leftMargin: root.margin
        // Sin etiqueta encima de la primera fila (una categoría de Explorar abierta), la carátula
        // elegida crece hacia arriba: se reserva el hueco para que su aro no se corte.
        topMargin: root.rows.length && root.rows[0].titulo === "" ? Math.ceil(root.tile * 0.06) + Theme.cursorWidth + 8 : 12
        bottomMargin: 48
        spacing: 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(0, Math.round(root.tile * 2))
        model: root.rows

        Behavior on contentY { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }

        WheelScroll { view: flick; behaviorAnimates: true }

        delegate: Column {
            id: rowItem
            required property var modelData
            required property int index

            // Hueco bajo la etiqueta: la carátula elegida crece (×1,12) y su aro no debe pisarla.
            spacing: Math.ceil(root.tile * 0.06) + Theme.cursorWidth + 8
            z: index === root.row ? 2 : 1

            SectionLabel {
                visible: text.length > 0
                text: rowItem.modelData.titulo
                height: 20
                verticalAlignment: Text.AlignVCenter
            }

            Row {
                spacing: root.gap

                Repeater {
                    model: rowItem.modelData.items

                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool current: rowItem.index === root.row && index === root.col
                        // Bajo el ratón, con la opción `brillo`: crece un poco y brilla con el color
                        // de su carátula, como las tarjetas de Explorar.
                        readonly property bool lit: hover.hovered && Theme.hoverGlow
                        // Opción `esquinas`; los artistas, siempre en círculo.
                        readonly property real corner: modelData.kind === "artist" ? width / 2 : Theme.coverRadius(width)

                        width: root.tile
                        height: root.tile
                        z: current ? 3 : lit ? 2 : 1
                        scale: current ? 1.12 : lit ? 1.045 : 1

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title + ", " + modelData.subtitle

                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                        // Halo y sonda de color: solo existen en la carátula bajo el ratón (una sonda
                        // por carátula serían decenas de lienzos). La sonda queda tapada por la carátula.
                        Loader {
                            id: glowBack
                            anchors.fill: parent
                            active: cell.lit
                            readonly property color glow: item ? Theme.glow(item.tint) : Theme.text
                            sourceComponent: Item {
                                property alias tint: probe.tint

                                RectangularShadow {
                                    anchors.fill: parent
                                    radius: cell.corner
                                    blur: 36
                                    spread: 3
                                    color: glowBack.glow
                                    opacity: 0.7
                                }

                                TintProbe {
                                    id: probe
                                    anchors.centerIn: parent
                                    thumb: cell.modelData.thumb
                                }
                            }
                        }

                        Cover {
                            anchors.fill: parent
                            radius: cell.corner
                            thumb: cell.modelData.thumb
                            // Solo descargan y ocupan memoria las filas a la vista o cerca.
                            load: rowItem.y + rowItem.height > flick.contentY - root.tile * 2
                                  && rowItem.y < flick.contentY + flick.height + root.tile * 2
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: cell.corner
                            color: "black"
                            opacity: cell.current || cell.lit ? 0 : 0.24
                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: cell.corner + 4
                            color: "transparent"
                            border.width: Theme.cursorWidth
                            border.color: Theme.text
                            visible: cell.current
                        }

                        // Brillo: reflejo de luz arriba y borde del color de la carátula.
                        Rectangle {
                            anchors.fill: parent
                            radius: cell.corner
                            visible: cell.lit && !cell.current
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(glowBack.glow.r, glowBack.glow.g, glowBack.glow.b, 0.2) }
                                GradientStop { position: 0.45; color: Qt.rgba(glowBack.glow.r, glowBack.glow.g, glowBack.glow.b, 0) }
                            }
                            border.width: 1.5
                            border.color: Qt.rgba(glowBack.glow.r, glowBack.glow.g, glowBack.glow.b, 0.85)
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                root.hinted(cell.modelData, hovered)
                                if (hovered)
                                    root.hoverItem = cell.modelData
                                else if (root.hoverItem === cell.modelData)
                                    root.hoverItem = null
                            }
                        }

                        // Clic derecho: menú con «Añadir a la lista temporal».
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: eventPoint => cell.Window.window.openMenu(cell.modelData, eventPoint.scenePosition)
                        }

                        TapHandler {
                            // Opción `clic`: «doble» (un clic elige, el doble abre o hace sonar)
                            // o «uno» (un clic ya lo abre o lo hace sonar).
                            onTapped: {
                                root.row = rowItem.index
                                root.col = cell.index
                                root.forceActiveFocus()
                                if (Theme.singleClick && tapCount === 1)
                                    root.activated(cell.modelData)
                            }
                            onDoubleTapped: if (!Theme.singleClick) root.activated(cell.modelData)
                        }
                    }
                }
            }
        }
    }

    FocusedCaption {
        id: info
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * root.margin
        height: 100
        // Separado de la última fila de carátulas.
        topPadding: 16
        item: root.shownItem
    }
}
