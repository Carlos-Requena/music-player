import QtQuick
import QtQuick.Shapes
import app.musicplayer

// Icono vectorial a partir de un trazo SVG en caja 24×24.
Item {
    id: root

    property string path
    property color color: Theme.text
    property bool filled: false
    property real size: 20

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.filled ? "transparent" : root.color
            strokeWidth: 1.8
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
