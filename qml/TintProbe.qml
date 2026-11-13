import QtQuick

// Calcula el color dominante de una carátula a partir de su miniatura más pequeña.
// Debe estar visible (aunque quede tapado) para que Qt lo pinte.
Canvas {
    id: probe

    property string thumb: ""
    property color tint: "#3A3F4B"

    readonly property string url: thumb.replace("w544-h544", "w60-h60")

    width: 8
    height: 8

    onUrlChanged: {
        if (url === "")
            return
        if (isImageLoaded(url))
            requestPaint()
        else
            loadImage(url)
    }
    onImageLoaded: requestPaint()

    onPaint: {
        if (url === "" || !isImageLoaded(url))
            return
        const ctx = getContext("2d")
        ctx.drawImage(url, 0, 0, width, height)
        const data = ctx.getImageData(0, 0, width, height).data

        // Media ponderada: los píxeles más saturados pesan más para que el color no salga gris.
        let r = 0, g = 0, b = 0, total = 0
        for (let i = 0; i < data.length; i += 4) {
            const weight = Math.max(data[i], data[i + 1], data[i + 2]) - Math.min(data[i], data[i + 1], data[i + 2]) + 12
            r += data[i] * weight
            g += data[i + 1] * weight
            b += data[i + 2] * weight
            total += weight
        }
        if (total === 0)
            return
        const mean = Qt.rgba(r / total / 255, g / total / 255, b / total / 255, 1)
        tint = Qt.hsla(mean.hslHue,
                       Math.min(1, mean.hslSaturation * 1.25),
                       Math.max(0.22, Math.min(0.5, mean.hslLightness)),
                       1)
    }
}
