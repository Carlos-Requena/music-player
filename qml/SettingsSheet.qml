import QtQuick
import app.musicplayer

// Opciones de apariencia: estilo de la ventana y vista por defecto de cada sección.
Item {
    id: root

    property Item backdrop: null
    signal closed()

    Keys.onEscapePressed: root.closed()

    component Segmented: Rectangle {
        id: seg
        property var options: []
        property string value
        signal picked(string id)

        width: 380
        height: Theme.hit + 8
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.3)

        Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: seg.options

                Item {
                    id: option
                    required property var modelData
                    readonly property bool chosen: modelData.id === seg.value

                    width: (seg.width - 8 - 4 * (seg.options.length - 1)) / seg.options.length
                    height: Theme.hit
                    activeFocusOnTab: true

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: chosen
                    Accessible.onPressAction: seg.picked(modelData.id)
                    Keys.onReturnPressed: seg.picked(modelData.id)

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: option.chosen ? Theme.controlActive : (optionHover.hovered ? Theme.control : "transparent")
                        border.width: option.activeFocus ? 2 : 0
                        border.color: Theme.text
                    }

                    Text {
                        anchors.centerIn: parent
                        text: option.modelData.label
                        color: option.chosen ? Theme.text : Theme.textMuted
                        font.pixelSize: 14
                        font.weight: option.chosen ? Font.DemiBold : Font.Normal
                    }

                    HoverHandler {
                        id: optionHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: seg.picked(option.modelData.id)
                    }
                }
            }
        }
    }

    component Heading: Text {
        color: Theme.textMuted
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.8
        font.capitalization: Font.AllUppercase
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.03, 0.05, 0.55)
    }

    // Un toque fuera de la hoja la cierra.
    TapHandler {
        onTapped: eventPoint => {
            const local = sheet.mapFromItem(root, eventPoint.position.x, eventPoint.position.y)
            if (!sheet.contains(local))
                root.closed()
        }
    }

    Glass {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(880, parent.width - 80)
        height: content.implicitHeight + 60
        radius: 24
        tint: Theme.glassStrong
        backdrop: root.backdrop

        Column {
            id: content
            x: 32
            y: 28
            width: parent.width - 64
            spacing: 26

            Item {
                width: parent.width
                height: Theme.hit

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Apariencia"
                    color: Theme.text
                    font.pixelSize: 30
                    font.weight: Font.Bold
                }

                IconButton {
                    anchors.right: parent.right
                    icon: Theme.iconClose
                    label: "Cerrar"
                    solid: true
                    onClicked: root.closed()
                }
            }

            Column {
                width: parent.width
                spacing: 12

                Heading { text: "Ventana principal" }

                Row {
                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: [
                            { id: "vidrio", label: "Vidrio", detail: "Panel de letra a la derecha y barra de reproducción completa." },
                            { id: "escenario", label: "Escenario", detail: "Sin paneles: letra sobre el escenario y reproductor en píldora." }
                        ]

                        Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool chosen: AppSettings.ventana === modelData.id

                            width: (parent.width - 16) / 2
                            height: 92
                            radius: 16
                            color: cardHover.hovered ? Theme.controlActive : Theme.control
                            border.width: chosen || activeFocus ? 2 : 1
                            border.color: chosen || activeFocus ? Theme.text : Theme.glassBorder
                            activeFocusOnTab: true

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.label
                            Accessible.checked: chosen
                            Accessible.onPressAction: AppSettings.elegirVentana(modelData.id)
                            Keys.onReturnPressed: AppSettings.elegirVentana(modelData.id)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 6

                                Text {
                                    text: card.modelData.label
                                    color: Theme.text
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: card.modelData.detail
                                    color: Theme.textMuted
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }

                            HoverHandler {
                                id: cardHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: AppSettings.elegirVentana(card.modelData.id)
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 12

                Heading { text: "Vista de cada sección" }

                Repeater {
                    model: Catalog.sections

                    Item {
                        id: sectionRow
                        required property var modelData

                        // Cada propiedad notifica por separado; se leen todas para que la fila se actualice.
                        readonly property string value: {
                            void (AppSettings.vistaInicio + AppSettings.vistaExplorar + AppSettings.vistaPlaylists + AppSettings.vistaAlbumes)
                            return AppSettings.vista(modelData.id)
                        }

                        width: parent.width
                        height: Theme.hit + 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: sectionRow.modelData.label
                            color: Theme.text
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        Segmented {
                            anchors.right: parent.right
                            options: Catalog.views
                            value: sectionRow.value
                            onPicked: id => AppSettings.setVista(sectionRow.modelData.id, id)
                        }
                    }
                }

                Text {
                    text: "También puedes alternar la vista con el selector de arriba a la derecha o con la tecla V."
                    color: Theme.textMuted
                    font.pixelSize: 13
                }
            }
        }
    }
}
