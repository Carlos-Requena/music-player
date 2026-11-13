import QtQuick
import app.musicplayer

// Carátula. Mientras no haya miniaturas reales dibuja arte generado a partir de `Catalog.covers`;
// una lista de cuatro índices se pinta como collage 2×2 (playlists).
Item {
    id: root

    property var art: 0
    readonly property bool collage: typeof art !== "number"

    Grid {
        anchors.fill: parent
        columns: 2
        visible: root.collage

        Repeater {
            model: root.collage ? root.art : []

            Canvas {
                required property var modelData
                width: root.width / 2
                height: root.height / 2
                onPaint: root.paint(getContext("2d"), width, height, Catalog.cover(modelData))
                onWidthChanged: requestPaint()
                onModelDataChanged: requestPaint()
            }
        }
    }

    // Se pinta una sola vez a 256 px y se escala: animar el tamaño no repinta.
    Canvas {
        id: single
        visible: !root.collage
        width: 256
        height: 256
        transformOrigin: Item.TopLeft
        scale: root.width / 256
        onPaint: root.paint(getContext("2d"), width, height, Catalog.cover(root.art))
    }

    onArtChanged: single.requestPaint()

    function disc(ctx, x, y, r, color) {
        ctx.fillStyle = color
        ctx.beginPath()
        ctx.arc(x, y, r, 0, 2 * Math.PI)
        ctx.fill()
    }

    function paint(ctx, w, h, spec) {
        const c = spec.c
        ctx.reset()
        ctx.fillStyle = c[0]
        ctx.fillRect(0, 0, w, h)

        switch (spec.kind) {
        case "sun":
            disc(ctx, w / 2, h * 0.44, h * 0.29, c[3])
            disc(ctx, w / 2, h * 0.44, h * 0.16, c[1])
            ctx.fillStyle = c[2]
            ctx.fillRect(0, h * 0.6, w, h * 0.4)
            break
        case "rings":
            for (let i = 12; i >= 1; --i)
                disc(ctx, 0, h, i * w * 0.11, i % 2 ? c[1] : c[0])
            break
        case "stripes":
            ctx.save()
            ctx.translate(w / 2, h / 2)
            ctx.rotate(Math.PI / 4)
            ctx.fillStyle = c[1]
            for (let x = -w; x < w; x += w * 0.13)
                ctx.fillRect(x, -h, w * 0.04, 2 * h)
            ctx.restore()
            break
        case "dot":
            disc(ctx, w * 0.4, h * 0.6, w * 0.23, c[1])
            disc(ctx, w * 0.66, h * 0.4, w * 0.08, c[2])
            break
        case "moon": {
            const sky = ctx.createLinearGradient(0, 0, w, h)
            sky.addColorStop(0, c[0])
            sky.addColorStop(1, c[2])
            ctx.fillStyle = sky
            ctx.fillRect(0, 0, w, h)
            disc(ctx, w * 0.54, h * 0.4, w * 0.25, c[1])
            disc(ctx, w * 0.63, h * 0.36, w * 0.22, "#12295A")
            break
        }
        case "half":
            disc(ctx, w / 2, h, w * 0.5, c[1])
            break
        case "bars": {
            const widths = [3, 4, 2, 7, 3, 9, 2, 5]
            let x = 0
            for (let i = 0; x < w; ++i) {
                const bar = widths[i % widths.length] * w / 128
                if (i % 2 === 0) {
                    ctx.fillStyle = i % 3 === 0 ? "#8A8A8A" : c[1]
                    ctx.fillRect(x, 0, bar, h)
                }
                x += bar
            }
            break
        }
        case "arch":
            ctx.fillStyle = c[1]
            ctx.beginPath()
            ctx.ellipse(w * 0.16, h * 0.44, w * 0.68, h * 1.12)
            ctx.fill()
            ctx.fillStyle = c[2]
            ctx.beginPath()
            ctx.ellipse(w * 0.28, h * 0.6, w * 0.44, h * 0.8)
            ctx.fill()
            break
        case "checker":
            ctx.fillStyle = c[1]
            for (let row = 0; row < 4; ++row)
                for (let col = 0; col < 4; ++col)
                    if ((row + col) % 2)
                        ctx.fillRect(col * w / 4, row * h / 4, w / 4, h / 4)
            break
        case "cross":
            ctx.strokeStyle = c[1]
            ctx.lineWidth = w * 0.09
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(w, h)
            ctx.moveTo(w, 0)
            ctx.lineTo(0, h)
            ctx.stroke()
            break
        case "waves":
            ctx.fillStyle = c[1]
            for (let y = h * 0.08; y < h; y += h * 0.1)
                ctx.fillRect(0, y, w, h * 0.02)
            break
        case "orbit":
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55)
            ctx.lineWidth = Math.max(1, w / 200)
            for (let r = w * 0.085; r < w * 0.75; r += w * 0.085) {
                ctx.beginPath()
                ctx.arc(w / 2, h / 2, r, 0, 2 * Math.PI)
                ctx.stroke()
            }
            disc(ctx, w * 0.74, h * 0.3, w * 0.05, c[2])
            break
        }
    }
}
