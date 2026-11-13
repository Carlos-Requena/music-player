import QtQuick
import QtQuick.Effects
import app.musicplayer

// Modo inspeccionar: la caja del álbum o playlist en grande. Se puede girar para leer la
// contraportada (las canciones), abrir y sacar el disco, que gira mientras suena.
FocusScope {
    id: root

    property Item backdrop: null
    readonly property var detail: Catalog.detalle
    readonly property var tracks: detail ? (detail.tracks || []) : []
    readonly property string thumb: detail ? detail.thumb : ""

    property bool flipped: false
    property bool open: false
    property bool discOut: false

    readonly property real side: Math.min(height * 0.6, width * 0.36, 480)
    readonly property real spine: side * 0.06

    signal closed()

    function reset() {
        flipped = false
        open = false
        discOut = false
    }

    function turn() {
        open = false
        discOut = false
        flipped = !flipped
    }

    function toggleOpen() {
        if (flipped)
            flipped = false
        if (open)
            discOut = false
        open = !open
    }

    function toggleDisc() {
        if (flipped)
            flipped = false
        open = true
        discOut = !discOut
    }

    function play() {
        if (tracks.length)
            Player.playTracks(JSON.stringify(tracks), 0, false)
    }

    onVisibleChanged: if (visible) reset()

    Keys.onEscapePressed: root.closed()
    Keys.onLeftPressed: turn()
    Keys.onRightPressed: turn()
    Keys.onSpacePressed: toggleOpen()
    Keys.onReturnPressed: play()
    Keys.onEnterPressed: play()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_D) {
            toggleDisc()
            event.accepted = true
        }
    }

    // Fondo: el escenario desenfocado y oscurecido.
    Glass {
        anchors.fill: parent
        radius: 0
        backdrop: root.backdrop
        tint: Qt.rgba(0.02, 0.025, 0.04, 0.72)
    }

    TapHandler {}

    // Disco: etiqueta con la carátula, recortada en círculo, sobre un CD plateado.
    component Disc: Item {
        id: disc
        property real diameter: 100

        width: diameter
        height: diameter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#E9ECF1" }
                GradientStop { position: 0.45; color: "#AEB4BF" }
                GradientStop { position: 0.55; color: "#D7DCE4" }
                GradientStop { position: 1; color: "#8E95A1" }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.5)
        }

        Item {
            id: labelMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.86
                height: width
                radius: width / 2
            }
        }

        Cover {
            anchors.fill: parent
            thumb: root.thumb
            pixels: 544
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: labelMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.2
            }
        }

        // Agujero central.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.14
            height: width
            radius: width / 2
            color: "#C9CED6"

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.45
                height: width
                radius: width / 2
                color: "#0B0D12"
            }
        }
    }

    Item {
        id: stageArea
        anchors.fill: parent
        anchors.bottomMargin: 120

        // El disco, cuando sale, se desliza a la derecha de la caja.
        Disc {
            id: outsideDisc
            diameter: root.side * 0.86
            x: caseItem.x + root.spine + root.side * 0.07 + (root.discOut ? root.side * 0.78 : 0)
            y: caseItem.y + root.side * 0.07
            // Siempre por encima de la bandeja: dentro de la caja abierta o fuera de ella.
            z: 3
            opacity: root.open && !root.flipped ? 1 : 0
            visible: opacity > 0

            Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 2400
                loops: Animation.Infinite
                running: root.visible && root.discOut && Player.playing
            }
        }

        Item {
            id: caseItem
            width: root.side + root.spine
            height: root.side
            // Abierta, la tapa ocupa sitio a la izquierda; con el disco fuera, a la derecha.
            x: (parent.width - width) / 2 + (root.open && !root.flipped ? root.side * 0.5 : 0) - (root.discOut ? root.side * 0.42 : 0)
            y: (parent.height - height) / 2
            z: 2

            property real angle: root.flipped ? 180 : 0
            readonly property bool showingBack: Math.cos(angle * Math.PI / 180) < 0

            Behavior on angle { NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }
            Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

            transform: Rotation {
                origin.x: caseItem.width / 2
                origin.y: caseItem.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: caseItem.angle
            }

            // Cara delantera: bandeja interior, y encima la portada como una puerta.
            Item {
                anchors.fill: parent
                visible: !caseItem.showingBack

                // Bandeja (se ve al abrir).
                Rectangle {
                    x: root.spine
                    width: root.side
                    height: root.side
                    color: "#15181F"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.side * 0.9
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                    }
                }

                // Lomo.
                Rectangle {
                    width: root.spine
                    height: root.side
                    color: "#0E1015"

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.14) }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.3) }
                        }
                    }
                }

                // Portada: gira sobre su borde izquierdo al abrir.
                Item {
                    id: door
                    x: root.spine
                    width: root.side
                    height: root.side
                    z: 4

                    // Se pliega sobre la bisagra (borde izquierdo) hasta quedar plana a la
                    // izquierda, como una caja de CD abierta vista de frente. Un pliegue plano
                    // en vez de un giro 3D: con perspectiva la tapa se acercaba a la cámara y
                    // tapaba la bandeja.
                    property real fold: root.open ? -1 : 1
                    readonly property bool inside: fold < 0
                    Behavior on fold { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }

                    transform: Scale {
                        origin.x: 0
                        xScale: door.fold
                    }

                    Cover {
                        anchors.fill: parent
                        visible: !door.inside
                        thumb: root.thumb
                        pixels: 544
                    }

                    // Reflejo del plástico de la caja.
                    Rectangle {
                        anchors.fill: parent
                        visible: !door.inside
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                            GradientStop { position: 0.35; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                        }
                    }

                    // Interior de la portada (el libreto).
                    Rectangle {
                        anchors.fill: parent
                        visible: door.inside
                        color: "#E9E4DA"

                        // La tapa plegada se ve al revés: su contenido se invierte de nuevo.
                        Item {
                            id: booklet
                            anchors.fill: parent
                            transform: Scale { origin.x: booklet.width / 2; xScale: -1 }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width * 0.78
                                spacing: root.side * 0.03

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    text: root.detail ? root.detail.title : ""
                                    color: "#2A2621"
                                    font.pixelSize: Math.round(root.side * 0.065)
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width * 0.3
                                    height: 2
                                    color: "#B8AE9C"
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    text: root.detail ? root.detail.subtitle : ""
                                    color: "#5A5247"
                                    font.pixelSize: Math.max(11, Math.round(root.side * 0.032))
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.tracks.length ? root.tracks.length + (root.tracks.length === 1 ? " canción" : " canciones") : ""
                                    color: "#5A5247"
                                    font.pixelSize: Math.max(11, Math.round(root.side * 0.032))
                                }
                            }
                        }
                    }
                }
            }

            // Cara trasera: la contraportada con las canciones.
            Rectangle {
                anchors.fill: parent
                visible: caseItem.showingBack
                color: "#101319"
                clip: true

                transform: Rotation {
                    origin.x: caseItem.width / 2
                    origin.y: caseItem.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: 180
                }

                Cover {
                    anchors.fill: parent
                    thumb: root.thumb
                    pixels: 120
                    opacity: 0.35
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.04, 0.05, 0.07, 0.55)
                }

                Column {
                    x: root.side * 0.08
                    y: root.side * 0.07
                    width: parent.width - 2 * x
                    spacing: root.side * 0.012

                    Text {
                        width: parent.width
                        text: root.detail ? root.detail.title : ""
                        color: Theme.text
                        font.pixelSize: Math.round(root.side * 0.05)
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Item { width: 1; height: root.side * 0.02 }

                    Repeater {
                        model: root.tracks.slice(0, 18)

                        Item {
                            id: line
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: Math.round(root.side * 0.042)

                            Text {
                                width: parent.width - 50
                                text: (line.index + 1) + ".  " + line.modelData.title
                                color: Qt.rgba(1, 1, 1, 0.86)
                                font.pixelSize: Math.max(10, Math.round(root.side * 0.029))
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.right: parent.right
                                text: line.modelData.duration > 0 ? Theme.mmss(line.modelData.duration) : ""
                                color: Qt.rgba(1, 1, 1, 0.6)
                                font.pixelSize: Math.max(10, Math.round(root.side * 0.029))
                            }
                        }
                    }

                    Text {
                        visible: root.tracks.length > 18
                        text: "y " + (root.tracks.length - 18) + " más"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: Math.max(10, Math.round(root.side * 0.029))
                    }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: caseItem.y + caseItem.height + 26
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.flipped ? "Contraportada" : (root.discOut ? "Disco fuera" : (root.open ? "Abierta" : "Cerrada"))
                color: Theme.textMuted
                font.pixelSize: 11
                font.letterSpacing: 1.8
                font.capitalization: Font.AllUppercase
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.detail ? root.detail.title : ""
                color: Theme.text
                font.pixelSize: 26
                font.weight: Font.Bold
            }
        }
    }

    // Controles, como la barra de botones del vídeo de referencia.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 10

        PillButton { text: "Girar  ← →"; onClicked: root.turn() }
        PillButton { text: root.open ? "Cerrar caja  Espacio" : "Abrir caja  Espacio"; onClicked: root.toggleOpen() }
        PillButton { text: root.discOut ? "Guardar disco  D" : "Sacar disco  D"; onClicked: root.toggleDisc() }
        PillButton { text: "Reproducir  ↵"; icon: Theme.iconPlay; primary: true; enabled: root.tracks.length > 0; onClicked: root.play() }
        PillButton { text: "Salir  Esc"; onClicked: root.closed() }
    }
}
