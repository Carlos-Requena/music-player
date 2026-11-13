//! Preferencias persistentes expuestas a QML como singleton `AppSettings`.
//!
//! Guarda el estilo de ventana y la vista elegida para cada sección en
//! `<config>/musicplayer/settings.json`.

use std::{fs, path::PathBuf, pin::Pin};

use cxx_qt_lib::QString;
use serde::{Deserialize, Serialize};

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    #[auto_cxx_name]
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, ventana)]
        #[qproperty(QString, vista_inicio)]
        #[qproperty(QString, vista_explorar)]
        #[qproperty(QString, vista_playlists)]
        #[qproperty(QString, vista_albumes)]
        type AppSettings = super::AppSettingsRust;

        /// Devuelve la vista ("muro", "lomos" o "cubeta") de una sección.
        #[qinvokable]
        fn vista(self: &AppSettings, seccion: &QString) -> QString;

        /// Cambia la vista de una sección y guarda las preferencias.
        #[qinvokable]
        fn set_vista(self: Pin<&mut AppSettings>, seccion: &QString, vista: &QString);

        /// Cambia el estilo de ventana ("vidrio" o "escenario") y guarda.
        #[qinvokable]
        fn elegir_ventana(self: Pin<&mut AppSettings>, ventana: &QString);
    }
}

/// Forma en disco de las preferencias; los campos ausentes toman su valor por defecto.
#[derive(Serialize, Deserialize)]
#[serde(default)]
struct Stored {
    ventana: String,
    vista_inicio: String,
    vista_explorar: String,
    vista_playlists: String,
    vista_albumes: String,
}

impl Default for Stored {
    fn default() -> Self {
        Self {
            ventana: "vidrio".into(),
            vista_inicio: "muro".into(),
            vista_explorar: "muro".into(),
            vista_playlists: "lomos".into(),
            vista_albumes: "lomos".into(),
        }
    }
}

fn settings_path() -> Option<PathBuf> {
    dirs::config_dir().map(|dir| dir.join("musicplayer").join("settings.json"))
}

fn load() -> Stored {
    settings_path()
        .and_then(|path| fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default()
}

pub struct AppSettingsRust {
    ventana: QString,
    vista_inicio: QString,
    vista_explorar: QString,
    vista_playlists: QString,
    vista_albumes: QString,
}

impl Default for AppSettingsRust {
    fn default() -> Self {
        let stored = load();
        Self {
            ventana: QString::from(&stored.ventana),
            vista_inicio: QString::from(&stored.vista_inicio),
            vista_explorar: QString::from(&stored.vista_explorar),
            vista_playlists: QString::from(&stored.vista_playlists),
            vista_albumes: QString::from(&stored.vista_albumes),
        }
    }
}

impl qobject::AppSettings {
    fn vista(&self, seccion: &QString) -> QString {
        match seccion.to_string().as_str() {
            "inicio" => self.vista_inicio().clone(),
            "explorar" => self.vista_explorar().clone(),
            "playlists" => self.vista_playlists().clone(),
            "albumes" => self.vista_albumes().clone(),
            _ => QString::from("muro"),
        }
    }

    fn set_vista(mut self: Pin<&mut Self>, seccion: &QString, vista: &QString) {
        let vista = vista.clone();
        match seccion.to_string().as_str() {
            "inicio" => self.as_mut().set_vista_inicio(vista),
            "explorar" => self.as_mut().set_vista_explorar(vista),
            "playlists" => self.as_mut().set_vista_playlists(vista),
            "albumes" => self.as_mut().set_vista_albumes(vista),
            _ => return,
        }
        self.save();
    }

    fn elegir_ventana(mut self: Pin<&mut Self>, ventana: &QString) {
        self.as_mut().set_ventana(ventana.clone());
        self.save();
    }

    /// Escribe las preferencias; un fallo de disco no debe tumbar la interfaz.
    fn save(&self) {
        let Some(path) = settings_path() else { return };
        let stored = Stored {
            ventana: self.ventana().to_string(),
            vista_inicio: self.vista_inicio().to_string(),
            vista_explorar: self.vista_explorar().to_string(),
            vista_playlists: self.vista_playlists().to_string(),
            vista_albumes: self.vista_albumes().to_string(),
        };
        if let Some(dir) = path.parent() {
            let _ = fs::create_dir_all(dir);
        }
        if let Ok(text) = serde_json::to_string_pretty(&stored) {
            if let Err(error) = fs::write(&path, text) {
                eprintln!("No se pudieron guardar las preferencias en {}: {error}", path.display());
            }
        }
    }
}
