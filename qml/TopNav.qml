import QtQuick
import app.musicplayer

// Navegación principal: pestañas en píldora sobre vidrio (regla de dos: la sección en la que
// estás, en blanco).
Glass {
    id: root

    property string current: "inicio"
    signal selected(string section)

    implicitWidth: tabs.implicitWidth + 8
    implicitHeight: Theme.hit + 8
    radius: height / 2

    Tabs {
        id: tabs
        anchors.centerIn: parent
        navigate: true
        tabs: Catalog.sections.map(section => ({ id: section.id, label: section.label }))
        current: root.current
        onPicked: id => root.selected(id)
    }
}
