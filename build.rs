use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

/// Componentes QML del módulo `app.musicplayer` (se registran en el qmldir).
const QML_FILES: &[&str] = &[
    "qml/Main.qml",
    "qml/Ambient.qml",
    "qml/Glass.qml",
    "qml/Cover.qml",
    "qml/Icon.qml",
    "qml/IconButton.qml",
    "qml/TopNav.qml",
    "qml/ViewSwitcher.qml",
    "qml/SectionView.qml",
    "qml/MuroView.qml",
    "qml/LomosView.qml",
    "qml/CubetaView.qml",
    "qml/NowPlayingPanel.qml",
    "qml/LyricsView.qml",
    "qml/PlayerBar.qml",
    "qml/SettingsSheet.qml",
];

/// Singletons QML (tema y datos de ejemplo).
const QML_SINGLETONS: &[&str] = &["qml/Theme.qml", "qml/Catalog.qml"];

fn main() {
    let module = QmlModule::new("app.musicplayer")
        .qml_files(QML_FILES.iter().copied())
        .qml_files(
            QML_SINGLETONS
                .iter()
                .map(|path| QmlFile::from(path).singleton(true)),
        );

    CxxQtBuilder::new_qml_module(module)
        .qt_module("Gui")
        .qt_module("Quick")
        .files(["src/player.rs", "src/settings.rs"])
        .build();
}
