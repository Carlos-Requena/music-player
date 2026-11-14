import QtQuick
import app.musicplayer

// Mascota (Opciones › Mascota): una imagen que cambia de pose según lo que pasa en el
// reproductor y da un saltito al cambiar. Las poses son PNG con transparencia de la carpeta de
// la mascota. De más a menos prioridad:
//
//   error      si algo falla                          → si falta, cargando
//   cargando   si una pista tarda en arrancar         → reposo
//   clic       unos segundos al pincharla             → nueva
//   nueva      unos segundos al empezar una pista     → sonando
//   sonando    mientras suena                         → reposo
//   navegando  sin música, mientras recorres la estantería o abres un álbum → pausa
//   pausa      con una pista en pausa                 → reposo
//   reposo     sin nada sonando (la única obligatoria)
//
// Cada pose es el nombre del PNG o `{ "imagen": "x.png", "alto": 120 }` para darle su propio
// alto (p. ej. si una pose es solo la cabeza y otra el busto entero).
//
// Es decorativa: no tapa los clics de lo que hay debajo (los gestores solo escuchan).
Item {
    id: root

    readonly property var poses: Theme.mascot ? Theme.mascot.poses : ({})
    readonly property real baseTall: Theme.mascot && Theme.mascot.alto ? Theme.mascot.alto : 160

    // Estados breves.
    property bool fresh: false
    property bool poked: false
    property bool slow: false

    property bool browsing: false

    readonly property string mood: Player.error !== "" ? "error"
        : slow ? "cargando"
        : poked ? "clic"
        : fresh && Player.playing ? "nueva"
        : Player.playing ? "sonando"
        : browsing ? "navegando"
        : Player.title !== "" ? "pausa"
        : "reposo"

    readonly property var fallback: ({
        error: "cargando", cargando: "reposo", clic: "nueva", nueva: "sonando",
        sonando: "reposo", navegando: "pausa", pausa: "reposo"
    })

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

    Accessible.ignored: true

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
        // Pista nueva (el índice no basta: la primera pista no lo cambia).
        function onTitleChanged() {
            if (Player.title === "")
                return
            root.fresh = true
            freshTimer.restart()
        }
    }
    Timer {
        id: freshTimer
        interval: 4000
        onTriggered: root.fresh = false
    }
    Timer {
        id: pokeTimer
        interval: 2500
        onTriggered: root.poked = false
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

    TapHandler {
        onTapped: {
            root.poked = true
            pokeTimer.restart()
            hop.restart()
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
