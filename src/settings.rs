//! Preferencias persistentes expuestas a QML como singleton `AppSettings`.
//!
//! Guarda el estilo de ventana, la vista de cada sección, la skin y las opciones de
//! disposición en `<config>/musicplayer/settings.json`.
//!
//! Las skins son archivos JSON: las incluidas (`skins/` del repositorio, dentro del
//! binario) y las del usuario en `<config>/musicplayer/skins/*.json`.

use std::{collections::BTreeMap, fs, path::PathBuf, pin::Pin};

use cxx_qt::CxxQtType;
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
        // `revision` cambia cada vez que cambia la vista de alguna sección (para enlazar en QML).
        #[qproperty(i32, revision)]
        // Skin elegida (nombre de archivo sin `.json`), su contenido y la lista disponible.
        #[qproperty(QString, skin)]
        #[qproperty(QString, skin_data)]
        #[qproperty(QString, skins)]
        type AppSettings = super::AppSettingsRust;

        /// Valor de una opción de disposición ("" si no se ha elegido).
        #[qinvokable]
        fn opcion(self: &AppSettings, clave: &QString) -> QString;

        /// Cambia una opción de disposición y guarda.
        #[qinvokable]
        fn set_opcion(self: Pin<&mut AppSettings>, clave: &QString, valor: &QString);

        /// Aplica la skin `id` y guarda.
        #[qinvokable]
        fn elegir_skin(self: Pin<&mut AppSettings>, id: &QString);

        /// Vuelve a leer las skins (p. ej. tras añadir un archivo a la carpeta).
        #[qinvokable]
        fn recargar_skins(self: Pin<&mut AppSettings>);

        /// Carpeta donde el usuario puede dejar sus skins.
        #[qinvokable]
        fn carpeta_skins(self: &AppSettings) -> QString;

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

/// Vista de cada sección si el usuario no ha elegido otra.
const DEFAULT_VIEWS: &[(&str, &str)] = &[
    ("inicio", "muro"),
    ("explorar", "muro"),
    ("playlists", "lomos"),
    ("albumes", "lomos"),
    ("megusta", "muro"),
    ("buscar", "muro"),
];

/// Forma en disco de las preferencias; los campos ausentes toman su valor por defecto.
#[derive(Serialize, Deserialize)]
#[serde(default)]
struct Stored {
    ventana: String,
    vistas: BTreeMap<String, String>,
    skin: String,
    opciones: BTreeMap<String, String>,
    // Formato anterior (una clave por sección); se migra al leer.
    #[serde(skip_serializing)]
    vista_inicio: Option<String>,
    #[serde(skip_serializing)]
    vista_explorar: Option<String>,
    #[serde(skip_serializing)]
    vista_playlists: Option<String>,
    #[serde(skip_serializing)]
    vista_albumes: Option<String>,
}

impl Default for Stored {
    fn default() -> Self {
        Self {
            ventana: "vidrio".into(),
            vistas: BTreeMap::new(),
            skin: "vidrio".into(),
            opciones: BTreeMap::new(),
            vista_inicio: None,
            vista_explorar: None,
            vista_playlists: None,
            vista_albumes: None,
        }
    }
}

fn settings_path() -> Option<PathBuf> {
    dirs::config_dir().map(|dir| dir.join("musicplayer").join("settings.json"))
}

fn load() -> Stored {
    let mut stored: Stored = settings_path()
        .and_then(|path| fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default();
    for (section, old) in [
        ("inicio", stored.vista_inicio.take()),
        ("explorar", stored.vista_explorar.take()),
        ("playlists", stored.vista_playlists.take()),
        ("albumes", stored.vista_albumes.take()),
    ] {
        if let Some(view) = old {
            stored.vistas.entry(section.to_owned()).or_insert(view);
        }
    }
    stored
}

/// Skins incluidas en el binario.
const BUILTIN_SKINS: &[(&str, &str)] = &[
    ("vidrio", include_str!("../skins/vidrio.json")),
    ("medianoche", include_str!("../skins/medianoche.json")),
    ("grafito", include_str!("../skins/grafito.json")),
    ("neon", include_str!("../skins/neon.json")),
];

fn skins_dir() -> Option<PathBuf> {
    dirs::config_dir().map(|dir| dir.join("musicplayer").join("skins"))
}

/// Todas las skins válidas: `(id, JSON)`. Una del usuario con el mismo id que una incluida
/// la sustituye.
fn all_skins() -> Vec<(String, String)> {
    let mut skins: Vec<(String, String)> =
        BUILTIN_SKINS.iter().map(|(id, json)| (id.to_string(), json.to_string())).collect();
    let Some(entries) = skins_dir().and_then(|dir| fs::read_dir(dir).ok()) else { return skins };
    let mut user: Vec<_> = entries.flatten().map(|entry| entry.path()).collect();
    user.sort();
    for path in user {
        if path.extension().and_then(|ext| ext.to_str()) != Some("json") {
            continue;
        }
        let (Some(id), Ok(text)) = (path.file_stem().and_then(|s| s.to_str()), fs::read_to_string(&path)) else {
            continue;
        };
        // Solo cuenta si es JSON con nombre y colores; si no, se ignora y se avisa.
        match serde_json::from_str::<serde_json::Value>(&text) {
            Ok(value) if value["nombre"].is_string() && value["colores"].is_object() => {
                skins.retain(|(existing, _)| existing != id);
                skins.push((id.to_owned(), text));
            }
            _ => eprintln!("skin ignorada (falta «nombre» o «colores», o no es JSON): {}", path.display()),
        }
    }
    skins
}

/// Lista para QML: `[{ id, nombre, descripcion }]`.
fn skins_list(skins: &[(String, String)]) -> String {
    let list: Vec<serde_json::Value> = skins
        .iter()
        .filter_map(|(id, json)| {
            let value: serde_json::Value = serde_json::from_str(json).ok()?;
            Some(serde_json::json!({ "id": id, "nombre": value["nombre"], "descripcion": value["descripcion"] }))
        })
        .collect();
    serde_json::to_string(&list).unwrap_or_default()
}

fn skin_json(skins: &[(String, String)], id: &str) -> String {
    skins
        .iter()
        .find(|(skin, _)| skin == id)
        .or_else(|| skins.first())
        .map(|(_, json)| json.clone())
        .unwrap_or_default()
}

pub struct AppSettingsRust {
    ventana: QString,
    revision: i32,
    skin: QString,
    skin_data: QString,
    skins: QString,
    vistas: BTreeMap<String, String>,
    opciones: BTreeMap<String, String>,
}

impl Default for AppSettingsRust {
    fn default() -> Self {
        let stored = load();
        crate::daemon::set_enabled(stored.opciones.get("ytdlp").map(String::as_str) != Some("no"));
        crate::resolver::set_premium(stored.opciones.get("calidad").map(String::as_str) == Some("premium"));
        let skins = all_skins();
        Self {
            ventana: QString::from(&stored.ventana),
            revision: 0,
            skin: QString::from(&stored.skin),
            skin_data: QString::from(&skin_json(&skins, &stored.skin)),
            skins: QString::from(&skins_list(&skins)),
            vistas: stored.vistas,
            opciones: stored.opciones,
        }
    }
}

impl qobject::AppSettings {
    fn vista(&self, seccion: &QString) -> QString {
        let seccion = seccion.to_string();
        let chosen = self.vistas.get(&seccion).map(String::as_str).or_else(|| {
            DEFAULT_VIEWS.iter().find(|(name, _)| *name == seccion).map(|(_, view)| *view)
        });
        QString::from(chosen.unwrap_or("muro"))
    }

    fn set_vista(mut self: Pin<&mut Self>, seccion: &QString, vista: &QString) {
        self.as_mut().rust_mut().vistas.insert(seccion.to_string(), vista.to_string());
        let revision = *self.revision() + 1;
        self.as_mut().set_revision(revision);
        self.save();
    }

    fn opcion(&self, clave: &QString) -> QString {
        QString::from(self.opciones.get(&clave.to_string()).map(String::as_str).unwrap_or(""))
    }

    fn set_opcion(mut self: Pin<&mut Self>, clave: &QString, valor: &QString) {
        match clave.to_string().as_str() {
            "ytdlp" => crate::daemon::set_enabled(valor.to_string() != "no"),
            "calidad" => crate::resolver::set_premium(valor.to_string() == "premium"),
            _ => {}
        }
        // Vacío = valor por defecto: se borra la clave (así no se acumulan, p. ej., los retrasos
        // de letra a cero de cada canción).
        if valor.is_empty() {
            self.as_mut().rust_mut().opciones.remove(&clave.to_string());
        } else {
            self.as_mut().rust_mut().opciones.insert(clave.to_string(), valor.to_string());
        }
        let revision = *self.revision() + 1;
        self.as_mut().set_revision(revision);
        self.save();
    }

    fn elegir_skin(mut self: Pin<&mut Self>, id: &QString) {
        let skins = all_skins();
        self.as_mut().set_skin_data(QString::from(&skin_json(&skins, &id.to_string())));
        self.as_mut().set_skin(id.clone());
        self.save();
    }

    fn recargar_skins(mut self: Pin<&mut Self>) {
        let skins = all_skins();
        let current = self.skin().to_string();
        self.as_mut().set_skins(QString::from(&skins_list(&skins)));
        self.as_mut().set_skin_data(QString::from(&skin_json(&skins, &current)));
    }

    fn carpeta_skins(&self) -> QString {
        QString::from(&skins_dir().map(|dir| dir.display().to_string()).unwrap_or_default())
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
            vistas: self.vistas.clone(),
            skin: self.skin().to_string(),
            opciones: self.opciones.clone(),
            ..Stored::default()
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
