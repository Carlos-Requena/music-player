import QtQuick
import QtQuick.Effects
import app.musicplayer

// Letra al estilo de Better Lyrics (la extensión para YouTube Music):
//
// - La línea que suena va entera y brillante, a un 37 % de la altura; las demás, al 30 % de
//   opacidad y al 95 % de tamaño. Pinchar una línea salta a ese momento.
// - Al cambiar de línea, cada una se desplaza por su cuenta con una curva rápida en medio y
//   suave en los extremos; las de abajo llegan algo después (efecto cascada). El desplazamiento
//   empieza medio segundo antes de que se cante la línea, para que llegue a su sitio a tiempo.
// - Las palabras se rellenan con un barrido de izquierda a derecha y se elevan un poco al
//   cantarse; la línea activa lleva un brillo suave que se apaga poco a poco. El barrido sigue
//   el tiempo real de cada palabra o sílaba (NetEase y Kugou lo dan casi siempre). Si la letra
//   solo trae el de la línea, se ilumina entera de golpe; con `letraSinTiempos: estimado`, el
//   barrido se estima repartiendo la línea (ver `timing`).
// - Las pausas instrumentales (líneas vacías del LRC, o una intro larga) son tres puntos que se
//   encienden a medida que pasa la pausa.
//
// Tres modos (Opciones › Apariencia › Calidad de la letra), porque cada fotograma redibuja la
// ventana entera con su vidrio desenfocado y eso es lo que cuesta CPU:
//
//   calidad      barrido a 60 Hz (aunque la pantalla vaya a 120), cascada, brillo y palabras que
//                se elevan con suavidad. (Se probó además dibujar el texto con curvas,
//                `Text.CurveRendering`: ~95 MB más para una nitidez que apenas se nota.)
//   equilibrado  barrido a 30 Hz, cascada y brillo; el resto, al instante. (Por defecto.)
//   bajo         sin barrido suave (diez pasos por segundo, los de mpv), un único desplazamiento
//                corto en vez de la cascada, sin brillo y sin encoger las otras líneas.
//
// En todos el texto se dibuja directamente (el brillo es una copia desenfocada detrás, no un
// efecto sobre el propio texto) y en píxeles enteros, para que no se vea borroso.
Item {
    id: root

    // Tamaño base; Opciones › Apariencia lo escala.
    property real baseSize: 24
    readonly property real fontSize: Math.round(baseSize * Theme.lyricsScale)
    // Mide las palabras a tamaño completo, para encoger las que no caben en una línea.
    FontMetrics {
        id: metrics
        font.pixelSize: root.fontSize
        font.family: Theme.lyricsFamily
        font.weight: Theme.lyricsWeight
        font.letterSpacing: 0
    }
    // Momento de la letra: la posición corregida con el retraso de esta canción.
    property real position: Catalog.lyricsTime
    // Muestra abajo el ajuste de retraso (adelantar/atrasar la letra de esta canción).
    property bool showTiming: true
    // Cada renglón centrado en la zona de la letra (opción `letraAlineacion`, por defecto) o
    // pegado a la izquierda.
    readonly property bool centered: { void AppSettings.revision; return AppSettings.opcion("letraAlineacion") !== "izquierda" }
    // Altura (0 arriba, 1 abajo) donde queda la línea que suena: centrada también en vertical
    // (lo pidió el propietario) o, a la izquierda, al 37 % como Better Lyrics.
    property real anchorRatio: centered ? 0.5 : 0.37

    readonly property var lines: Catalog.lyrics

    // Líneas sin tiempo por palabra: entera de golpe (por defecto) o barrido estimado.
    readonly property bool estimate: { void AppSettings.revision; return AppSettings.opcion("letraSinTiempos") === "estimado" }
    // Japonés, chino y coreano: no separan las palabras con espacios y se puede partir el
    // renglón entre dos caracteres cualesquiera.
    readonly property var cjk: /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af\uff66-\uff9f]/

    // Palabras de la línea `i` con su comienzo y su final en segundos, y `join` si van pegadas
    // a la siguiente (sílabas de una palabra, o japonés y chino).
    function timing(i) {
        const line = lines[i]
        if (!line || line.text === "")
            return []
        const next = i + 1 < lines.length ? lines[i + 1].t : line.t + 6
        const timed = line.w || []
        if (timed.length > 0)
            return timed.map((w, k) => ({
                text: w.text, join: !!w.join, start: w.t,
                end: w.d > 0 ? w.t + w.d : k + 1 < timed.length ? timed[k + 1].t : Math.min(next, w.t + 1.5)
            }))

        // Sin tiempos: palabras separadas por espacios y, en japonés y chino, cada carácter
        // (pegado al siguiente). `units` pesa lo que se tarda en cantarlo: un carácter de
        // japonés o chino es una sílaba o más; uno latino, mucho menos.
        const parts = []
        for (const piece of line.text.split(/\s+/)) {
            if (piece === "")
                continue
            let run = ""
            for (const c of piece) {
                if (!cjk.test(c)) {
                    run += c
                    continue
                }
                if (run !== "")
                    parts.push({ text: run, join: true, units: run.length })
                run = ""
                parts.push({ text: c, join: true, units: 3 })
            }
            if (run !== "")
                parts.push({ text: run, join: true, units: run.length + 1 })
            parts[parts.length - 1].join = false
        }
        // Entera de golpe: todas empiezan y acaban con la línea.
        if (!estimate)
            return parts.map(p => ({ text: p.text, join: p.join, start: line.t, end: line.t }))
        // Estimado: repartido por toda la línea, hasta la siguiente (sin pasar de 0,2 s por
        // unidad, por si detrás viene un solo instrumental sin pausa marcada).
        const units = parts.reduce((sum, p) => sum + p.units, 0)
        const total = Math.min(0.92 * (next - line.t), Math.max(1.0, units * 0.2))
        let at = line.t
        return parts.map(p => {
            const length = total * p.units / units
            const word = { text: p.text, join: p.join, start: at, end: at + length }
            at += length
            return word
        })
    }
    // Modo de la letra (ver arriba). La opción vieja «letraAnimada: ligera» equivale a «bajo».
    readonly property string mode: {
        void AppSettings.revision
        const chosen = AppSettings.opcion("letraCalidad")
        if (chosen === "calidad" || chosen === "bajo")
            return chosen
        return chosen === "" && AppSettings.opcion("letraAnimada") === "ligera" ? "bajo" : "equilibrado"
    }
    readonly property bool quality: mode === "calidad"
    readonly property bool low: mode === "bajo"
    // Línea iluminada (con una pizca de adelanto, como Better Lyrics) y línea a la que se
    // desplaza la vista (medio segundo antes, para que llegue cuando empieza).
    readonly property int current: lines.length ? Catalog.lineAt(position + 0.1) : -1
    readonly property int scrollLine: lines.length ? Catalog.lineAt(position + 0.5) : -1

    // mpv da la posición diez veces por segundo; para que el barrido de las palabras sea suave,
    // un reloj propio avanza entre una y otra (a 60 Hz en «calidad», a 30 Hz en «equilibrado»).
    // Solo mientras se está cantando la línea activa (o dura su brillo) y se ve: en las pausas o
    // con la línea ya entera y apagada se queda en los diez pasos por segundo de mpv.
    property real smooth: 0
    readonly property bool ticking: !low && visible && Player.playing && position < Math.max(fillEnd, glowEnd)
    readonly property real clock: ticking ? smooth : position
    onPositionChanged: {
        if (!ticking || Math.abs(position - smooth) > 0.35)
            smooth = position
    }
    function advance(seconds) {
        smooth = Math.min(smooth + seconds, position + 0.15)
    }
    // Hasta cuándo dura el barrido de la línea activa (con la línea entera de golpe, nada: el
    // reloj propio no llega a ponerse en marcha).
    readonly property real fillEnd: {
        const words = timing(current)
        return words.length ? words.reduce((last, w) => Math.max(last, w.end), 0) + 0.3 : -1
    }
    // El brillo de la línea activa también sigue a este reloj (ver `glow`): mientras dura, el
    // reloj propio sigue en marcha aunque la línea ya esté entera.
    readonly property real glowSeconds: 1.6
    readonly property real glowEnd: !low && Theme.blur && current >= 0 && lines[current].text !== ""
        ? lines[current].t + glowSeconds : -1
    // «Calidad»: con los fotogramas de la pantalla, pero 60 veces por segundo como mucho. En una
    // pantalla de 120 Hz (ProMotion) los fotogramas de en medio no cambian nada y Qt no redibuja.
    FrameAnimation {
        property real pending: 0
        running: root.ticking && root.quality
        onRunningChanged: pending = 0
        onTriggered: {
            pending += frameTime
            if (pending >= 1 / 60 - 0.002) {
                root.advance(pending)
                pending = 0
            }
        }
    }
    // «Equilibrado»: a 30 Hz.
    Timer {
        property double last: 0
        interval: 33
        repeat: true
        running: root.ticking && !root.quality
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now()
            root.advance((now - last) / 1000)
            last = now
        }
    }

    clip: true

    Text {
        visible: root.lines.length === 0 && Player.title !== ""
        width: parent.width
        horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
        text: "Sin letra sincronizada para esta canción."
        color: Theme.textFaint
        font.pixelSize: 15
        wrapMode: Text.WordWrap
    }

    // Deja sitio abajo para el ajuste de retraso.
    readonly property real timingHeight: showTiming && lines.length ? Theme.hit + 8 : 0

    // Coloca la línea de `scrollLine` a su altura. Con `animated`, cada línea recorre la
    // distancia con su propia duración (ver `slideFrom`).
    function place(animated) {
        const at = repeater.itemAt(Math.max(0, scrollLine))
        if (!at)
            return
        // Nunca deja hueco arriba: al empezar la canción la letra llena la zona desde arriba y la
        // línea que suena baja hasta su altura; desde ahí se queda fija y la letra sube.
        const target = Math.min(0, Math.round((height - timingHeight) * anchorRatio - at.y - at.height / 2))
        columnAnim.stop()
        // «Bajo»: un único desplazamiento corto de toda la columna.
        if (animated && low && Math.abs(column.y - target) >= 1) {
            columnAnim.to = target
            columnAnim.start()
            return
        }
        const delta = column.y - target
        column.y = target
        if (!animated || low || Math.abs(delta) < 1)
            return
        for (let i = 0; i < repeater.count; ++i) {
            const line = repeater.itemAt(i)
            if (line && line.near)
                line.slideFrom(delta, i - Math.max(0, scrollLine))
        }
    }
    onScrollLineChanged: place(true)
    onHeightChanged: Qt.callLater(place, false)
    onWidthChanged: Qt.callLater(place, false)
    onFontSizeChanged: Qt.callLater(place, false)
    onAnchorRatioChanged: Qt.callLater(place, false)
    onLinesChanged: Qt.callLater(place, false)

    // Ratón: un solo gestor de clic para toda la letra, que averigua la línea pinchada, y sin
    // seguir el puntero (nada de HoverHandler): mientras la letra se mueve bajo el puntero, Qt
    // repasa la escena en cada fotograma para el «hover» y la letra pasaba de ~5 % a ~25 % de
    // CPU. La mano del cursor la pone un `MouseArea` que no escucha el «hover».
    function lineUnder(point) {
        const local = column.mapFromItem(root, point.x, point.y)
        const item = column.childAt(local.x, local.y)
        return item && item.modelData !== undefined && !item.gap && item.near ? item.index : -1
    }
    // Pinchar una línea salta a ese momento de la canción.
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: eventPoint => {
            const at = root.lineUnder(eventPoint.position)
            if (at >= 0)
                Player.seek(root.lines[at].t + Catalog.lyricsDelay)
        }
    }

    NumberAnimation {
        id: columnAnim
        target: column
        property: "y"
        duration: 320
        easing.type: Easing.OutCubic
    }

    // La letra termina encima del pie de retraso: sin este recorte, las líneas de abajo se
    // dibujaban sobre él.
    Item {
        id: viewport
        width: parent.width
        height: parent.height - root.timingHeight
        clip: root.timingHeight > 0

        Column {
            id: column
            width: parent.width

            Repeater {
                id: repeater
                model: root.lines
                onItemAdded: Qt.callLater(root.place, false)

                Item {
                    id: line
                    required property var modelData
                    required property int index

                    readonly property bool gap: modelData.text === ""
                    readonly property real start: modelData.t
                    readonly property real end: index + 1 < root.lines.length ? root.lines[index + 1].t : start + 6
                    readonly property int distance: index - root.current
                    readonly property bool active: distance === 0
                    // Solo se dibujan (y se animan) las cercanas; el resto ocupa su sitio sin pintarse.
                    readonly property bool near: index >= root.scrollLine - 8 && index <= root.scrollLine + 12
                    // Pausas cortas: no merece la pena dibujarlas.
                    readonly property bool gapShown: gap && end - start >= 2.5

                    // Palabras con su comienzo y su final, en segundos.
                    readonly property var words: gap ? [] : root.timing(index)

                    // Las palabras repartidas en renglones según su ancho (lo que hacía un `Flow`, que
                    // no sabe centrar cada renglón). Las sílabas de una palabra no se separan; en
                    // japonés y chino, que no usan espacios, se parte entre dos caracteres
                    // cualesquiera. Una palabra más ancha que la línea va sola y se encoge (`fit`,
                    // abajo). Cada palabra lleva `gap` si detrás va un espacio.
                    readonly property var rows: {
                        void (root.fontSize, Theme.lyricsFamily, Theme.lyricsWeight)
                        const room = column.width * 0.98
                        const gapWidth = root.fontSize * 0.27
                        const chunks = []
                        for (let k = 0; k < words.length; ++k) {
                            const w = words[k]
                            const prev = k > 0 ? words[k - 1] : null
                            const together = prev && prev.join
                                && !root.cjk.test(prev.text.slice(-1)) && !root.cjk.test(w.text.charAt(0))
                            if (!together)
                                chunks.push({ words: [], width: 0, spaced: !prev || !prev.join })
                            const chunk = chunks[chunks.length - 1]
                            chunk.words.push(w)
                            chunk.width += Math.min(room, metrics.advanceWidth(w.text) - 0.3 * w.text.length)
                        }
                        const out = []
                        let row = []
                        let used = 0
                        for (const chunk of chunks) {
                            const gapBefore = row.length && chunk.spaced ? gapWidth : 0
                            if (row.length && used + gapBefore + chunk.width > room) {
                                out.push(row)
                                row = []
                                used = 0
                            } else if (gapBefore > 0) {
                                row[row.length - 1].gap = true
                                used += gapBefore
                            }
                            for (const w of chunk.words)
                                row.push({ text: w.text, start: w.start, end: w.end, gap: false })
                            used += chunk.width
                        }
                        if (row.length)
                            out.push(row)
                        return out
                    }

                    width: column.width
                    height: gap ? (gapShown ? root.fontSize * 1.5 : 0) : body.height + root.fontSize * 0.6
                    // Ocultar con `visible` sacaría la línea del `Column` y movería las demás: las
                    // lejanas solo dejan de pintarse (opacidad 0 no se dibuja).
                    visible: !gap || gapShown

                    opacity: !near ? 0 : active ? 1 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    transform: Translate { id: slide }

                    // Recorre `delta` píxeles hasta su sitio. Más lejos de la línea activa, más tarda:
                    // las de abajo llegan en cascada, las de arriba casi a la vez.
                    function slideFrom(delta, n) {
                        slideAnim.stop()
                        slide.y += delta
                        slideAnim.duration = n >= 0 ? 750 + Math.log(n + 1) * 80 + n * 20
                                                    : 750 + Math.log(1 - n) * 10
                        slideAnim.start()
                    }
                    NumberAnimation {
                        id: slideAnim
                        target: slide
                        property: "y"
                        to: 0
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.86, 0, 0.2, 1, 1, 1]
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: line.gap ? "" : modelData.text
                    Accessible.ignored: line.gap
                    Accessible.onPressAction: Player.seek(line.start + Catalog.lyricsDelay)

                    // ---- Brillo de la línea activa ----
                    // Una copia desenfocada detrás del texto: fuerte al empezar la línea y apagada en
                    // 1,6 s, como en Better Lyrics. Detrás y no como efecto del propio texto: así el
                    // texto se dibuja directo y nítido. Apagado, el efecto se quita.
                    //
                    // Desenfoca una instantánea de la línea (`live: false`), no la línea viva: con
                    // ella viva, cada paso del barrido volvía a copiar y desenfocar la línea entera.
                    // La instantánea se rehace al encenderse la línea y cada vez que empieza a
                    // iluminarse una palabra (`litWords`); detrás del texto y desenfocada, la
                    // diferencia con el barrido exacto no se ve.
                    readonly property bool glowOn: !root.low && line.active && Theme.blur && body.glow > 0.01
                    readonly property int litWords: glowOn ? words.reduce((n, w) => n + (root.clock >= w.start ? 1 : 0), 0) : 0
                    onLitWordsChanged: if (glowOn) glowSource.scheduleUpdate()
                    onGlowOnChanged: if (glowOn) glowSource.scheduleUpdate()

                    ShaderEffectSource {
                        id: glowSource
                        visible: false
                        width: body.width
                        height: body.height
                        sourceItem: line.glowOn ? body : null
                        live: false
                    }

                    MultiEffect {
                        visible: line.glowOn
                        source: visible ? glowSource : null
                        x: body.x
                        y: body.y
                        width: body.width
                        height: body.height
                        blurEnabled: true
                        blur: 1
                        blurMax: 24
                        opacity: body.glow
                    }

                    // ---- Línea con texto ----
                    Column {
                        id: body
                        visible: !line.gap
                        width: parent.width

                        // Las inactivas, algo más pequeñas (desde donde se alinea el texto). En
                        // «bajo», no: el texto escalado queda algo menos nítido.
                        transform: Scale {
                            origin.x: root.centered ? body.width / 2 : 0
                            origin.y: body.height / 2
                            xScale: line.active || root.low ? 1 : 0.95
                            yScale: xScale
                            Behavior on xScale { NumberAnimation { duration: 166; easing.type: Easing.InOutQuad } }
                        }

                        // Intensidad del brillo: de 0,9 a 0 en `glowSeconds` desde que empieza la
                        // línea, con la curva de antes (OutQuad). Sale del reloj de la letra y no de
                        // una animación propia: así no añade fotogramas a la frecuencia de la
                        // pantalla (en «Equilibrado», 30 por segundo como el barrido).
                        readonly property real glow: {
                            if (!line.active || root.low)
                                return 0
                            const t = (root.clock - line.start) / root.glowSeconds
                            return t < 0 || t >= 1 ? 0 : 0.9 * (1 - t) * (1 - t)
                        }

                        Repeater {
                            model: line.rows

                            Row {
                                required property var modelData
                                anchors.horizontalCenter: root.centered ? parent.horizontalCenter : undefined

                                Repeater {
                                    model: parent.modelData

                                    Item {
                                        id: word
                                        required property var modelData

                                        // Parte rellena (0–1). El barrido empieza un poco antes de la palabra
                                        // y dura algo más que ella, como en Better Lyrics. Fuera de la línea
                                        // activa, entera.
                                        readonly property real fill: {
                                            if (!line.active)
                                                return 1
                                            const d = Math.max(0.05, modelData.end - modelData.start)
                                            return Math.max(0, Math.min(1, (root.clock - modelData.start + 0.1 * d) / (1.2 * d)))
                                        }
                                        // Se eleva mientras se canta y queda apenas levantada después.
                                        // En píxeles enteros: medio píxel deja el texto borroso.
                                        readonly property real lift: !line.active || fill <= 0 ? 0
                                            : Math.round((fill < 1 ? -0.05 : -0.02) * root.fontSize)

                                        // El espacio detrás de la palabra, si lo lleva, va dentro de su ancho.
                                        width: dim.implicitWidth + (modelData.gap ? root.fontSize * 0.27 : 0)
                                        height: dim.implicitHeight
                                        // Animado solo en «calidad»: cada animación redibuja la ventana a 60 Hz
                                        // y, con una palabra cada pocas décimas, casi no paran.
                                        transform: Translate {
                                            y: word.lift
                                            Behavior on y {
                                                enabled: root.quality
                                                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                                            }
                                        }

                                        // Una sola `Text` por palabra: tenue sin cantar, entera una vez cantada.
                                        // Mientras se barre, encima va la parte cantada recortada. (Recortar
                                        // todas las palabras impedía a Qt dibujar el texto por lotes y la
                                        // letra gastaba diez veces más CPU.)
                                        // Una palabra más ancha que la línea (en un recuadro estrecho) se encoge
                                        // hasta caber en vez de salirse. Su ancho a tamaño completo lo da la
                                        // `FontMetrics` común (los nombres de la fuente, para medir otra vez si
                                        // cambia).
                                        readonly property real natural: (root.fontSize, Theme.lyricsFamily, Theme.lyricsWeight,
                                            metrics.advanceWidth(modelData.text) - 0.3 * modelData.text.length)
                                        readonly property real fit: natural > body.width && body.width > 0 ? body.width / natural : 1

                                        Text {
                                            id: dim
                                            text: word.modelData.text
                                            color: word.fill >= 1 ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
                                            font.pixelSize: Math.max(8, Math.floor(root.fontSize * word.fit))
                                            font.family: Theme.lyricsFamily
                                            font.weight: Theme.lyricsWeight
                                            font.letterSpacing: -0.3
                                        }

                                        Loader {
                                            active: word.fill > 0 && word.fill < 1
                                            sourceComponent: Item {
                                                // Borde del barrido: una franja a media luz delante de lo cantado.
                                                Item {
                                                    width: Math.min(dim.width, word.fill * dim.width + 0.12 * dim.width)
                                                    height: word.height
                                                    clip: true
                                                    Text {
                                                        text: dim.text
                                                        font: dim.font
                                                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
                                                    }
                                                }
                                                // Cantado: brillante.
                                                Item {
                                                    width: word.fill * dim.width
                                                    height: word.height
                                                    clip: true
                                                    Text {
                                                        text: dim.text
                                                        font: dim.font
                                                        color: Theme.text
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Pausa instrumental: tres puntos que se encienden con el tiempo ----
                    Row {
                        id: dots
                        visible: line.gapShown
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.centered ? (parent.width - width) / 2 : root.fontSize * 0.1
                        spacing: root.fontSize * 0.22
                        transformOrigin: root.centered ? Item.Center : Item.Left

                        readonly property real progress: line.active
                            ? Math.max(0, Math.min(1, (root.clock - line.start) / Math.max(0.1, line.end - line.start)))
                            : 0

                        Repeater {
                            model: 3

                            Rectangle {
                                required property int index
                                width: root.fontSize * 0.3
                                height: width
                                radius: width / 2
                                color: Theme.text
                                opacity: 0.35 + 0.65 * Math.max(0, Math.min(1, dots.progress * 3 - index))
                            }
                        }

                        // Respira mientras dura la pausa (2,5 s por respiración). Sale de la posición
                        // de la canción, diez pasos por segundo: tan lento, no se ve a saltos y no
                        // redibuja la ventana a la frecuencia de la pantalla durante toda la pausa.
                        // En «bajo», quietos.
                        scale: line.active && line.gapShown && !root.low
                            ? 1 + 0.075 * (1 - Math.cos(2 * Math.PI * Math.max(0, root.clock - line.start) / 2.5))
                            : 1
                    }
                }
            }
        }

    }

    // Ajuste de retraso de la letra de esta canción.
    LyricsTiming {
        visible: root.timingHeight > 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
