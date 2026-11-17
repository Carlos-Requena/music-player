use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

/// Componentes QML del módulo `app.musicplayer` (se registran en el qmldir).
const QML_FILES: &[&str] = &[
    "qml/Main.qml",
    "qml/Ambient.qml",
    "qml/Glass.qml",
    "qml/Cover.qml",
    "qml/TintProbe.qml",
    "qml/Icon.qml",
    "qml/IconButton.qml",
    "qml/SearchField.qml",
    "qml/Slider.qml",
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
    "qml/PillButton.qml",
    "qml/DetailView.qml",
    "qml/InspectView.qml",
    "qml/MiniPlayer.qml",
    "qml/TextField.qml",
    "qml/NowPlayingView.qml",
    "qml/ContextMenu.qml",
    "qml/CategoryBar.qml",
    "qml/Mascot.qml",
    "qml/QueueList.qml",
    "qml/LyricsTiming.qml",
    "qml/TabStrip.qml",
];

/// Singletons QML (tema y datos de ejemplo).
const QML_SINGLETONS: &[&str] = &["qml/Theme.qml", "qml/Catalog.qml"];

/// Sombreadores ya compilados con `scripts/shaders.sh` (qsb). Van en el repositorio para que
/// compilar no necesite qsb; en QML: `qrc:/qt/qml/app/musicplayer/shaders/<nombre>.qsb`.
const SHADERS: &[&str] = &["shaders/fluido.frag", "shaders/reflejo.frag"];

fn main() {
    // Aviso si un sombreador cambió y su .qsb no se volvió a compilar.
    for source in SHADERS {
        println!("cargo::rerun-if-changed={source}");
        let modified = |path: &str| std::fs::metadata(path).and_then(|m| m.modified()).ok();
        if let (Some(src), Some(qsb)) = (modified(source), modified(&format!("{source}.qsb"))) {
            if src > qsb {
                println!("cargo::warning={source} es más nuevo que su .qsb: ejecuta scripts/shaders.sh");
            }
        }
    }
    // Application ID de Discord que se incluye en la app (ver COMPILAR.md).
    println!("cargo::rerun-if-env-changed=MUSICPLAYER_DISCORD_ID");
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
        .qt_module("Network")
        .qrc_resources(SHADERS.iter().map(|source| format!("{source}.qsb")).collect::<Vec<_>>())
        .cpp_file("src/window.cpp")
        .cpp_file("src/signals.cpp")
        .files(["src/account.rs", "src/library.rs", "src/player.rs", "src/plugins.rs", "src/settings.rs"])
        .build();

    // Ventana de inicio de sesión (WebKit del sistema). Solo macOS: en Linux el navegador no
    // está protegido y la sesión se importa de él directamente.
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo::rerun-if-changed=src/login_mac.mm");
        cc::Build::new()
            .cpp(true)
            .file("src/login_mac.mm")
            .flag("-fobjc-arc")
            .flag("-std=c++17")
            .compile("musicplayer_login");
        println!("cargo::rustc-link-lib=framework=Cocoa");
        println!("cargo::rustc-link-lib=framework=WebKit");
    }
}
