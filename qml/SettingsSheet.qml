import QtQuick
import app.musicplayer

// Opciones, agrupadas por categorías (barra lateral): cuenta, reproducción, apariencia, vistas
// y plugins.
Item {
    id: root

    property Item backdrop: null
    signal closed()

    // El panel de la hoja (la mascota se apoya en su borde inferior izquierdo).
    readonly property Item panel: sheet

    // Categoría que se ve (se recuerda mientras la app sigue abierta).
    property string category: "cuenta"
    readonly property var categories: [
        { id: "cuenta", label: "Cuenta", icon: Theme.iconAccount },
        { id: "reproduccion", label: "Reproducción", icon: Theme.iconPlay },
        { id: "apariencia", label: "Apariencia", icon: Theme.iconImage },
        { id: "vistas", label: "Vistas", icon: Theme.iconMuro },
        { id: "plugins", label: "Plugins", icon: Theme.iconPlug }
    ]
    onCategoryChanged: settingsFlick.contentY = 0

    function stepCategory(delta) {
        const at = categories.findIndex(c => c.id === category)
        category = categories[Math.max(0, Math.min(categories.length - 1, at + delta))].id
    }

    // Opciones sueltas (`AppSettings.opcion`), cada una en su categoría.
    readonly property var optionRows: [
        { cat: "reproduccion", key: "calidad", label: "Calidad del audio", hint: "Premium (256 kbps) necesita sesión y suscripción.", fallback: "alta",
          options: [{ id: "alta", label: "Alta · 160 kbps" }, { id: "premium", label: "Premium · 256 kbps" }] },
        { cat: "reproduccion", key: "historial", label: "Registrar en YouTube Music",
          hint: "Con sesión, lo que escuchas cuenta como reproducción: entra en tu historial y tus recomendaciones, y suma para el artista. No retrasa el arranque. YouTube puede pausar otro dispositivo que suene a la vez con tu cuenta.",
          fallback: "si", options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
        { cat: "reproduccion", key: "ytdlp", label: "yt-dlp residente", hint: "Suena ~1 s antes; ocupa ~120 MB mientras navegas.", fallback: "si",
          options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
        { cat: "apariencia", key: "ambiente", label: "Modo ambiente", hint: "Suave y Tenue usan un solo color; Tenue, apenas un velo.", fallback: "si",
          options: [{ id: "si", label: "Vivo" }, { id: "suave", label: "Suave" }, { id: "tenue", label: "Tenue" }, { id: "no", label: "No" }] },
        { cat: "apariencia", key: "desenfoque", label: "Desenfoque", hint: "Desactivarlo ahorra memoria y batería.", fallback: "si",
          options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
        { cat: "apariencia", key: "letraCalidad", label: "Calidad de la letra",
          hint: "CPU con la letra a la vista: Calidad ~32 %, Equilibrado ~20 %, Bajo ~14 % (como con la cola).",
          fallback: "equilibrado", options: [{ id: "calidad", label: "Calidad" }, { id: "equilibrado", label: "Equilibrado" }, { id: "bajo", label: "Bajo" }] },
        { cat: "apariencia", key: "letraTamano", label: "Tamaño de la letra", hint: "El retraso se ajusta en cada canción, bajo su letra.", fallback: "mediana",
          options: [{ id: "pequena", label: "Pequeña" }, { id: "mediana", label: "Mediana" }, { id: "grande", label: "Grande" }, { id: "enorme", label: "Enorme" }] },
        { cat: "apariencia", key: "letraFuente", label: "Fuente de la letra", fallback: "sistema",
          options: [{ id: "sistema", label: "Sistema" }, { id: "serif", label: "Serif" }, { id: "mono", label: "Mono" }] },
        { cat: "apariencia", key: "letraPeso", label: "Grosor de la letra", fallback: "negrita",
          options: [{ id: "negrita", label: "Negrita" }, { id: "normal", label: "Normal" }] },
        { cat: "vistas", key: "panel", label: "Panel de letra y cola", fallback: "derecha",
          options: [{ id: "izquierda", label: "Izquierda" }, { id: "derecha", label: "Derecha" }] },
        { cat: "vistas", key: "caratulas", label: "Carátulas del Muro", fallback: "medianas",
          options: [{ id: "pequenas", label: "Pequeñas" }, { id: "medianas", label: "Medianas" }, { id: "grandes", label: "Grandes" }] }
    ]

    Keys.onEscapePressed: root.closed()

    function scrollTo(y) {
        settingsFlick.contentY = Math.max(0, Math.min(y, settingsFlick.contentHeight - settingsFlick.height))
    }

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
        width: Math.min(980, parent.width - 80)
        // Alto fijo: no da saltos al cambiar de categoría.
        height: Math.min(760, parent.height - 48)
        radius: 24
        tint: Theme.glassStrong
        backdrop: root.backdrop

        Item {
            id: header
            x: 32
            y: 24
            width: parent.width - 64
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

        // Categorías, como en los ajustes del sistema. ↑/↓ cambian de una a otra.
        Column {
            id: sidebar
            x: 20
            anchors.top: header.bottom
            anchors.topMargin: 22
            width: 196
            spacing: 4

            Keys.onUpPressed: root.stepCategory(-1)
            Keys.onDownPressed: root.stepCategory(1)

            Repeater {
                model: root.categories

                Item {
                    id: catItem
                    required property var modelData
                    readonly property bool chosen: modelData.id === root.category

                    width: sidebar.width
                    height: Theme.hit
                    activeFocusOnTab: true

                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.checked: chosen
                    Accessible.onPressAction: root.category = modelData.id
                    Keys.onReturnPressed: root.category = modelData.id
                    Keys.onSpacePressed: root.category = modelData.id

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: catItem.chosen ? Theme.controlActive : (catHover.hovered ? Theme.control : "transparent")
                        border.width: catItem.activeFocus ? 2 : 0
                        border.color: Theme.text
                    }

                    Icon {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        path: catItem.modelData.icon
                        size: 18
                        color: catItem.chosen ? Theme.text : Theme.textMuted
                    }

                    Text {
                        x: 44
                        anchors.verticalCenter: parent.verticalCenter
                        text: catItem.modelData.label
                        color: catItem.chosen ? Theme.text : Theme.textMuted
                        font.pixelSize: 15
                        font.weight: catItem.chosen ? Font.DemiBold : Font.Normal
                    }

                    HoverHandler {
                        id: catHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.category = catItem.modelData.id
                    }
                }
            }
        }

        Rectangle {
            x: sidebar.x + sidebar.width + 16
            anchors.top: sidebar.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: 1
            color: Theme.glassBorder
        }

        Flickable {
            id: settingsFlick
            x: sidebar.x + sidebar.width + 40
            anchors.top: sidebar.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: parent.width - x - 32
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: 26

            Column {
                visible: root.category === "cuenta"
                id: accountSection
                width: parent.width
                spacing: 12

                readonly property var browsers: Qt.platform.os === "osx"
                    ? [{ id: "chrome", label: "Chrome" }, { id: "safari", label: "Safari" }, { id: "firefox", label: "Firefox" },
                       { id: "brave", label: "Brave" }, { id: "edge", label: "Edge" }]
                    : [{ id: "chrome", label: "Chrome" }, { id: "chromium", label: "Chromium" }, { id: "firefox", label: "Firefox" },
                       { id: "brave", label: "Brave" }, { id: "vivaldi", label: "Vivaldi" }]

                // Ventana propia de inicio de sesión (macOS, y Linux con qt6-webengine); importar
                // del navegador queda como alternativa (en macOS exige «Acceso total al disco»).
                readonly property bool webLogin: Account.webLogin
                property bool importing: !webLogin

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
                                : accountSection.webLogin
                                  ? "Entra con tu cuenta de Google para ver tu biblioteca, tus playlists y tus «Me gusta»."
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
                            else if (accountSection.webLogin)
                                Account.signInWeb()
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
                    visible: !Account.signedIn && accountSection.importing
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
                        : !Account.signedIn && !accountSection.webLogin && Qt.platform.os !== "osx"
                          ? "Para iniciar sesión en una ventana, instala qt6-webengine y vuelve a instalar el reproductor (scripts/instalar-linux.sh)."
                        : !Account.signedIn && Qt.platform.os === "osx" && accountSection.importing
                          ? (Account.browser === "safari"
                             ? "macOS exige «Acceso total al disco» para leer los datos de Safari."
                             : "macOS puede pedir «Acceso total al disco» y permiso para la clave del navegador.")
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

                Row {
                    visible: !Account.signedIn && accountSection.webLogin && !Account.busy
                    spacing: 12

                    PillButton {
                        visible: !accountSection.importing
                        text: "Importar desde el navegador"
                        onClicked: accountSection.importing = true
                    }

                    PillButton {
                        visible: accountSection.importing
                        text: "Importar de " + (accountSection.browsers.find(b => b.id === Account.browser) || { label: Account.browser }).label
                        onClicked: Account.signIn()
                    }

                    PillButton {
                        visible: accountSection.importing
                        text: "Cancelar"
                        onClicked: accountSection.importing = false
                    }
                }
            }

            Column {
                visible: root.category === "vistas"
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
                visible: root.category === "apariencia"
                id: skinSection
                width: parent.width
                spacing: 12

                readonly property var skins: Catalog.parse(AppSettings.skins)

                Heading { text: "Skin" }

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
                    height: Math.max(Theme.hit, skinsHint.implicitHeight)

                    Text {
                        id: skinsHint
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

            // Mascotas: aparte de las skins, para combinarlas como se quiera.
            Column {
                visible: root.category === "apariencia"
                id: mascotSection
                width: parent.width
                spacing: 12

                readonly property var mascots: [{ id: "", nombre: "Ninguna", descripcion: "Sin mascota sobre la barra." }]
                    .concat(Catalog.parse(AppSettings.mascotas))

                Heading { text: "Mascota" }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    Repeater {
                        model: mascotSection.mascots

                        Rectangle {
                            id: mascotCard
                            required property var modelData
                            readonly property bool chosen: AppSettings.mascota === modelData.id

                            width: (mascotSection.width - 16) / 2
                            height: 76
                            radius: 16
                            color: mascotHover.hovered ? Theme.controlActive : Theme.control
                            border.width: chosen || activeFocus ? 2 : 1
                            border.color: chosen || activeFocus ? Theme.text : Theme.glassBorder
                            activeFocusOnTab: true

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: "Mascota " + modelData.nombre
                            Accessible.checked: chosen
                            Accessible.onPressAction: AppSettings.elegirMascota(modelData.id)
                            Keys.onReturnPressed: AppSettings.elegirMascota(modelData.id)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 4

                                Text {
                                    text: mascotCard.modelData.nombre
                                    color: Theme.text
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: mascotCard.modelData.descripcion || ""
                                    color: Theme.textMuted
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler {
                                id: mascotHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: AppSettings.elegirMascota(mascotCard.modelData.id)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(Theme.hit, mascotsHint.implicitHeight)

                    Text {
                        id: mascotsHint
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - reloadMascots.width - 16
                        text: "Tus mascotas: una carpeta con mascota.json y sus PNG en " + AppSettings.carpetaMascotas() + "."
                        color: Theme.textMuted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    PillButton {
                        id: reloadMascots
                        anchors.right: parent.right
                        text: "Recargar"
                        onClicked: AppSettings.recargarSkins()
                    }
                }
            }

            // Filas de opciones sueltas de la categoría elegida (ver `optionRows`).
            Column {
                readonly property var rows: root.optionRows.filter(row => row.cat === root.category)
                readonly property var headings: ({ reproduccion: "Audio", apariencia: "Ambiente y letra", vistas: "Disposición" })

                id: optionSection
                visible: rows.length > 0
                width: parent.width
                spacing: 12

                Heading { text: optionSection.headings[root.category] || "" }

                Repeater {
                    model: optionSection.rows

                    Item {
                        id: layoutRow
                        required property var modelData
                        readonly property string value: {
                            void AppSettings.revision
                            const chosen = AppSettings.opcion(modelData.key)
                            return chosen !== "" ? chosen : modelData.fallback
                        }

                        width: parent.width
                        height: Math.max(Theme.hit + 8, labels.implicitHeight)

                        Column {
                            id: labels
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - segmented.width - 20
                            spacing: 2

                            Text {
                                width: parent.width
                                text: layoutRow.modelData.label
                                color: Theme.text
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                width: parent.width
                                visible: layoutRow.modelData.hint !== undefined
                                text: layoutRow.modelData.hint || ""
                                color: Theme.textMuted
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }

                        Segmented {
                            id: segmented
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            // Estrecho si los textos son cortos; ancho si alguno es largo.
                            width: Math.min(380, layoutRow.modelData.options.length
                                            * (layoutRow.modelData.options.some(o => o.label.length > 12) ? 190 : 110))
                            options: layoutRow.modelData.options
                            value: layoutRow.value
                            onPicked: id => AppSettings.setOpcion(layoutRow.modelData.key, id)
                        }
                    }
                }
            }

            Column {
                visible: root.category === "plugins"
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
