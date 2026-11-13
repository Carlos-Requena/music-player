//! Compila la ventana de inicio de sesión de Linux (`src/login_linux.cpp`) contra Qt WebEngine.
//!
//! Es opcional: si no está `qt6-webengine` (o no compila), se construye un programa que solo
//! responde «no disponible» a `--check`, y el reproductor ofrece importar la sesión del
//! navegador como antes. Así una dependencia que falta nunca rompe la compilación.

use std::{path::PathBuf, process::Command};

fn qmake_query(qmake: &str, key: &str) -> Option<String> {
    let output = Command::new(qmake).args(["-query", key]).output().ok()?;
    output.status.success().then(|| String::from_utf8_lossy(&output.stdout).trim().to_owned()).filter(|v| !v.is_empty())
}

fn main() {
    println!("cargo::rustc-check-cfg=cfg(webengine)");
    println!("cargo::rerun-if-changed=src/login_linux.cpp");
    println!("cargo::rerun-if-env-changed=QMAKE");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("linux") {
        return;
    }

    let candidates = std::env::var("QMAKE").into_iter().chain(["qmake6".to_owned(), "qmake".to_owned()]);
    let Some((headers, libs)) = candidates
        .into_iter()
        .find_map(|qmake| Some((qmake_query(&qmake, "QT_INSTALL_HEADERS")?, qmake_query(&qmake, "QT_INSTALL_LIBS")?)))
    else {
        println!("cargo::warning=No se encuentra qmake: la ventana de inicio de sesión no se compila.");
        return;
    };
    let headers = PathBuf::from(headers);
    if !headers.join("QtWebEngineWidgets").is_dir() {
        println!(
            "cargo::warning=Falta qt6-webengine: sin ventana de inicio de sesión (se podrá importar la sesión del navegador). \
             Instálalo con `sudo pacman -S qt6-webengine` y vuelve a compilar."
        );
        return;
    }

    let mut build = cc::Build::new();
    build.cpp(true).file("src/login_linux.cpp").flag("-std=c++17").include(&headers);
    for module in ["QtCore", "QtGui", "QtWidgets", "QtNetwork", "QtWebEngineCore", "QtWebEngineWidgets"] {
        build.include(headers.join(module));
    }
    if let Err(error) = build.try_compile("musicplayer_login_linux") {
        println!("cargo::warning=No se pudo compilar la ventana de inicio de sesión: {error}");
        return;
    }

    println!("cargo::rustc-link-search=native={libs}");
    for lib in ["Qt6WebEngineWidgets", "Qt6WebEngineCore", "Qt6Widgets", "Qt6Network", "Qt6Gui", "Qt6Core"] {
        println!("cargo::rustc-link-lib=dylib={lib}");
    }
    println!("cargo::rustc-cfg=webengine");
}
