import QtQuick
import QtMultimedia
import app.musicplayer

// Carátula animada de «Sonando» (opción `caratulaAnimada`): el vídeo en bucle de Apple Music que
// publica `Player.animada`, con esquinas redondeadas. Va aparte de `NowPlayingView` para que, si
// falta Qt Multimedia, solo falle esto. Aparece con un fundido cuando empieza a reproducir.
Item {
    id: root

    property url source
    // Lado de la textura del vídeo en píxeles físicos (960 como mucho, el del original).
    property real textureSide: 960
    // Lo pone «Sonando» (opción `esquinas`).
    property real radius: Theme.radiusM

    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 500 } }

    MediaPlayer {
        id: video
        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        // Se mueve mientras suena la música; en pausa, se queda quieto (no gasta CPU).
        readonly property bool run: Player.playing
        onRunChanged: run ? play() : pause()
        // El archivo llega después de crearse (lo pone el `Loader` de «Sonando»).
        onSourceChanged: if (run) play()
        onPlaybackStateChanged: if (playbackState !== MediaPlayer.StoppedState) root.opacity = 1
        onErrorOccurred: (error, message) => console.warn("animada:", message)
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // Esquinas redondeadas con un sombreador (`redondeo.frag`) que lee la textura del vídeo. Una
    // capa con máscara (`MultiEffect`) costaba ~20 MB y ~5 % de CPU más.
    ShaderEffectSource {
        id: outputTexture
        sourceItem: output
        hideSource: true
        visible: false
        textureSize: Qt.size(root.textureSide, root.textureSide)
    }

    ShaderEffect {
        anchors.fill: parent
        property variant source: outputTexture
        property size size: Qt.size(width, height)
        property real radius: root.radius
        fragmentShader: "qrc:/qt/qml/app/musicplayer/shaders/redondeo.frag.qsb"
    }
}
