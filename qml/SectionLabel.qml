import QtQuick
import app.musicplayer

// Etiqueta de una sección, en mayúsculas espaciadas. La misma en el Muro, el detalle, Opciones,
// «Sonando», el panel, el artista e Inspeccionar (ADR-23).
Text {
    color: Theme.textMuted
    font.pixelSize: Theme.fontLabel
    font.weight: Font.DemiBold
    font.letterSpacing: Theme.labelSpacing
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
}
