import QtQuick
import QtQuick.Effects
import app.musicplayer

// Letra dinámica: la línea activa se ilumina palabra a palabra y el resto se atenúa
// y desenfoca según su distancia a ella.
Item {
    id: root

    property real fontSize: 24
    property real position: Player.position

    readonly property var lines: Catalog.lyrics
    readonly property int current: Catalog.lineAt(position)
    readonly property real progress: Catalog.lineProgress(current, position)
    readonly property Item currentLine: {
        void repeater.count
        return current >= 0 ? repeater.itemAt(current) : null
    }

    clip: true

    Text {
        visible: root.lines.length === 0 && Player.title !== ""
        width: parent.width
        text: "Sin letra sincronizada para esta canción."
        color: Theme.textFaint
        font.pixelSize: 15
        wrapMode: Text.WordWrap
    }

    Column {
        id: column
        width: parent.width
        spacing: root.fontSize * 0.5
        y: root.currentLine ? root.height * 0.16 - root.currentLine.y : 0

        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        Repeater {
            id: repeater
            model: root.lines

            Flow {
                id: line
                required property var modelData
                required property int index

                readonly property int distance: index - root.current
                readonly property bool active: distance === 0
                readonly property var words: modelData.text.split(" ")

                width: column.width
                spacing: root.fontSize * 0.26
                visible: distance >= -2 && distance <= 5
                opacity: active ? 1 : (distance < 0 ? 0.62 + 0.18 * distance : Math.max(0.3, 0.74 - 0.11 * distance))

                layer.enabled: visible && !active && Theme.blur
                // En píxeles físicos: el tamaño lógico es media resolución en pantallas Retina.
                layer.textureSize: Qt.size(Math.ceil(width), Math.ceil(height))
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 8
                    blur: Math.min(1, Math.abs(line.distance) * 0.22)
                }

                Behavior on opacity { NumberAnimation { duration: 300 } }

                Repeater {
                    model: line.words

                    Text {
                        required property string modelData
                        required property int index

                        // Parte de esta palabra ya cantada, repartiendo la línea a partes iguales.
                        readonly property real sung: line.active
                            ? Math.max(0, Math.min(1, root.progress * line.words.length - index))
                            : 0

                        text: modelData
                        color: Qt.rgba(1, 1, 1, line.active ? 0.5 + 0.5 * sung : 1)
                        font.pixelSize: root.fontSize
                        font.weight: Font.Bold
                        font.letterSpacing: -0.3
                    }
                }
            }
        }
    }
}
