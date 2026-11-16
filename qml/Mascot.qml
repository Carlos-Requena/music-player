import QtQuick
import app.musicplayer

// Mascota (Opciones › Mascota): una imagen que cambia de pose según lo que pasa en el
// reproductor y da un saltito al cambiar. Las poses son PNG con transparencia de la carpeta de
// la mascota. De más a menos prioridad:
//
//   reacciones breves (unos segundos; `segundos` en la pose cambia cuánto):
//     clic       al pincharla                                  → nueva
//     megusta    tras `clic`, si el pinchazo dio «Me gusta»     → clic
//     fallo      si el «Me gusta» no se pudo dar                → error
//     enfado     al pincharla 5 veces seguidas                  → clic
//     saltada    al pasar a la siguiente canción                → sonando
//     playlist   al guardar algo en una playlist                → megusta
//   error      si algo falla                                   → cargando
//   cargando   si una pista tarda en arrancar                  → reposo
//   nueva      unos segundos al empezar una pista              → sonando
//   sonando    mientras suena                                  → reposo
//   navegando  sin música, mientras recorres la estantería o abres un álbum → pausa
//   pausa      con una pista en pausa                          → reposo
//   reposo     sin nada sonando (la única obligatoria)
//
// Cada pose es el nombre del PNG o `{ "imagen": "x.png", "alto": 120, "segundos": 2 }` para
// darle su propio alto (p. ej. si una pose es solo la cabeza y otra el busto entero) y, en las
// breves, su duración. Con `"pincharDaMeGusta": true` en `mascota.json`, pincharla mientras
// suena una canción le da «Me gusta».
Item {
    id: root

    readonly property var poses: Theme.mascot ? Theme.mascot.poses : ({})
    readonly property real baseTall: Theme.mascot && Theme.mascot.alto ? Theme.mascot.alto : 160

    // Estados breves.
    property bool fresh: false
    property bool slow: false

    property bool browsing: false

    // Reacción breve en curso ("" = ninguna) y la que viene detrás.
    property string flash: ""
    property string queued: ""

    readonly property bool likes: Theme.mascot ? Theme.mascot.pincharDaMeGusta === true : false
    // Última canción a la que se dio «Me gusta» desde aquí: pincharla otra vez no repite la petición.
    property string likedId: ""
    // Momentos de los últimos pinchazos, para el enfado.
    property var pokes: []

    readonly property string mood: flash !== "" ? flash
        : Player.error !== "" ? "error"
        : slow ? "cargando"
        : fresh && Player.playing ? "nueva"
        : Player.playing ? "sonando"
        : browsing ? "navegando"
        : Player.title !== "" ? "pausa"
        : "reposo"

    readonly property var fallback: ({
        clic: "nueva", megusta: "clic", fallo: "error", enfado: "clic", saltada: "sonando",
        playlist: "megusta", error: "cargando", cargando: "reposo", nueva: "sonando",
        sonando: "reposo", navegando: "pausa", pausa: "reposo"
    })

    // Duración de cada reacción breve si su pose no dice `segundos`.
    readonly property var seconds: ({ clic: 1.5, megusta: 2.5, fallo: 2.5, enfado: 3, saltada: 2.5, playlist: 3 })

    // Muestra la reacción `name` y, al acabar, `then` (si la hay).
    function react(name, then) {
        flash = name
        queued = then || ""
        flashTimer.interval = 1000 * (pose(name).segundos || seconds[name] || 2.5)
        flashTimer.restart()
        hop.restart()
    }
    Timer {
        id: flashTimer
        onTriggered: {
            if (root.queued !== "")
                root.react(root.queued)
            else
                root.flash = ""
        }
    }

    // Pincharla: vergüenza; si suena una canción (y la mascota lo pide), además «Me gusta» y
    // después alegría. Cinco pinchazos en cuatro segundos la enfadan.
    function poke() {
        const now = Date.now()
        pokes = pokes.filter(at => now - at < 4000).concat([now])
        if (pokes.length >= 5) {
            pokes = []
            react("enfado")
            return
        }
        const id = Catalog.currentVideoId
        if (likes && Player.playing && id !== "") {
            if (likedId !== id) {
                likedId = id
                Library.like(id, Player.title, true)
            }
            react("clic", "megusta")
        } else {
            react("clic")
        }
    }

    // La ventana avisa cada vez que el usuario se mueve por el catálogo. Lo que pasa al
    // arrancar (la vista coloca su primer elemento) no cuenta.
    function browsed() {
        if (!settled.running) {
            browsing = true
            browseTimer.restart()
        }
    }
    Timer {
        id: settled
        running: true
        interval: 1500
    }
    Timer {
        id: browseTimer
        interval: 4000
        onTriggered: root.browsing = false
    }

    function pose(mood) {
        let at = mood
        while (at && !poses[at])
            at = fallback[at]
        const entry = poses[at || "reposo"]
        return typeof entry === "string" ? { imagen: entry } : (entry || {})
    }

    readonly property var current: pose(mood)
    readonly property string source: Theme.mascotImage(current.imagen)
    readonly property real tall: current.alto || baseTall
    onSourceChanged: hop.restart()

    implicitWidth: image.status === Image.Ready ? tall * image.implicitWidth / image.implicitHeight : tall
    implicitHeight: tall

    Accessible.role: Accessible.Button
    Accessible.name: likes && Player.playing ? "Mascota: dar «Me gusta» a la canción" : "Mascota"
    Accessible.onPressAction: poke()

    // «Cargando» solo si tarda: las pistas suelen arrancar en décimas y la pose parpadearía.
    Timer {
        running: Player.loading
        interval: 700
        onTriggered: root.slow = true
    }
    Connections {
        target: Player
        function onLoadingChanged() {
            if (!Player.loading)
                root.slow = false
        }
        function onSaltada() {
            root.react("saltada")
        }
        // Pista nueva (el índice no basta: la primera pista no lo cambia).
        function onTitleChanged() {
            if (Player.title === "")
                return
            root.fresh = true
            freshTimer.restart()
        }
    }
    Connections {
        target: Library
        function onGuardado(mensaje, error) {
            if (!error)
                root.react("playlist")
        }
        function onGustado(mensaje, error, videoId, gusta) {
            // Si se quitó el «Me gusta» (desde la barra), pincharla otra vez lo vuelve a dar.
            if (!error) {
                if (!gusta && videoId === root.likedId)
                    root.likedId = ""
                return
            }
            root.likedId = ""
            root.react("fallo")
        }
    }
    Timer {
        id: freshTimer
        interval: 4000
        onTriggered: root.fresh = false
    }
    Image {
        id: image
        width: parent.width
        height: parent.height
        source: root.source
        // Decodificada a su tamaño en pantalla: unas pocas decenas de KB por pose.
        sourceSize.height: root.tall * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        transform: [
            Scale {
                origin.x: image.width / 2
                xScale: Theme.mascot && Theme.mascot.espejo ? -1 : 1
            },
            Translate { id: lift }
        ]
    }

    // Saltito al cambiar de pose.
    SequentialAnimation {
        id: hop
        NumberAnimation { target: lift; property: "y"; to: -10; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: lift; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBounce }
    }

    // Se queda el clic: lo que haya debajo (una tarjeta) no lo recibe.
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.poke()
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
