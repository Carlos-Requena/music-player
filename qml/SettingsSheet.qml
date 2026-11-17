import QtQuick
import QtQuick.Shapes
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
        { cat: "apariencia", key: "ambiente", label: "Modo ambiente",
          hint: "Suave y Tenue: un solo color; Tenue, apenas un velo. Plano: un color sólido, sin degradados (para pantallas antiguas). Fluido: la carátula desenfocada como fondo.",
          fallback: "si",
          options: [{ id: "si", label: "Vivo" }, { id: "suave", label: "Suave" }, { id: "tenue", label: "Tenue" }, { id: "plano", label: "Plano" }, { id: "fluido", label: "Fluido" }, { id: "no", label: "No" }] },
        { cat: "apariencia", key: "ambienteMovimiento", label: "Movimiento del ambiente",
          hint: "Los focos pasean despacio mientras suena. Gasta ~5 % de CPU y unos 100 MB más de memoria; en Plano no se mueve.",
          fallback: "no", options: [{ id: "no", label: "No" }, { id: "sonando", label: "En Sonando" }, { id: "siempre", label: "Siempre" }] },
        { cat: "apariencia", key: "caratulaCalidad", label: "Carátula de «Sonando»",
          hint: "Máxima: al tamaño que ocupa en pantalla (hasta 2400 px); tarda hasta un segundo más la primera vez y usa más memoria. Alta: 1200 px.",
          fallback: "maxima", options: [{ id: "maxima", label: "Máxima" }, { id: "alta", label: "Alta" }] },
        { cat: "apariencia", key: "desenfoque", label: "Desenfoque", hint: "Desactivarlo ahorra memoria y batería.", fallback: "si",
          options: [{ id: "si", label: "Activado" }, { id: "no", label: "Desactivado" }] },
        { cat: "apariencia", key: "barra", label: "Barra de reproducción",
          hint: "Clásica: la posición bajo los botones. Compacta: más baja, la posición arriba.",
          fallback: "islas", options: [{ id: "islas", label: "Islas" }, { id: "clasica", label: "Clásica" }, { id: "compacta", label: "Compacta" }] },
        { cat: "apariencia", key: "letraCalidad", label: "Calidad de la letra",
          hint: "CPU con la letra a la vista: Calidad ~32 %, Equilibrado ~20 %, Bajo ~14 % (como con la cola).",
          fallback: "equilibrado", options: [{ id: "calidad", label: "Calidad" }, { id: "equilibrado", label: "Equilibrado" }, { id: "bajo", label: "Bajo" }] },
        { cat: "apariencia", key: "letraOrigen", label: "Origen de la letra",
          hint: "Automática elige la que trae el tiempo de cada palabra y la duración de la canción. NetEase y Kugou tienen mucho anime. En cada canción se cambia pulsando su nombre, bajo la letra.",
          fallback: "auto", options: [{ id: "auto", label: "Automática" }, { id: "lrclib", label: "LRCLIB" }, { id: "netease", label: "NetEase" }, { id: "kugou", label: "Kugou" }] },
        { cat: "apariencia", key: "letraSinTiempos", label: "Letra sin tiempo por palabra",
          hint: "Cuando la fuente solo da el tiempo de cada línea: iluminarla entera, o estimar el barrido (puede no encajar con la voz).",
          fallback: "linea", options: [{ id: "linea", label: "Línea entera" }, { id: "estimado", label: "Estimado" }] },
        { cat: "apariencia", key: "letraTamano", label: "Tamaño de la letra", hint: "El retraso se ajusta en cada canción, bajo su letra.", fallback: "mediana",
          options: [{ id: "pequena", label: "Pequeña" }, { id: "mediana", label: "Mediana" }, { id: "grande", label: "Grande" }, { id: "enorme", label: "Enorme" }] },
        { cat: "apariencia", key: "letraFuente", label: "Fuente de la letra", fallback: "sistema",
          options: [{ id: "sistema", label: "Sistema" }, { id: "serif", label: "Serif" }, { id: "mono", label: "Mono" }] },
        { cat: "apariencia", key: "letraPeso", label: "Grosor de la letra", fallback: "negrita",
          options: [{ id: "negrita", label: "Negrita" }, { id: "normal", label: "Normal" }] },
        { cat: "apariencia", key: "letraAlineacion", label: "Alineación de la letra", fallback: "centro",
          options: [{ id: "centro", label: "Centrada" }, { id: "izquierda", label: "A la izquierda" }] },
        { cat: "vistas", key: "panel", label: "Panel de letra y cola", fallback: "derecha",
          options: [{ id: "izquierda", label: "Izquierda" }, { id: "derecha", label: "Derecha" }] },
        { cat: "vistas", key: "sonando", label: "Pantalla Sonando", hint: "Grande: carátula sola y letra estrecha. Clásica: con el título y letra ancha.", fallback: "grande",
          options: [{ id: "grande", label: "Grande" }, { id: "clasica", label: "Clásica" }] },
        { cat: "vistas", key: "sonandoTitulo", label: "Título en Sonando", hint: "Título y artista bajo la carátula. Automático: solo en la Clásica.", fallback: "auto",
          options: [{ id: "auto", label: "Automático" }, { id: "si", label: "Siempre" }, { id: "no", label: "Nunca" }] },
        { cat: "vistas", key: "explorarFuente", label: "Fuente de Explorar",
          hint: "ListenBrainz: tus listas semanales y recomendaciones (conecta tu cuenta en Plugins). YouTube Music: novedades, listas de éxitos y ánimos.",
          fallback: "listenbrainz", options: [{ id: "listenbrainz", label: "ListenBrainz" }, { id: "youtube", label: "YouTube Music" }] },
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

    // Encabezado con dos botones a la derecha: abrir la carpeta del usuario y recargar.
    component FolderHeading: Item {
        id: folderHeading
        property string text
        property string what
        signal openFolder()

        width: parent ? parent.width : 0
        height: Theme.hit

        Heading {
            anchors.verticalCenter: parent.verticalCenter
            text: folderHeading.text
            font.pixelSize: 12
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            IconButton {
                icon: Theme.iconFolder
                label: "Abrir la carpeta de " + folderHeading.what
                solid: true
                onClicked: folderHeading.openFolder()
            }

            IconButton {
                icon: Theme.iconReload
                label: "Recargar " + folderHeading.what
                solid: true
                onClicked: AppSettings.recargarSkins()
            }
        }
    }

    // Aro de la tarjeta elegida (o con el foco), separado de ella por un hueco.
    component ChosenRing: Rectangle {
        property Item target
        x: target.x - 5
        y: target.y - 5
        width: target.width + 10
        height: target.height + 10
        radius: (target.radius || 12) + 5
        color: "transparent"
        border.width: 2
        border.color: Theme.text
    }

    // Miniatura de una skin con sus propios colores: barra de arriba, cuatro carátulas (la
    // primera, enfocada) y la barra de reproducción con su acento. Las de carpeta con fondo
    // lo muestran detrás.
    component SkinPreview: Rectangle {
        id: preview
        property var skin: ({})
        property bool hovered: false

        readonly property var colors: skin.colores || {}
        readonly property color ink: colors.textoSecundario || "#BDFFFFFF"
        readonly property real unit: width / 225
        readonly property real round: (skin.radio !== undefined ? skin.radio : 20) * unit
        function tone(alpha) {
            return Qt.tint(color, Qt.rgba(ink.r, ink.g, ink.b, alpha))
        }

        radius: 12
        color: colors.fondo || "#0A0C11"
        border.width: 1
        border.color: hovered ? Theme.textFaint : (colors.bordeVidrio || Theme.glassBorder)
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: 1
            visible: source !== ""
            source: preview.skin.imagen || ""
            sourceSize.width: 2 * width
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.6
        }

        Rectangle {
            x: parent.width * 0.07
            y: parent.height * 0.1
            width: parent.width * 0.37
            height: parent.height * 0.09
            radius: Math.min(height / 2, preview.round * 0.45)
            color: preview.tone(0.25)
        }

        Row {
            x: parent.width * 0.07
            y: parent.height * 0.34
            spacing: parent.width * 0.035

            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    width: preview.height * 0.27
                    height: width
                    radius: preview.round * 0.3
                    color: preview.tone(index === 0 ? 0.36 : 0.2)
                }
            }
        }

        Rectangle {
            x: parent.width * 0.07
            y: parent.height * 0.76
            width: parent.width * 0.86
            height: parent.height * 0.14
            radius: Math.min(height / 2, preview.round * 0.45)
            color: preview.tone(0.14)

            Rectangle {
                x: parent.width * 0.03
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.33
                height: Math.max(2, parent.height * 0.17)
                radius: height / 2
                color: preview.colors.acento || Theme.accent
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.03, 0.05, 0.55)
    }

    // La rueda no llega al escenario: la lista de opciones la usa si puede desplazarse y, si no
    // (al llegar al final, o fuera de ella), se queda aquí. Sin esto se desplazaba la sección de
    // debajo.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => wheel.accepted = true
    }

    // Un toque fuera de la hoja la cierra. Con agarre exclusivo (`ReleaseWithinBounds`) y todos
    // los botones: con el agarre pasivo de un `TapHandler` normal, el clic seguía hasta las
    // tarjetas de debajo (TRAMPAS, «Clics que atraviesan»). Lo de la hoja va antes con sus
    // propios gestores.
    TapHandler {
        acceptedButtons: Qt.AllButtons
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint, button) => {
            if (button !== Qt.LeftButton)
                return
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
            // Margen de 6 px a cada lado: el aro de la tarjeta elegida asoma de ella sin cortarse.
            x: sidebar.x + sidebar.width + 34
            anchors.top: sidebar.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: parent.width - x - 26
            contentWidth: width
            contentHeight: content.implicitHeight + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            x: 6
            y: 6
            width: settingsFlick.width - 12
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
                spacing: 16

                readonly property var skins: Catalog.parse(AppSettings.skins)
                readonly property var chosenSkin: skins.find(skin => skin.id === AppSettings.skin) || skins[0] || null

                FolderHeading {
                    text: "Skin"
                    what: "skins"
                    onOpenFolder: Qt.openUrlExternally("file://" + encodeURI(AppSettings.carpetaSkins()))
                }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 16
                    rowSpacing: 20

                    Repeater {
                        model: skinSection.skins

                        Item {
                            id: skinCard
                            required property var modelData
                            readonly property bool chosen: AppSettings.skin === modelData.id

                            width: (skinSection.width - 3 * 16) / 4
                            height: preview.height + 10 + skinName.implicitHeight
                            activeFocusOnTab: true

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: "Skin " + modelData.nombre
                            Accessible.checked: chosen
                            Accessible.onPressAction: AppSettings.elegirSkin(modelData.id)
                            Keys.onReturnPressed: AppSettings.elegirSkin(modelData.id)
                            Keys.onSpacePressed: AppSettings.elegirSkin(modelData.id)

                            SkinPreview {
                                id: preview
                                width: parent.width
                                height: Math.round(width * 0.57)
                                skin: skinCard.modelData
                                hovered: skinHover.hovered
                            }

                            ChosenRing {
                                target: preview
                                visible: skinCard.chosen || skinCard.activeFocus
                            }

                            Text {
                                id: skinName
                                anchors.top: preview.bottom
                                anchors.topMargin: 10
                                x: 4
                                width: parent.width - 4
                                text: skinCard.modelData.nombre
                                color: Theme.text
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            HoverHandler {
                                id: skinHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: AppSettings.elegirSkin(skinCard.modelData.id)
                            }
                        }
                    }
                }

                // Descripción de la elegida: «Vidrio: paneles translúcidos…».
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: {
                        const skin = skinSection.chosenSkin
                        if (!skin || !skin.descripcion)
                            return ""
                        return skin.nombre + ": " + skin.descripcion.charAt(0).toLowerCase() + skin.descripcion.slice(1)
                    }
                    color: Theme.textMuted
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
            }

            // Mascotas: aparte de las skins, para combinarlas como se quiera. Cada una se ve con
            // su pose de reposo; «Añadir…» abre su carpeta.
            Column {
                visible: root.category === "apariencia"
                id: mascotSection
                width: parent.width
                spacing: 16

                readonly property var mascots: [{ id: "", nombre: "Ninguna", imagen: "" }]
                    .concat(Catalog.parse(AppSettings.mascotas))
                readonly property real tileWidth: 104
                readonly property real tileHeight: 78

                function openFolder() {
                    Qt.openUrlExternally("file://" + encodeURI(AppSettings.carpetaMascotas()))
                }

                FolderHeading {
                    text: "Mascota"
                    what: "mascotas"
                    onOpenFolder: mascotSection.openFolder()
                }

                Flow {
                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: mascotSection.mascots

                        Item {
                            id: mascotCard
                            required property var modelData
                            readonly property bool chosen: AppSettings.mascota === modelData.id

                            width: mascotSection.tileWidth
                            height: tile.height + 10 + mascotName.implicitHeight
                            activeFocusOnTab: true

                            Accessible.role: Accessible.RadioButton
                            Accessible.name: "Mascota " + modelData.nombre
                            Accessible.description: modelData.descripcion || ""
                            Accessible.checked: chosen
                            Accessible.onPressAction: AppSettings.elegirMascota(modelData.id)
                            Keys.onReturnPressed: AppSettings.elegirMascota(modelData.id)
                            Keys.onSpacePressed: AppSettings.elegirMascota(modelData.id)

                            Rectangle {
                                id: tile
                                width: parent.width
                                height: mascotSection.tileHeight
                                radius: 14
                                color: mascotHover.hovered ? Theme.controlActive : Theme.control
                                border.width: 1
                                border.color: Theme.glassBorder

                                // Pose de reposo, reducida al recuadro (se decodifica a ese tamaño).
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    visible: source !== ""
                                    source: mascotCard.modelData.imagen || ""
                                    sourceSize.height: 2 * height
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                }
                            }

                            ChosenRing {
                                target: tile
                                visible: mascotCard.chosen || mascotCard.activeFocus
                            }

                            Text {
                                id: mascotName
                                anchors.top: tile.bottom
                                anchors.topMargin: 10
                                x: 4
                                width: parent.width - 4
                                text: mascotCard.modelData.nombre
                                color: Theme.text
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
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

                    // Añadir una: abre la carpeta de mascotas (una carpeta con mascota.json y
                    // sus PNG; el formato está en el README).
                    Item {
                        id: addMascot
                        width: mascotSection.tileWidth
                        height: addTile.height + 10 + addName.implicitHeight
                        activeFocusOnTab: true

                        Accessible.role: Accessible.Button
                        Accessible.name: "Añadir una mascota: abre la carpeta de mascotas"
                        Accessible.onPressAction: mascotSection.openFolder()
                        Keys.onReturnPressed: mascotSection.openFolder()
                        Keys.onSpacePressed: mascotSection.openFolder()

                        Item {
                            id: addTile
                            width: parent.width
                            height: mascotSection.tileHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: addHover.hovered ? Theme.control : "transparent"
                                border.width: addMascot.activeFocus ? 2 : 0
                                border.color: Theme.text
                            }

                            Shape {
                                anchors.fill: parent

                                ShapePath {
                                    strokeColor: Theme.textFaint
                                    strokeWidth: 1.5
                                    strokeStyle: ShapePath.DashLine
                                    dashPattern: [3, 3]
                                    fillColor: "transparent"
                                    PathRectangle {
                                        x: 1
                                        y: 1
                                        width: addTile.width - 2
                                        height: addTile.height - 2
                                        radius: 13
                                    }
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                path: Theme.iconPlus
                                size: 22
                                color: Theme.textMuted
                            }
                        }

                        Text {
                            id: addName
                            anchors.top: addTile.bottom
                            anchors.topMargin: 10
                            x: 4
                            text: "Añadir…"
                            color: Theme.textMuted
                            font.pixelSize: 15
                        }

                        HoverHandler {
                            id: addHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: mascotSection.openFolder()
                        }
                    }
                }
            }

            // Filas de opciones sueltas de la categoría elegida (ver `optionRows`).
            Column {
                readonly property var rows: root.optionRows.filter(row => row.cat === root.category)
                readonly property var headings: ({ reproduccion: "Audio", apariencia: "Aspecto", vistas: "Disposición" })

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

                Toggle {
                    label: "ListenBrainz"
                    hint: Plugins.listenbrainzUser !== "" ? "Conectado como " + Plugins.listenbrainzUser + "."
                                                          : "Tus escuchas dan forma a Explorar."
                    on: Plugins.listenbrainzOn
                    onChanged: on => {
                        if (on && Plugins.listenbrainzUser === "")
                            listenbrainzSetup.visible = true
                        else
                            Plugins.setListenbrainz(on)
                    }
                }

                Column {
                    id: listenbrainzSetup
                    visible: false
                    width: parent.width
                    spacing: 8

                    Status {
                        text: "Crea una cuenta gratis en listenbrainz.org, copia tu token de listenbrainz.org/settings y pégalo aquí. Tu historial de Last.fm se puede importar desde su web."
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        TextField {
                            id: listenbrainzToken
                            width: parent.width - listenbrainzConnect.width - 8
                            secret: true
                            placeholder: "Token de ListenBrainz"
                            onCommitted: text => Plugins.listenbrainzConnect(text)
                        }

                        PillButton {
                            id: listenbrainzConnect
                            text: "Conectar"
                            primary: true
                            onClicked: Plugins.listenbrainzConnect(listenbrainzToken.text)
                        }
                    }

                    Connections {
                        target: Plugins
                        function onListenbrainzUserChanged() {
                            if (Plugins.listenbrainzUser !== "") {
                                listenbrainzSetup.visible = false
                                listenbrainzToken.text = ""
                            }
                        }
                    }
                }

                Status { text: Plugins.listenbrainzStatus }

                PillButton {
                    visible: Plugins.listenbrainzUser !== ""
                    text: "Desconectar ListenBrainz"
                    onClicked: Plugins.listenbrainzDisconnect()
                }
            }
        }
        }
    }
}
