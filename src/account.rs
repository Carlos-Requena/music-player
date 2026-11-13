//! Sesión de YouTube Music importada del navegador, expuesta a QML como singleton `Account`.
//!
//! Google bloquea los inicios de sesión desde navegadores embebidos, así que no hay
//! formulario propio: se copian las cookies de youtube.com del navegador donde el usuario
//! ya tiene la sesión abierta (con `yt-dlp --cookies-from-browser`). Solo se guardan las de
//! youtube.com, en un archivo legible únicamente por el usuario.

use std::{
    fs,
    path::PathBuf,
    pin::Pin,
    process::{Command, Stdio},
    sync::{LazyLock, RwLock},
    thread,
    time::{SystemTime, UNIX_EPOCH},
};

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use serde::{Deserialize, Serialize};
use sha1::{Digest, Sha1};

use crate::audio::{search_path, which};

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
        #[qproperty(bool, signed_in)]
        #[qproperty(bool, busy)]
        #[qproperty(QString, name)]
        #[qproperty(QString, browser)]
        #[qproperty(QString, message)]
        // macOS impidió leer las cookies (Safari necesita «Acceso total al disco»).
        #[qproperty(bool, needs_disk_access)]
        type Account = super::AccountRust;

        /// Abre en Ajustes del Sistema el panel «Acceso total al disco» (macOS).
        #[qinvokable]
        fn open_privacy_settings(self: &Account);

        /// Importa la sesión del navegador `browser` (chrome, firefox, safari…).
        #[qinvokable]
        fn sign_in(self: Pin<&mut Account>);

        /// Comprueba en segundo plano que la sesión guardada sigue valiendo.
        #[qinvokable]
        fn verify(self: Pin<&mut Account>);

        /// Borra la sesión guardada.
        #[qinvokable]
        fn sign_out(self: Pin<&mut Account>);
    }

    impl cxx_qt::Threading for Account {}
}

const ORIGIN: &str = "https://music.youtube.com";

/// Credenciales para las peticiones a InnerTube.
pub struct Session {
    cookie: String,
    sapisid: String,
}

impl Session {
    /// Cabeceras `Cookie` y `Authorization` (SAPISIDHASH) para una petición.
    pub fn headers(&self) -> (String, String) {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs());
        let digest = Sha1::digest(format!("{now} {} {ORIGIN}", self.sapisid).as_bytes());
        let hash: String = digest.iter().map(|byte| format!("{byte:02x}")).collect();
        (self.cookie.clone(), format!("SAPISIDHASH {now}_{hash}"))
    }
}

static SESSION: LazyLock<RwLock<Option<Session>>> = LazyLock::new(|| RwLock::new(load_session()));

fn config_dir() -> Option<PathBuf> {
    dirs::config_dir().map(|dir| dir.join("musicplayer"))
}

/// Archivo de cookies (formato Netscape) que también usa yt-dlp.
pub fn cookies_path() -> Option<PathBuf> {
    config_dir().map(|dir| dir.join("cookies.txt"))
}

fn info_path() -> Option<PathBuf> {
    config_dir().map(|dir| dir.join("account.json"))
}

/// Ruta del archivo de cookies si hay sesión, para pasárselo a yt-dlp.
pub fn cookies_file() -> Option<PathBuf> {
    cookies_path().filter(|path| path.is_file())
}

/// Copia privada del archivo de cookies para un proceso externo (yt-dlp lo reescribe al
/// terminar). `None` si no hay sesión.
pub fn cookies_copy(tag: &str) -> Option<PathBuf> {
    let source = cookies_file()?;
    let copy = source.with_file_name(format!("cookies-{tag}.tmp"));
    let text = fs::read_to_string(&source).ok()?;
    write_private(&copy, &text).ok()?;
    Some(copy)
}

/// Ejecuta `f` con la sesión actual, si la hay.
pub fn with_session<T>(f: impl FnOnce(&Session) -> T) -> Option<T> {
    SESSION.read().ok()?.as_ref().map(f)
}

/// Cookies `(dominio, nombre, valor)` de un archivo Netscape.
fn parse_cookies(text: &str) -> Vec<(String, String, String)> {
    text.lines()
        .filter_map(|line| {
            // Las cookies HttpOnly llevan este prefijo; el resto de líneas con `#` son comentarios.
            let line = line.strip_prefix("#HttpOnly_").unwrap_or(line);
            if line.starts_with('#') {
                return None;
            }
            let fields: Vec<&str> = line.split('\t').collect();
            (fields.len() == 7).then(|| (fields[0].to_owned(), fields[5].to_owned(), fields[6].trim_end().to_owned()))
        })
        .collect()
}

fn is_youtube(domain: &str) -> bool {
    let domain = domain.trim_start_matches('.');
    domain == "youtube.com" || domain.ends_with(".youtube.com")
}

fn session_from(text: &str) -> Option<Session> {
    let cookies: Vec<_> = parse_cookies(text).into_iter().filter(|(domain, ..)| is_youtube(domain)).collect();
    let sapisid = cookies
        .iter()
        .find(|(_, name, _)| name == "SAPISID")
        .or_else(|| cookies.iter().find(|(_, name, _)| name == "__Secure-3PAPISID"))
        .map(|(_, _, value)| value.clone())?;
    let cookie = cookies.iter().map(|(_, name, value)| format!("{name}={value}")).collect::<Vec<_>>().join("; ");
    Some(Session { cookie, sapisid })
}

fn load_session() -> Option<Session> {
    session_from(&fs::read_to_string(cookies_path()?).ok()?)
}

#[derive(Default, Serialize, Deserialize)]
#[serde(default)]
struct Info {
    name: String,
    browser: String,
}

fn load_info() -> Info {
    info_path()
        .and_then(|path| fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default()
}

fn save_info(info: &Info) {
    if let (Some(path), Ok(text)) = (info_path(), serde_json::to_string_pretty(info)) {
        let _ = fs::write(path, text);
    }
}

/// Escribe un archivo que solo puede leer el usuario.
fn write_private(path: &PathBuf, text: &str) -> std::io::Result<()> {
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)?;
    }
    fs::write(path, text)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    }
    Ok(())
}

/// Copia del navegador las cookies de youtube.com y comprueba que hay sesión.
/// Devuelve el nombre de la cuenta.
fn import(browser: &str) -> Result<String, String> {
    let path = search_path();
    let ytdlp = which("yt-dlp", &path).ok_or("No se encuentra yt-dlp.")?;
    let target = cookies_path().ok_or("No hay carpeta de configuración.")?;
    // yt-dlp vuelca todas las cookies del navegador: se escriben en un temporal privado,
    // se filtran y el temporal se borra enseguida.
    let scratch = target.with_file_name("cookies-import.tmp");
    write_private(&scratch, "").map_err(|error| format!("No se pudo preparar la importación: {error}"))?;

    let output = Command::new(ytdlp)
        .env("PATH", &path)
        .args(["--no-warnings", "--skip-download", "--flat-playlist", "--cookies-from-browser", browser, "--cookies"])
        .arg(&scratch)
        .arg("https://music.youtube.com/")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output();
    let dump = fs::read_to_string(&scratch).unwrap_or_default();
    let _ = fs::remove_file(&scratch);
    let output = output.map_err(|error| format!("No se pudo ejecutar yt-dlp: {error}"))?;

    let youtube: String = dump
        .lines()
        .filter(|line| {
            let cookie = line.strip_prefix("#HttpOnly_").unwrap_or(line);
            !cookie.starts_with('#') && cookie.split('\t').next().is_some_and(is_youtube)
        })
        .map(|line| format!("{line}\n"))
        .collect();

    let Some(session) = session_from(&youtube) else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        // macOS protege la carpeta de cookies de Safari: sin «Acceso total al disco» para el
        // programa que abrió el reproductor, el sistema niega la lectura.
        if permission_denied(&stderr) {
            return Err(DISK_ACCESS.to_owned());
        }
        if let Some(error) = stderr.lines().find(|line| line.contains("ERROR") && line.to_lowercase().contains("cookie")) {
            return Err(format!("No se pudieron leer las cookies de {browser}: {}", error.trim_start_matches("ERROR: ")));
        }
        // El detalle de yt-dlp ayuda a diagnosticar (navegador sin perfil, base de datos bloqueada…).
        let detail = stderr
            .lines()
            .rev()
            .find(|line| line.contains("ERROR") || line.contains("Extracted") || line.contains("cookies from"))
            .map(|line| format!(" (yt-dlp: {})", line.trim_start_matches("ERROR: ").trim()))
            .unwrap_or_default();
        return Err(format!(
            "No hay sesión de YouTube en {browser}. Abre music.youtube.com en ese navegador, inicia sesión y vuelve a intentarlo.{detail}"
        ));
    };

    write_private(&target, &format!("# Netscape HTTP Cookie File\n{youtube}"))
        .map_err(|error| format!("No se pudo guardar la sesión: {error}"))?;
    if let Ok(mut current) = SESSION.write() {
        *current = Some(session);
    }

    match crate::ytm::account_name() {
        Ok(name) if !name.is_empty() => Ok(name),
        Ok(_) => {
            forget();
            Err("YouTube no reconoce la sesión copiada. Vuelve a iniciar sesión en el navegador.".to_owned())
        }
        Err(error) => {
            forget();
            Err(error)
        }
    }
}

/// ¿El sistema negó a yt-dlp la lectura de las cookies del navegador?
fn permission_denied(stderr: &str) -> bool {
    stderr.contains("Operation not permitted") || stderr.contains("PermissionError")
}

/// Marca de error para «macOS no deja leer las cookies».
const DISK_ACCESS: &str = "\u{0}acceso-disco";

fn forget() {
    if let Ok(mut current) = SESSION.write() {
        *current = None;
    }
    if let Some(path) = cookies_path() {
        let _ = fs::remove_file(path);
    }
    clean_copies();
    crate::library::cache::forget_account();
}

/// Borra las copias de cookies que se dieron a yt-dlp y mpv.
fn clean_copies() {
    let Some(dir) = config_dir() else { return };
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if name.starts_with("cookies-") && name.ends_with(".tmp") {
            let _ = fs::remove_file(entry.path());
        }
    }
}

fn default_browser() -> &'static str {
    "chrome"
}

pub struct AccountRust {
    signed_in: bool,
    busy: bool,
    name: QString,
    browser: QString,
    message: QString,
    needs_disk_access: bool,
}

impl Default for AccountRust {
    fn default() -> Self {
        // Restos de una ejecución anterior que terminó sin limpiar.
        clean_copies();
        let info = load_info();
        let signed_in = with_session(|_| ()).is_some();
        let browser = if info.browser.is_empty() { default_browser().to_owned() } else { info.browser };
        Self {
            signed_in,
            busy: false,
            name: QString::from(if signed_in { info.name.as_str() } else { "" }),
            browser: QString::from(&browser),
            message: QString::default(),
            needs_disk_access: false,
        }
    }
}

impl qobject::Account {
    fn sign_in(mut self: Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        let browser = self.browser().to_string();
        self.as_mut().set_busy(true);
        self.as_mut().set_message(QString::from("Leyendo la sesión del navegador…"));

        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = import(&browser);
            let _ = qt.queue(move |mut account| {
                account.as_mut().set_busy(false);
                match result {
                    Ok(name) => {
                        account.as_mut().set_needs_disk_access(false);
                        save_info(&Info { name: name.clone(), browser });
                        account.as_mut().set_name(QString::from(&name));
                        account.as_mut().set_message(QString::default());
                        account.as_mut().set_signed_in(true);
                    }
                    Err(error) if error == DISK_ACCESS => {
                        account.as_mut().set_needs_disk_access(true);
                        account.as_mut().set_message(QString::from(&format!(
                            "macOS no deja leer las cookies de {browser}. En Ajustes del Sistema › Privacidad y seguridad › \
                             Acceso total al disco, activa la aplicación desde la que abres el reproductor (Terminal, iTerm, \
                             VS Code… o el propio reproductor si lo abres como app). Después ciérrala del todo, vuelve a \
                             abrirla y pulsa Iniciar sesión. Con Chrome no hace falta este permiso."
                        )));
                        account.as_mut().set_signed_in(false);
                    }
                    Err(error) => {
                        account.as_mut().set_needs_disk_access(false);
                        account.as_mut().set_message(QString::from(&error));
                        account.as_mut().set_signed_in(false);
                    }
                }
            });
        });
    }

    fn verify(self: Pin<&mut Self>) {
        if !*self.signed_in() {
            return;
        }
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = crate::ytm::account_name();
            let _ = qt.queue(move |mut account| match result {
                Ok(name) if !name.is_empty() => {
                    if name != account.name().to_string() {
                        save_info(&Info { name: name.clone(), browser: account.browser().to_string() });
                        account.as_mut().set_name(QString::from(&name));
                    }
                }
                // YouTube ya no reconoce las cookies: se cierra la sesión y se avisa.
                Ok(_) => {
                    forget();
                    account.as_mut().set_message(QString::from(
                        "Tu sesión guardada ha caducado. Vuelve a iniciar sesión.",
                    ));
                    account.as_mut().set_name(QString::default());
                    account.as_mut().set_signed_in(false);
                }
                // Sin red no se puede saber: se mantiene la sesión.
                Err(error) => eprintln!("no se pudo comprobar la sesión: {error}"),
            });
        });
    }

    fn open_privacy_settings(&self) {
        #[cfg(target_os = "macos")]
        let _ = Command::new("open")
            .arg("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
            .spawn();
    }

    fn sign_out(mut self: Pin<&mut Self>) {
        forget();
        save_info(&Info { name: String::new(), browser: self.browser().to_string() });
        self.as_mut().set_name(QString::default());
        self.as_mut().set_message(QString::default());
        self.as_mut().set_signed_in(false);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = "# Netscape HTTP Cookie File\n\
        .youtube.com\tTRUE\t/\tTRUE\t1999999999\tSAPISID\tabc/123\n\
        #HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t1999999999\tSID\tsecret\n\
        .google.com\tTRUE\t/\tTRUE\t1999999999\tNID\tajeno\n\
        music.youtube.com\tFALSE\t/\tTRUE\t1999999999\tPREF\tf6=80\n";

    #[test]
    fn solo_se_usan_cookies_de_youtube() {
        let session = session_from(SAMPLE).expect("hay SAPISID");
        assert_eq!(session.sapisid, "abc/123");
        assert_eq!(session.cookie, "SAPISID=abc/123; SID=secret; PREF=f6=80");
    }

    #[test]
    fn detecta_el_bloqueo_de_safari() {
        let stderr = "ERROR: [Errno 1] Operation not permitted: '/Users/x/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies'";
        assert!(permission_denied(stderr));
        assert!(!permission_denied("ERROR: failed to decrypt cookie (AES-GCM)"));
    }

    #[test]
    fn sin_sapisid_no_hay_sesion() {
        assert!(session_from(".youtube.com\tTRUE\t/\tTRUE\t1\tPREF\tx\n").is_none());
    }

    #[test]
    fn la_firma_tiene_el_formato_de_google() {
        let session = session_from(SAMPLE).unwrap();
        let (_, authorization) = session.headers();
        let (stamp, hash) = authorization.strip_prefix("SAPISIDHASH ").unwrap().split_once('_').unwrap();
        assert!(stamp.parse::<u64>().is_ok());
        assert_eq!(hash.len(), 40);
    }
}
