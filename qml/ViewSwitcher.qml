import QtQuick
import app.musicplayer

// Selector rápido de la vista (Lomos, Cubeta, Muro) de la sección actual.
Glass {
    id: root

    property string view: "muro"
    signal picked(string view)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.hit + 8
    radius: height / 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        IconButton {
            icon: Theme.iconLomos
            label: "Vista Lomos"
            active: root.view === "lomos"
            onClicked: root.picked("lomos")
        }

        IconButton {
            icon: Theme.iconCubeta
            label: "Vista Cubeta"
            active: root.view === "cubeta"
            onClicked: root.picked("cubeta")
        }

        IconButton {
            icon: Theme.iconMuro
            label: "Vista Muro"
            active: root.view === "muro"
            onClicked: root.picked("muro")
        }
    }
}
