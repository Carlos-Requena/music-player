import QtQuick
import app.musicplayer

// Opciones de apariencia: estilo de la ventana y vista por defecto de cada sección.
Item {
    id: root

    property Item backdrop: null
    signal closed()

    Keys.onEscapePressed: root.closed()

    function scrollToEnd() {
        settingsFlick.contentY = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
    }

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
        height: Math.min(content.implicitHeight + 60, parent.height - 48)
        radius: 24
        tint: Theme.glassStrong
        backdrop: root.backdrop

        Flickable {
            id: settingsFlick
            anchors.fill: parent
            anchors.topMargin: 28
            anchors.bottomMargin: 28
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            x: 32
            width: parent.width - 64
            spacing: 26

            Item {
                width: parent.width
                height: Theme.hit

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Opciones"
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
                id: accountSection
                width: parent.width
                spacing: 12

                readonly property var browsers: Qt.platform.os === "osx"
                    ? [{ id: "chrome", label: "Chrome" }, { id: "safari", label: "Safari" }, { id: "firefox", label: "Firefox" },
                       { id: "brave", label: "Brave" }, { id: "edge", label: "Edge" }]
                    : [{ id: "chrome", label: "Chrome" }, { id: "chromium", label: "Chromium" }, { id: "firefox", label: "Firefox" },
                       { id: "brave", label: "Brave" }, { id: "vivaldi", label: "Vivaldi" }]

                Heading { text: "Cuenta" }

                Item {
                    width: parent.width
                    height: Theme.hit + 8

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - actionButton.width - 16
                        spacing: 2

                        Text {
                            width: parent.width
                            text: Account.signedIn ? Account.name : "Sin sesión"
                            color: Theme.text
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: Account.signedIn
                                ? "Tu biblioteca, tus playlists y tus «Me gusta» de YouTube Music."
                                : "Usa la sesión de YouTube Music que ya tienes abierta en tu navegador."
                            color: Theme.textMuted
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        id: actionButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: actionLabel.implicitWidth + 40
                        height: Theme.hit
                        radius: height / 2
                        color: Account.signedIn ? (actionHover.hovered ? Theme.controlActive : Theme.control) : Theme.text
                        opacity: Account.busy ? 0.6 : 1
                        border.width: activeFocus ? 2 : 0
                        border.color: Theme.accent
                        activeFocusOnTab: true

                        function act() {
                            if (Account.busy)
                                return
                            if (Account.signedIn)
                                Account.signOut()
                            else
                                Account.signIn()
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: actionLabel.text
                        Accessible.onPressAction: act()
                        Keys.onReturnPressed: act()

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: Account.busy ? "Conectando…" : (Account.signedIn ? "Cerrar sesión" : "Iniciar sesión")
                            color: Account.signedIn ? Theme.text : Theme.ground
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        HoverHandler {
                            id: actionHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: actionButton.act()
                        }
                    }
                }

                Item {
                    visible: !Account.signedIn
                    width: parent.width
                    height: Theme.hit + 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Navegador"
                        color: Theme.text
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Segmented {
                        anchors.right: parent.right
                        width: 480
                        options: accountSection.browsers
                        value: Account.browser
                        onPicked: id => Account.browser = id
                    }
                }

                Text {
                    visible: text !== ""
                    width: parent.width
                    text: Account.message !== "" ? Account.message
                        : !Account.signedIn && Qt.platform.os === "osx"
                          ? (Account.browser === "safari"
                             ? "Safari necesita que des a esta app «Acceso total al disco» en Ajustes del Sistema › Privacidad."
                             : "macOS te pedirá permiso para leer la clave del navegador: pulsa «Permitir».")
                          : ""
                    color: Account.message !== "" && !Account.busy ? Theme.accent : Theme.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                PillButton {
                    visible: Account.needsDiskAccess && Qt.platform.os === "osx"
                    text: "Abrir «Acceso total al disco»"
                    onClicked: Account.openPrivacySettings()
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

                        // `revision` cambia con cada elección: hace que la fila se actualice.
                        readonly property string value: {
                            void AppSettings.revision
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

            Column {
                id: skinSection
                width: parent.width
                spacing: 12

                readonly property var skins: Catalog.parse(AppSettings.skins)

                Heading { text: "Aspecto" }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Repeater {
                        model: skinSection.skins

                        Rectangle {
                            id: skinCard
                            required property var modelData
                            readonly property bool chosen: AppSettings.skin === modelData.id
                            readonly property var preview: {
                                void AppSettings.skins
                                return modelData
                            }

                            width: (skinSection.width - 16) / 2
                            height: 76
                            radius: 16
                            color: skinHover.hovered ? Theme.controlActive : Theme.control
                            border.width: chosen || activeFocus ? 2 : 1
                            border.color: chosen || activeFocus ? Theme.text : Theme.glassBorder
                            activeFocusOnTab: true

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.nombre
                            Accessible.checked: chosen
                            Accessible.onPressAction: AppSettings.elegirSkin(modelData.id)
                            Keys.onReturnPressed: AppSettings.elegirSkin(modelData.id)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 4

                                Text {
                                    text: skinCard.modelData.nombre
                                    color: Theme.text
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: skinCard.modelData.descripcion || ""
                                    color: Theme.textMuted
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler {
                                id: skinHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: AppSettings.elegirSkin(skinCard.modelData.id)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.hit

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - reload.width - 16
                        text: "Tus skins: copia un archivo de la carpeta skins/ del proyecto en " + AppSettings.carpetaSkins() + " y cámbialo."
                        color: Theme.textMuted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    PillButton {
                        id: reload
                        anchors.right: parent.right
                        text: "Recargar skins"
                        onClicked: AppSettings.recargarSkins()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 12

                Heading { text: "Disposición" }

                Repeater {
                    model: [
                        { key: "panel", label: "Panel de letra y cola", fallback: "derecha",
                          options: [{ id: "izquierda", label: "Izquierda" }, { id: "derecha", label: "Derecha" }] },
                        { key: "ambiente", label: "Modo ambiente", fallback: "si",
                          options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
                        { key: "desenfoque", label: "Desenfoque", hint: "Desactivarlo ahorra memoria y batería.", fallback: "si",
                          options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
                        { key: "calidad", label: "Calidad del audio", hint: "Premium (256 kbps) necesita sesión y suscripción.", fallback: "alta",
                          options: [{ id: "alta", label: "Alta · 160 kbps" }, { id: "premium", label: "Premium · 256 kbps" }] },
                        { key: "ytdlp", label: "yt-dlp residente", hint: "Suena ~1 s antes; ocupa ~120 MB mientras navegas.", fallback: "si",
                          options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
                        { key: "caratulas", label: "Carátulas del Muro", fallback: "medianas",
                          options: [{ id: "pequenas", label: "Pequeñas" }, { id: "medianas", label: "Medianas" }, { id: "grandes", label: "Grandes" }] }
                    ]

                    Item {
                        id: layoutRow
                        required property var modelData
                        readonly property string value: {
                            void AppSettings.revision
                            const chosen = AppSettings.opcion(modelData.key)
                            return chosen !== "" ? chosen : modelData.fallback
                        }

                        width: parent.width
                        height: Theme.hit + 8

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: layoutRow.modelData.label
                                color: Theme.text
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: layoutRow.modelData.hint !== undefined
                                text: layoutRow.modelData.hint || ""
                                color: Theme.textMuted
                                font.pixelSize: 12
                            }
                        }

                        Segmented {
                            anchors.right: parent.right
                            options: layoutRow.modelData.options
                            value: layoutRow.value
                            onPicked: id => AppSettings.setOpcion(layoutRow.modelData.key, id)
                        }
                    }
                }
            }

            Column {
                id: pluginSection
                width: parent.width
                spacing: 12

                Heading { text: "Plugins" }

                component Status: Text {
                    width: pluginSection.width
                    visible: text !== ""
                    color: Theme.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                component Toggle: Item {
                    id: toggle
                    property string label
                    property string hint
                    property bool on
                    signal changed(bool on)

                    width: pluginSection.width
                    height: Theme.hit + 8

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 400
                        spacing: 2

                        Text {
                            text: toggle.label
                            color: Theme.text
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            visible: toggle.hint !== ""
                            text: toggle.hint
                            color: Theme.textMuted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    Segmented {
                        anchors.right: parent.right
                        options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }]
                        value: toggle.on ? "si" : "no"
                        onPicked: id => toggle.changed(id === "si")
                    }
                }

                Toggle {
                    label: "Controles del sistema"
                    hint: Qt.platform.os === "osx" ? "Teclas multimedia y Centro de control." : "Teclas multimedia y MPRIS (panel del escritorio)."
                    on: Plugins.mediaOn
                    onChanged: on => Plugins.setMedia(on)
                }

                Toggle {
                    label: "Discord"
                    hint: "Muestra «Escuchando…» en tu perfil."
                    on: Plugins.discordOn
                    onChanged: on => Plugins.setDiscord(on, discordId.text)
                }

                Column {
                    visible: Plugins.discordOn
                    width: parent.width
                    spacing: 8

                    TextField {
                        id: discordId
                        width: parent.width
                        text: Plugins.discordId
                        placeholder: Plugins.discordBuiltin ? "Opcional: Application ID de otra aplicación de Discord"
                                                            : "Application ID de tu aplicación de Discord"
                        onCommitted: text => {
                            if (text !== Plugins.discordId)
                                Plugins.setDiscord(true, text)
                        }
                    }

                    Status {
                        text: Plugins.discordStatus !== "" ? Plugins.discordStatus
                            : Plugins.discordBuiltin ? "Automático: se conecta solo en cuanto abres Discord."
                            : "Esta compilación no trae ID de Discord: crea una aplicación gratis en discord.com/developers/applications y pega su «Application ID»."
                    }
                }

                Toggle {
                    label: "Last.fm"
                    hint: Plugins.lastfmUser !== "" ? "Conectado como " + Plugins.lastfmUser + "." : "Registra lo que escuchas (scrobbling)."
                    on: Plugins.lastfmOn
                    onChanged: on => {
                        if (on && Plugins.lastfmUser === "")
                            lastfmSetup.visible = true
                        else
                            Plugins.setLastfm(on)
                    }
                }

                Column {
                    id: lastfmSetup
                    visible: Plugins.lastfmUser === "" && (Plugins.lastfmOn || Plugins.lastfmPending)
                    width: parent.width
                    spacing: 8

                    Status {
                        text: "Crea una clave de API gratis en last.fm/api/account/create y pega aquí la clave y el secreto."
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        TextField {
                            id: lastfmKey
                            width: (parent.width - 8) / 2
                            text: Plugins.lastfmKey
                            placeholder: "Clave de API"
                        }

                        TextField {
                            id: lastfmSecret
                            width: (parent.width - 8) / 2
                            secret: true
                            placeholder: "Secreto compartido"
                        }
                    }

                    Row {
                        spacing: 8

                        PillButton {
                            text: "Conectar con Last.fm"
                            primary: !Plugins.lastfmPending
                            onClicked: {
                                Plugins.setLastfmKeys(lastfmKey.text, lastfmSecret.text)
                                Plugins.lastfmConnect()
                            }
                        }

                        PillButton {
                            visible: Plugins.lastfmPending
                            primary: true
                            text: "Ya lo he autorizado"
                            onClicked: Plugins.lastfmFinish()
                        }
                    }
                }

                Status { text: Plugins.lastfmStatus }

                PillButton {
                    visible: Plugins.lastfmUser !== ""
                    text: "Desconectar Last.fm"
                    onClicked: Plugins.lastfmDisconnect()
                }
            }
        }
        }
    }
}
