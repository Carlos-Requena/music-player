//! Plugins: controles multimedia del sistema, Discord Rich Presence y Last.fm.
//!
//! El reproductor avisa de lo que pasa con `emit(Event)`; un hilo propio reparte los
//! eventos a Discord y Last.fm, que hablan con la red y nunca deben frenar la interfaz.
//! Los controles del sistema viven en el reproductor (en macOS deben estar en el hilo
//! principal) y usan `media_enabled`.
//!
//! La configuración (incluido el secreto y la sesión de Last.fm) se guarda en
//! `<config>/musicplayer/plugins.json`, legible solo por el usuario.

mod discord;
mod lastfm;

use std::{
    fs,
    path::PathBuf,
    pin::Pin,
    process::Command,
    sync::{mpsc, LazyLock, Mutex},
    thread,
};

use cxx_qt::{CxxQtThread, Threading};
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
        #[qproperty(bool, media_on)]
        #[qproperty(bool, discord_on)]
        #[qproperty(QString, discord_id)]
        #[qproperty(QString, discord_status)]
        /// La app trae su propio Application ID de Discord (no hace falta configurar nada).
        #[qproperty(bool, discord_builtin)]
        #[qproperty(bool, lastfm_on)]
        #[qproperty(QString, lastfm_key)]
        #[qproperty(QString, lastfm_user)]
        #[qproperty(QString, lastfm_status)]
        /// Hay un token esperando a que el usuario lo autorice en el navegador.
        #[qproperty(bool, lastfm_pending)]
        type Plugins = super::PluginsRust;

        /// Arranca el hilo de los plugins (una vez, al abrir la app).
        #[qinvokable]
        fn start(self: Pin<&mut Plugins>);

        #[qinvokable]
        fn set_media(self: Pin<&mut Plugins>, on: bool);

        #[qinvokable]
        fn set_discord(self: Pin<&mut Plugins>, on: bool, client_id: &QString);

        /// Guarda la clave y el secreto de la API de Last.fm.
        #[qinvokable]
        fn set_lastfm_keys(self: Pin<&mut Plugins>, key: &QString, secret: &QString);

        #[qinvokable]
        fn set_lastfm(self: Pin<&mut Plugins>, on: bool);

        /// Pide un token y abre el navegador para autorizar la app en Last.fm.
        #[qinvokable]
        fn lastfm_connect(self: Pin<&mut Plugins>);

        /// Completa la autorización tras aceptarla en el navegador.
        #[qinvokable]
        fn lastfm_finish(self: Pin<&mut Plugins>);

        #[qinvokable]
        fn lastfm_disconnect(self: Pin<&mut Plugins>);
    }

    impl cxx_qt::Threading for Plugins {}
}

/// Pista tal como la ven los plugins.
#[derive(Clone, Debug, Default)]
pub struct Track {
    pub title: String,
    pub artist: String,
    pub thumb: String,
    pub duration: f64,
}

/// Lo que el reproductor cuenta a los plugins.
pub enum Event {
    /// Empieza a sonar una pista nueva.
    Track(Track),
    /// Reanuda (`true`) o pausa, con la posición en segundos.
    Playing(bool, f64),
    Position(f64),
    Stopped,
    /// Cambió la configuración: el hilo vuelve a leerla.
    Reload,
}

/// Application ID de Discord incluido en la app (la aplicación «Reproductor de música» del
/// propietario del proyecto). Se puede sustituir al compilar con `MUSICPLAYER_DISCORD_ID`
/// (ver COMPILAR.md) y el usuario puede usar otro en Opciones.
const BUILTIN_DISCORD_ID: &str = match option_env!("MUSICPLAYER_DISCORD_ID") {
    Some(id) => id,
    None => "1570826346035281922",
};

#[derive(Clone, Default, Serialize, Deserialize)]
#[serde(default)]
struct Config {
    media: Option<bool>,
    /// Activado por defecto: se conecta solo en cuanto Discord está abierto.
    discord: Option<bool>,
    discord_id: String,
    lastfm: bool,
    lastfm_key: String,
    lastfm_secret: String,
    lastfm_session: String,
    lastfm_user: String,
}

impl Config {
    fn media_on(&self) -> bool {
        self.media.unwrap_or(true)
    }

    fn discord_on(&self) -> bool {
        self.discord.unwrap_or(true)
    }

    /// El ID propio del usuario si lo puso; si no, el incluido en la app.
    fn discord_app(&self) -> String {
        let own = self.discord_id.trim();
        if own.is_empty() { BUILTIN_DISCORD_ID.to_owned() } else { own.to_owned() }
    }
}

fn config_path() -> Option<PathBuf> {
    dirs::config_dir().map(|dir| dir.join("musicplayer").join("plugins.json"))
}

fn load_config() -> Config {
    config_path()
        .and_then(|path| fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default()
}

static CONFIG: LazyLock<Mutex<Config>> = LazyLock::new(|| Mutex::new(load_config()));
static SENDER: LazyLock<Mutex<Option<mpsc::Sender<Event>>>> = LazyLock::new(Default::default);

fn config() -> Config {
    CONFIG.lock().map(|config| config.clone()).unwrap_or_default()
}

fn save_config(config: &Config) {
    let Some(path) = config_path() else { return };
    if let Some(dir) = path.parent() {
        let _ = fs::create_dir_all(dir);
    }
    if let Ok(text) = serde_json::to_string_pretty(config) {
        if fs::write(&path, text).is_ok() {
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
            }
        }
    }
}

fn update(change: impl FnOnce(&mut Config)) {
    if let Ok(mut current) = CONFIG.lock() {
        change(&mut current);
        save_config(&current);
    }
    emit(Event::Reload);
}

/// ¿Están activados los controles multimedia del sistema?
pub fn media_enabled() -> bool {
    config().media_on()
}

/// Avisa a los plugins (no bloquea).
pub fn emit(event: Event) {
    if let Ok(sender) = SENDER.lock() {
        if let Some(sender) = sender.as_ref() {
            let _ = sender.send(event);
        }
    }
}

fn open_browser(url: &str) {
    let opener = if cfg!(target_os = "macos") { "open" } else { "xdg-open" };
    let _ = Command::new(opener).arg(url).spawn();
}

/// Hilo de Discord y Last.fm.
fn worker(events: mpsc::Receiver<Event>, qt: CxxQtThread<qobject::Plugins>) {
    let mut settings = config();
    let mut discord: Option<discord::Discord> = None;
    let mut scrobbler: Option<lastfm::Scrobbler> = None;
    let mut current: Option<Track> = None;
    let mut playing = false;
    let mut position = 0.0;
    // Último intento de conectar con Discord sin éxito, para reintentar cada cierto tiempo
    // (Discord puede abrirse con la canción ya sonando).
    let mut last_attempt: Option<std::time::Instant> = None;

    let status = |qt: &CxxQtThread<qobject::Plugins>, discord_text: Option<String>, lastfm_text: Option<String>| {
        let _ = qt.queue(move |mut plugins| {
            if let Some(text) = discord_text {
                plugins.as_mut().set_discord_status(QString::from(&text));
            }
            if let Some(text) = lastfm_text {
                plugins.as_mut().set_lastfm_status(QString::from(&text));
            }
        });
    };

    for event in events {
        // Aplica la configuración vigente (también tras `Reload`).
        if matches!(event, Event::Reload) {
            settings = config();
        }
        let app = settings.discord_app();
        if settings.discord_on() && !app.is_empty() {
            if discord.as_ref().map(|d| d.client_id() != app) != Some(false) {
                discord = Some(discord::Discord::new(&app));
                last_attempt = None;
            }
        } else if discord.take().is_some() {
            status(&qt, Some(String::new()), None);
        }
        if settings.lastfm && !settings.lastfm_session.is_empty() {
            if scrobbler.as_ref().map(|s| s.session != settings.lastfm_session) != Some(false) {
                scrobbler = Some(lastfm::Scrobbler::new(
                    settings.lastfm_key.clone(),
                    settings.lastfm_secret.clone(),
                    settings.lastfm_session.clone(),
                ));
            }
        } else {
            scrobbler = None;
        }

        let mut discord_update: Option<Option<serde_json::Value>> = None;
        match event {
            Event::Track(track) => {
                playing = true;
                position = 0.0;
                if let Some(scrobbler) = scrobbler.as_mut() {
                    let result = scrobbler.start(&track);
                    status(&qt, None, Some(match result {
                        Ok(()) => format!("Escuchando ahora: {} — {}", track.title, track.artist),
                        Err(error) => error,
                    }));
                }
                discord_update = Some(Some(discord::activity(&track, 0.0)));
                current = Some(track);
            }
            Event::Playing(now_playing, at) => {
                playing = now_playing;
                position = at;
                discord_update = Some(match (&current, playing) {
                    (Some(track), true) => Some(discord::activity(track, position)),
                    _ => None,
                });
            }
            Event::Position(at) => {
                position = at;
                let retry = last_attempt.is_some_and(|at| at.elapsed() >= std::time::Duration::from_secs(20));
                if retry && playing && discord.as_ref().is_some_and(|d| !d.connected()) {
                    if let Some(track) = &current {
                        discord_update = Some(Some(discord::activity(track, position)));
                    }
                }
                if let Some(scrobbler) = scrobbler.as_mut() {
                    match scrobbler.progress(position, playing) {
                        Ok(true) => {
                            let title = current.as_ref().map(|t| t.title.clone()).unwrap_or_default();
                            status(&qt, None, Some(format!("Scrobble enviado: {title}")));
                        }
                        Ok(false) => {}
                        Err(error) => status(&qt, None, Some(error)),
                    }
                }
            }
            Event::Stopped => {
                playing = false;
                current = None;
                discord_update = Some(None);
            }
            Event::Reload => {
                discord_update = Some(match (&current, playing) {
                    (Some(track), true) => Some(discord::activity(track, position)),
                    _ => None,
                });
            }
        }

        if let (Some(activity), Some(discord)) = (discord_update, discord.as_mut()) {
            let result = discord.set_activity(activity);
            last_attempt = if result.is_err() { Some(std::time::Instant::now()) } else { None };
            status(&qt, Some(match result {
                Ok(()) => "Conectado a Discord.".to_owned(),
                Err(error) => error,
            }), None);
        }
    }
}

pub struct PluginsRust {
    media_on: bool,
    discord_on: bool,
    discord_id: QString,
    discord_status: QString,
    discord_builtin: bool,
    lastfm_on: bool,
    lastfm_key: QString,
    lastfm_user: QString,
    lastfm_status: QString,
    lastfm_pending: bool,
    /// Token de Last.fm a la espera de autorización.
    token: String,
}

impl Default for PluginsRust {
    fn default() -> Self {
        let config = config();
        Self {
            media_on: config.media_on(),
            discord_on: config.discord_on(),
            discord_id: QString::from(&config.discord_id),
            discord_status: QString::default(),
            discord_builtin: !BUILTIN_DISCORD_ID.is_empty(),
            lastfm_on: config.lastfm,
            lastfm_key: QString::from(&config.lastfm_key),
            lastfm_user: QString::from(&config.lastfm_user),
            lastfm_status: QString::default(),
            lastfm_pending: false,
            token: String::new(),
        }
    }
}

impl qobject::Plugins {
    fn start(self: Pin<&mut Self>) {
        let Ok(mut sender) = SENDER.lock() else { return };
        if sender.is_some() {
            return;
        }
        let (tx, rx) = mpsc::channel();
        *sender = Some(tx);
        let qt = self.qt_thread();
        thread::spawn(move || worker(rx, qt));
    }

    fn set_media(mut self: Pin<&mut Self>, on: bool) {
        update(|config| config.media = Some(on));
        self.as_mut().set_media_on(on);
    }

    fn set_discord(mut self: Pin<&mut Self>, on: bool, client_id: &QString) {
        let id = client_id.to_string().trim().to_owned();
        update(|config| {
            config.discord = Some(on);
            config.discord_id = id.clone();
        });
        self.as_mut().set_discord_id(QString::from(&id));
        self.as_mut().set_discord_on(on);
        if on && id.is_empty() && BUILTIN_DISCORD_ID.is_empty() {
            self.as_mut().set_discord_status(QString::from("Esta compilación no incluye ID de Discord: pega el de tu aplicación."));
        } else if on {
            self.as_mut().set_discord_status(QString::from("Se conectará solo en cuanto Discord esté abierto."));
        }
    }

    fn set_lastfm_keys(mut self: Pin<&mut Self>, key: &QString, secret: &QString) {
        let key = key.to_string().trim().to_owned();
        let secret = secret.to_string().trim().to_owned();
        update(|config| {
            config.lastfm_key = key.clone();
            if !secret.is_empty() {
                config.lastfm_secret = secret.clone();
            }
        });
        self.as_mut().set_lastfm_key(QString::from(&key));
    }

    fn set_lastfm(mut self: Pin<&mut Self>, on: bool) {
        update(|config| config.lastfm = on);
        self.as_mut().set_lastfm_on(on);
    }

    fn lastfm_connect(mut self: Pin<&mut Self>) {
        let settings = config();
        if settings.lastfm_key.is_empty() || settings.lastfm_secret.is_empty() {
            self.as_mut().set_lastfm_status(QString::from("Primero pega la clave de API y el secreto."));
            return;
        }
        self.as_mut().set_lastfm_status(QString::from("Pidiendo permiso a Last.fm…"));
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = lastfm::begin_auth(&settings.lastfm_key, &settings.lastfm_secret);
            let _ = qt.queue(move |mut plugins| match result {
                Ok((token, url)) => {
                    open_browser(&url);
                    plugins.as_mut().rust_mut_token(token);
                    plugins.as_mut().set_lastfm_pending(true);
                    plugins.as_mut().set_lastfm_status(QString::from(
                        "Se ha abierto Last.fm en el navegador: pulsa «Sí, permitir acceso» y vuelve aquí.",
                    ));
                }
                Err(error) => plugins.as_mut().set_lastfm_status(QString::from(&error)),
            });
        });
    }

    fn lastfm_finish(mut self: Pin<&mut Self>) {
        use cxx_qt::CxxQtType;
        let settings = config();
        let token = self.as_mut().rust_mut().token.clone();
        if token.is_empty() {
            return;
        }
        self.as_mut().set_lastfm_status(QString::from("Comprobando la autorización…"));
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = lastfm::finish_auth(&settings.lastfm_key, &settings.lastfm_secret, &token);
            let _ = qt.queue(move |mut plugins| match result {
                Ok((session, user)) => {
                    update(|config| {
                        config.lastfm_session = session;
                        config.lastfm_user = user.clone();
                        config.lastfm = true;
                    });
                    plugins.as_mut().rust_mut_token(String::new());
                    plugins.as_mut().set_lastfm_pending(false);
                    plugins.as_mut().set_lastfm_user(QString::from(&user));
                    plugins.as_mut().set_lastfm_on(true);
                    plugins.as_mut().set_lastfm_status(QString::from(&format!("Conectado como {user}.")));
                }
                Err(error) => plugins.as_mut().set_lastfm_status(QString::from(&error)),
            });
        });
    }

    fn lastfm_disconnect(mut self: Pin<&mut Self>) {
        update(|config| {
            config.lastfm_session.clear();
            config.lastfm_user.clear();
            config.lastfm = false;
        });
        self.as_mut().set_lastfm_user(QString::default());
        self.as_mut().set_lastfm_on(false);
        self.as_mut().set_lastfm_pending(false);
        self.as_mut().set_lastfm_status(QString::default());
    }

    fn rust_mut_token(self: Pin<&mut Self>, token: String) {
        use cxx_qt::CxxQtType;
        self.rust_mut().get_mut().token = token;
    }
}
