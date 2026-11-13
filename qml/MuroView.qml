import QtQuick
import app.musicplayer

// Vista "Muro": cuadrícula de carátulas agrupada por zonas, con la enfocada ampliada.
FocusScope {
    id: root

    property var zonas: []
    property int cols: 6
    property int row: 0
    property int col: 0

    readonly property real margin: 40
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

    signal activated(var item)

    onZonasChanged: {
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
        const target = rowRepeater.itemAt(row)
        if (!target)
            return
        const top = target.y - 16
        const bottom = target.y + target.height + root.tile * 0.2 + 16
        if (top < flick.contentY)
            flick.contentY = Math.max(0, top)
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height
    }

    Keys.onLeftPressed: moveCol(-1)
    Keys.onRightPressed: moveCol(1)
    Keys.onUpPressed: moveRow(-1)
    Keys.onDownPressed: moveRow(1)
    Keys.onReturnPressed: if (currentItem) activated(currentItem)
    Keys.onEnterPressed: if (currentItem) activated(currentItem)

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: info.height
        contentHeight: column.height + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY { NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }

        Column {
            id: column
            x: root.margin
            width: root.width - 2 * root.margin
            topPadding: 12
            spacing: 20

            Repeater {
                id: rowRepeater
                model: root.rows

                Column {
                    id: rowItem
                    required property var modelData
                    required property int index

                    spacing: 8
                    z: index === root.row ? 2 : 1

                    Text {
                        visible: text.length > 0
                        text: rowItem.modelData.titulo
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.7
                        font.capitalization: Font.AllUppercase
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

                                width: root.tile
                                height: root.tile
                                z: current ? 3 : 1
                                scale: current ? 1.16 : 1
                                transformOrigin: Item.Top

                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.title + ", " + modelData.subtitle

                                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                                Cover {
                                    anchors.fill: parent
                                    art: cell.modelData.art
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "black"
                                    opacity: cell.current ? 0 : 0.24
                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    radius: 4
                                    color: "transparent"
                                    border.width: 3
                                    border.color: Theme.text
                                    visible: cell.current
                                }

                                HoverHandler { cursorShape: Qt.PointingHandCursor }

                                TapHandler {
                                    onTapped: {
                                        root.row = rowItem.index
                                        root.col = cell.index
                                        root.forceActiveFocus()
                                    }
                                    onDoubleTapped: root.activated(cell.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        id: info
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * root.margin
        height: 92
        spacing: 4

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.currentItem ? root.currentItem.title : ""
            color: Theme.text
            font.pixelSize: 32
            font.weight: Font.Bold
            font.letterSpacing: -0.4
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.currentItem ? root.currentItem.subtitle : ""
            color: Theme.textMuted
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }
}
