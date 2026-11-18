//! Reproductor expuesto a QML como singleton `Player`.
//!
//! Mantiene la cola, ordena a mpv qué cargar y publica el estado (posición, pista
//! actual, letra) como propiedades. La red y mpv trabajan en hilos propios y
//! devuelven sus resultados al hilo de Qt con `qt_thread().queue`.

use std::{
    collections::{HashMap, HashSet, VecDeque},
    pin::Pin,
    sync::{Condvar, LazyLock, Mutex},
    thread,
    time::Instant,
};

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;
use serde::Deserialize;

use crate::{
    audio::{Event, Mpv},
    history, lyrics, plugins, resolver,
    ytm::{self, Item, Track},
};

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
        #[qproperty(bool, playing)]
        #[qproperty(bool, loading)]
        #[qproperty(f64, position)]
        #[qproperty(f64, duration)]
        #[qproperty(QString, title)]
        #[qproperty(QString, artist)]
        #[qproperty(QString, thumb)]
        #[qproperty(i32, index)]
        #[qproperty(QString, queue)]
        /// Letras encontradas para la pista que suena, de mejor a peor (JSON de
        /// `[lyrics::Found]`): la interfaz elige cuál mostrar.
        #[qproperty(QString, lyrics)]
        #[qproperty(QString, error)]
        #[qproperty(f64, volume)]
        /// Formato real de lo que suena, p. ej. «Opus · 152 kbps».
        #[qproperty(QString, calidad)]
        /// Al acabar la cola vuelve a empezar.
        #[qproperty(bool, repetir)]
        /// Repite la canción que suena (mpv `loop-file`).
        #[qproperty(bool, repetir_una)]
        /// Lista temporal (JSON de `[ytm::Track]`): canciones sueltas reunidas a mano.
        #[qproperty(QString, temporal)]
        type Player = super::PlayerRust;

        /// Reproduce un elemento del catálogo (JSON de `ytm::Item`): una canción con
        /// su radio, o un álbum o playlist completos.
        #[qinvokable]
        fn play_item(self: Pin<&mut Player>, item: &QString);

        /// Reproduce una lista de pistas (JSON de `[ytm::Track]`) desde `index`; con
        /// `shuffle` la baraja antes y empieza por la primera.
        #[qinvokable]
        fn play_tracks(self: Pin<&mut Player>, tracks: &QString, index: i32, shuffle: bool);

        /// Salta a la pista `index` de la cola.
        #[qinvokable]
        fn play_index(self: Pin<&mut Player>, index: i32);

        /// Alterna reproducción y pausa.
        #[qinvokable]
        fn toggle(self: Pin<&mut Player>);

        /// Salta a la pista siguiente de la cola (lo pide el usuario: termina con `saltada`).
        #[qinvokable]
        fn next(self: Pin<&mut Player>);

        /// El usuario ha pasado a la siguiente (no cuando una pista termina sola).
        #[qsignal]
        fn saltada(self: Pin<&mut Player>);

        /// Vuelve al inicio de la pista o a la anterior si acaba de empezar.
        #[qinvokable]
        fn previous(self: Pin<&mut Player>);

        /// Mueve la posición a `seconds`.
        #[qinvokable]
        fn seek(self: Pin<&mut Player>, seconds: f64);

        /// Prepara un elemento para que suene al instante si se elige: resuelve su
        /// audio (y, si es un álbum o playlist, su cola) en segundo plano.
        #[qinvokable]
        fn prefetch_item(self: &Player, item: &QString);

        /// Arranca el motor de audio antes del primer clic.
        #[qinvokable]
        fn warm_up(self: Pin<&mut Player>);

        /// Activa o desactiva los controles multimedia del sistema según los plugins.
        #[qinvokable]
        fn apply_media_controls(self: Pin<&mut Player>);

        /// Reinicia el motor de audio (p. ej. tras iniciar o cerrar sesión, para que el
        /// gancho de yt-dlp de mpv use las cookies nuevas). Corta lo que esté sonando.
        #[qinvokable]
        fn restart_engine(self: Pin<&mut Player>);

        /// Vuelve a aplicar el ecualizador y el amplificador (tras cambiarlos en Opciones).
        #[qinvokable]
        fn apply_effects(self: Pin<&mut Player>);

        /// Cambia el volumen (0–100).
        #[qinvokable]
        fn change_volume(self: Pin<&mut Player>, volume: f64);

        /// Resuelve de antemano las primeras `count` pistas de una lista (JSON de
        /// `[ytm::Track]` o de `[ytm::Item]`), para que suenen al instante al elegirlas.
        #[qinvokable]
        fn prefetch_tracks(self: &Player, tracks: &QString, count: i32);

        /// Añade a la lista temporal una canción, o todas las de un álbum o playlist
        /// (JSON de `ytm::Item` o de `ytm::Track`).
        #[qinvokable]
        fn add_to_temporal(self: Pin<&mut Player>, item: &QString);

        /// Quita de la lista temporal la pista `index`.
        #[qinvokable]
        fn remove_from_temporal(self: Pin<&mut Player>, index: i32);

        /// Vacía la lista temporal.
        #[qinvokable]
        fn clear_temporal(self: Pin<&mut Player>);

        /// Pasa al siguiente modo de repetición, como en cualquier reproductor:
        /// desactivada → repetir la cola → repetir la canción → desactivada.
        #[qinvokable]
        fn cycle_repeat(self: Pin<&mut Player>);

        /// Reproduce la lista temporal desde `index`, en bucle.
        #[qinvokable]
        fn play_temporal(self: Pin<&mut Player>, index: i32);

        /// Pone una canción, o todas las de un álbum o playlist, justo detrás de la que suena
        /// (con `next`) o al final de la cola. Sin nada sonando, empiezan a sonar.
        #[qinvokable]
        fn enqueue(self: Pin<&mut Player>, item: &QString, next: bool);

        /// Mueve la pista `from` de la cola a la posición `to`; la que suena sigue sonando.
        #[qinvokable]
        fn move_in_queue(self: Pin<&mut Player>, from: i32, to: i32);

        /// Quita de la cola la pista `index` (no la que suena).
        #[qinvokable]
        fn remove_from_queue(self: Pin<&mut Player>, index: i32);

        /// Baraja las pistas que quedan detrás de la que suena; la que suena sigue sonando.
        #[qinvokable]
        fn shuffle_queue(self: Pin<&mut Player>);
    }

    impl cxx_qt::Threading for Player {}
}

pub struct PlayerRust {
    playing: bool,
    loading: bool,
    position: f64,
    duration: f64,
    title: QString,
    artist: QString,
    thumb: QString,
    index: i32,
    queue: QString,
    lyrics: QString,
    error: QString,
    volume: f64,

    /// Letras que han llegado para la pista que suena (cada fuente responde por su cuenta).
    lyrics_found: Vec<lyrics::Found>,
    /// Cambia con cada petición de letra; descarta las respuestas de la anterior.
    lyrics_token: u64,
    /// La próxima carga no pide la letra: la pedirá la cola al llegar, con el artista limpio y la
    /// duración (ver `play_item`).
    defer_lyrics: bool,

    mpv: Option<Mpv>,
    tracks: Vec<Track>,
    /// Cambia con cada petición de reproducción; descarta respuestas de red obsoletas.
    request: u64,
    /// Pista que ya se reintentó tras un fallo, para no reintentar en bucle.
    retried: Option<usize>,
    /// Cambia con cada carga; descarta resoluciones que llegan para una pista anterior.
    load_token: u64,
    /// Momento del último clic o salto, para medir cuánto tarda en sonar.
    load_started: Option<Instant>,
    /// La carga en curso usa una URL ya resuelta (no el gancho de yt-dlp de mpv).
    via_stream: bool,
    /// Controles multimedia del sistema (Centro de control / MPRIS).
    media: Option<souvlaki::MediaControls>,
    /// Ya se avisó a los plugins de la pista que se está cargando.
    announced: bool,
    /// Última pausa que informó mpv.
    mpv_paused: bool,
    calidad: QString,
    codec: String,
    kbps: f64,
    repetir: bool,
    repetir_una: bool,
    temporal: QString,
    /// Pistas de la lista temporal (`temporal` es su JSON).
    temporal_tracks: Vec<Track>,
    /// Escucha que se está registrando en la cuenta (opción `historial`).
    listen: Option<Listen>,
}

/// Escucha en curso que se registra en la cuenta. Los tramos escuchados se envían cada 30 s,
/// al pausar, al saltar a otro punto y al cambiar de pista.
struct Listen {
    /// `load_token` de la carga a la que pertenece.
    token: u64,
    /// Llega del hilo de red poco después de empezar a sonar.
    report: Option<history::Report>,
    /// Inicio del tramo aún sin enviar.
    from: f64,
    /// Última posición conocida.
    last: f64,
}

/// Pista a partir del JSON de una tarjeta del catálogo (`Item`) o de una pista (`Track`).
/// `None` si no es una canción (álbum, playlist…).
fn track_from(value: &serde_json::Value) -> Option<Track> {
    if value.get("artist").is_some() {
        return Track::deserialize(value).ok().filter(|track| !track.video_id.is_empty());
    }
    let item = Item::deserialize(value).ok()?;
    (!item.video_id.is_empty()).then(|| Track {
        artist: artist_from_subtitle(&item.subtitle),
        title: item.title,
        thumb: item.thumb,
        video_id: item.video_id,
        duration: 0.0,
    })
}

/// Artista a partir del subtítulo de una tarjeta: «Quevedo • 75 M reproducciones» o
/// «Canción • Vetusta Morla • Álbum • 3:27» → el nombre del artista.
fn artist_from_subtitle(subtitle: &str) -> String {
    const KINDS: &[&str] = &["Canción", "Vídeo", "Video", "Song", "Episodio", "Single", "Álbum", "Album", "EP"];
    subtitle
        .split(" • ")
        .map(str::trim)
        .find(|part| !part.is_empty() && !KINDS.contains(part))
        .unwrap_or_default()
        .to_owned()
}

/// Baraja con Fisher–Yates; la semilla sale del reloj, basta para música.
fn shuffle_tracks(tracks: &mut [Track]) {
    let mut seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0x9E37_79B9_7F4A_7C15, |d| d.as_nanos() as u64)
        | 1;
    for i in (1..tracks.len()).rev() {
        // xorshift64*
        seed ^= seed >> 12;
        seed ^= seed << 25;
        seed ^= seed >> 27;
        let j = (seed.wrapping_mul(0x2545_F491_4F6C_DD1D) % (i as u64 + 1)) as usize;
        tracks.swap(i, j);
    }
}

/// Colas de álbumes y playlists ya descargadas (las últimas `QUEUE_LIMIT`) y las que se están
/// descargando ahora.
#[derive(Default)]
struct Queues {
    lists: HashMap<String, Vec<Track>>,
    /// Orden de uso, de la más antigua a la más reciente.
    order: VecDeque<String>,
    loading: HashSet<String>,
}

/// Colas guardadas como mucho: recorrer la estantería precarga una por álbum.
const QUEUE_LIMIT: usize = 24;

static QUEUES: LazyLock<(Mutex<Queues>, Condvar)> = LazyLock::new(Default::default);

fn cached_queue(playlist_id: &str) -> Option<Vec<Track>> {
    QUEUES.0.lock().ok()?.lists.get(playlist_id).cloned()
}

/// Olvida la cola guardada de una playlist (p. ej. tras añadirle canciones).
pub fn forget_queue(playlist_id: &str) {
    if let Ok(mut queues) = QUEUES.0.lock() {
        queues.lists.remove(playlist_id);
        queues.order.retain(|id| id != playlist_id);
    }
}

/// Cola de un álbum o playlist, desde la caché o la red. Si ya se está descargando (una
/// precarga), espera a esa descarga en vez de empezar otra.
fn album_queue(playlist_id: &str) -> ytm::Result<Vec<Track>> {
    let (lock, signal) = &*QUEUES;
    {
        let mut queues = lock.lock().map_err(|_| "colas envenenadas".to_owned())?;
        loop {
            if let Some(tracks) = queues.lists.get(playlist_id) {
                return Ok(tracks.clone());
            }
            if !queues.loading.contains(playlist_id) {
                break;
            }
            queues = signal.wait(queues).map_err(|_| "colas envenenadas".to_owned())?;
        }
        queues.loading.insert(playlist_id.to_owned());
    }
    // La lista real del álbum o playlist; si YouTube no la da, la cola de reproducción.
    let result = match ytm::playlist_tracks(playlist_id) {
        Ok(tracks) if !tracks.is_empty() => Ok(tracks),
        _ => ytm::queue("", playlist_id),
    };
    if let Ok(mut queues) = lock.lock() {
        queues.loading.remove(playlist_id);
        if let Ok(tracks) = &result {
            queues.lists.insert(playlist_id.to_owned(), tracks.clone());
            queues.order.retain(|id| id != playlist_id);
            queues.order.push_back(playlist_id.to_owned());
            while queues.order.len() > QUEUE_LIMIT {
                if let Some(oldest) = queues.order.pop_front() {
                    queues.lists.remove(&oldest);
                }
            }
        }
    }
    signal.notify_all();
    result
}

/// Álbum o playlist cuya primera pista se precarga (solo cuenta el último pedido) y si hay un
/// hilo atendiéndolos. Como `resolver::hint`: pasar el ratón por veinte álbumes no lanza veinte
/// descargas de su lista, se descarga la del último.
static WANTED_LIST: LazyLock<Mutex<(Option<String>, bool)>> = LazyLock::new(Default::default);

fn hint_list(playlist_id: &str) {
    if let Some(first) = cached_queue(playlist_id).and_then(|tracks| tracks.into_iter().next()) {
        resolver::hint(&first.video_id);
        return;
    }
    let Ok(mut wanted) = WANTED_LIST.lock() else { return };
    wanted.0 = Some(playlist_id.to_owned());
    if wanted.1 {
        return;
    }
    wanted.1 = true;
    thread::spawn(|| loop {
        let next = match WANTED_LIST.lock() {
            Ok(mut wanted) => match wanted.0.take() {
                Some(id) => id,
                None => {
                    wanted.1 = false;
                    return;
                }
            },
            Err(_) => return,
        };
        if let Some(first) = album_queue(&next).ok().and_then(|tracks| tracks.into_iter().next()) {
            resolver::hint(&first.video_id);
        }
    });
}

impl Default for PlayerRust {
    fn default() -> Self {
        Self {
            playing: false,
            loading: false,
            position: 0.0,
            duration: 0.0,
            title: QString::default(),
            artist: QString::default(),
            thumb: QString::default(),
            index: 0,
            queue: QString::default(),
            lyrics: QString::default(),
            error: QString::default(),
            volume: 100.0,
            lyrics_found: Vec::new(),
            lyrics_token: 0,
            defer_lyrics: false,
            mpv: None,
            tracks: Vec::new(),
            request: 0,
            retried: None,
            load_token: 0,
            load_started: None,
            via_stream: false,
            media: None,
            announced: false,
            mpv_paused: false,
            calidad: QString::default(),
            codec: String::new(),
            kbps: 0.0,
            repetir: false,
            repetir_una: false,
            temporal: QString::from("[]"),
            temporal_tracks: Vec::new(),
            listen: None,
        }
    }
}

impl qobject::Player {
    fn play_item(mut self: Pin<&mut Self>, item: &QString) {
        let Ok(item) = serde_json::from_str::<Item>(&item.to_string()) else { return };
        if item.video_id.is_empty() && item.playlist_id.is_empty() {
            return;
        }

        let request = self.as_mut().new_request();

        // Una canción empieza a sonar ya; su cola (la radio) llega después.
        let started = !item.video_id.is_empty();
        if !started {
            if let Some(tracks) = cached_queue(&item.playlist_id) {
                self.as_mut().set_tracks(tracks);
                self.load(0);
                return;
            }
        }
        if started {
            let track = Track {
                title: item.title.clone(),
                artist: artist_from_subtitle(&item.subtitle),
                thumb: item.thumb.clone(),
                video_id: item.video_id.clone(),
                duration: 0.0,
            };
            self.as_mut().set_tracks(vec![track]);
            // La letra se pide una sola vez, cuando llega la cola (unas décimas después): la
            // tarjeta no trae la duración ni el artista limpio, y pedirla dos veces repetía las
            // búsquedas y rehacía la letra en pantalla.
            self.as_mut().rust_mut().defer_lyrics = true;
            self.as_mut().load(0);
        } else {
            self.as_mut().set_loading(true);
        }

        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = if started {
                ytm::queue(&item.video_id, &item.playlist_id)
            } else {
                album_queue(&item.playlist_id)
            };
            let _ = qt.queue(move |mut player| {
                if player.request != request {
                    return;
                }
                match result {
                    Ok(tracks) if !tracks.is_empty() => player.as_mut().adopt_queue(tracks, started),
                    Ok(_) if !started => player.as_mut().fail("No se encontraron canciones."),
                    Err(error) if !started => player.as_mut().fail(&error),
                    // La canción ya suena: quedarse sin radio no es un error visible. La letra se
                    // pide con lo que se sabe de la tarjeta.
                    _ => {
                        if let Some(track) = player.tracks.first().cloned() {
                            player.as_mut().fetch_lyrics(track);
                        }
                    }
                }
            });
        });
    }

    fn play_tracks(mut self: Pin<&mut Self>, tracks: &QString, index: i32, shuffle: bool) {
        let Ok(mut tracks) = serde_json::from_str::<Vec<Track>>(&tracks.to_string()) else { return };
        if tracks.is_empty() {
            return;
        }
        let mut start = (index.max(0) as usize).min(tracks.len() - 1);
        if shuffle {
            shuffle_tracks(&mut tracks);
            start = 0;
        }
        self.as_mut().new_request();
        self.as_mut().set_tracks(tracks);
        self.load(start);
    }

    fn play_index(self: Pin<&mut Self>, index: i32) {
        if index >= 0 && (index as usize) < self.tracks.len() {
            self.load(index as usize);
        }
    }

    fn toggle(mut self: Pin<&mut Self>) {
        let paused = *self.playing();
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.set_pause(paused);
        }
    }

    fn next(mut self: Pin<&mut Self>) {
        if self.as_mut().advance() {
            self.saltada();
        }
    }

    /// Carga la pista siguiente (o la primera si se repite la cola); `false` si no hay.
    fn advance(self: Pin<&mut Self>) -> bool {
        let next = *self.index() as usize + 1;
        if next < self.tracks.len() {
            self.load(next);
        } else if *self.repetir() && !self.tracks.is_empty() {
            self.load(0);
        } else {
            return false;
        }
        true
    }

    fn previous(mut self: Pin<&mut Self>) {
        if *self.position() > 3.0 || *self.index() == 0 {
            self.as_mut().seek(0.0);
        } else {
            let previous = *self.index() as usize - 1;
            self.load(previous);
        }
    }

    fn seek(mut self: Pin<&mut Self>, seconds: f64) {
        let target = seconds.clamp(0.0, *self.duration());
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.seek(target);
        }
        self.as_mut().set_position(target);
    }

    fn prefetch_item(&self, item: &QString) {
        let Ok(item) = serde_json::from_str::<Item>(&item.to_string()) else { return };
        if !item.video_id.is_empty() {
            resolver::hint(&item.video_id);
        } else if !item.playlist_id.is_empty() {
            hint_list(&item.playlist_id);
        }
    }

    fn warm_up(mut self: Pin<&mut Self>) {
        self.as_mut().apply_media_controls();
        self.ensure_engine();
    }

    fn apply_media_controls(mut self: Pin<&mut Self>) {
        if !plugins::media_enabled() {
            // Al soltarlos, souvlaki los desengancha del sistema.
            self.as_mut().rust_mut().media = None;
            return;
        }
        if self.media.is_some() {
            return;
        }
        let config = souvlaki::PlatformConfig {
            display_name: "Reproductor de música",
            dbus_name: "musicplayer",
            hwnd: None,
        };
        let Ok(mut controls) = souvlaki::MediaControls::new(config) else {
            eprintln!("no se pudieron crear los controles multimedia del sistema");
            return;
        };
        let qt = self.qt_thread();
        let attached = controls.attach(move |event| {
            let _ = qt.queue(move |player| player.on_media_command(event));
        });
        if attached.is_ok() {
            self.as_mut().rust_mut().media = Some(controls);
            self.publish_media();
        }
    }

    /// Órdenes del sistema: teclas multimedia, Centro de control, MPRIS.
    fn on_media_command(self: Pin<&mut Self>, event: souvlaki::MediaControlEvent) {
        use souvlaki::{MediaControlEvent as Command, SeekDirection};
        let position = *self.position();
        match event {
            Command::Play if !*self.playing() => self.toggle(),
            Command::Pause if *self.playing() => self.toggle(),
            Command::Toggle => self.toggle(),
            Command::Next => self.next(),
            Command::Previous => self.previous(),
            Command::SetPosition(souvlaki::MediaPosition(at)) => self.seek(at.as_secs_f64()),
            Command::SeekBy(direction, by) => {
                let delta = by.as_secs_f64();
                self.seek(if direction == SeekDirection::Forward { position + delta } else { position - delta });
            }
            Command::Seek(direction) => {
                self.seek(if direction == SeekDirection::Forward { position + 10.0 } else { position - 10.0 });
            }
            Command::Stop if *self.playing() => self.toggle(),
            _ => {}
        }
    }

    fn update_quality(self: Pin<&mut Self>) {
        let codec = match self.codec.as_str() {
            "opus" => "Opus".to_owned(),
            "aac" => "AAC".to_owned(),
            "" => String::new(),
            other => other.to_uppercase(),
        };
        let text = match (codec.is_empty(), self.kbps > 0.0) {
            (false, true) => format!("{codec} · {} kbps", self.kbps),
            (false, false) => codec,
            _ => String::new(),
        };
        self.set_calidad(QString::from(&text));
    }

    /// Publica en el sistema la pista y el estado actuales.
    fn publish_media(mut self: Pin<&mut Self>) {
        let title = self.title().to_string();
        let artist = self.artist().to_string();
        let thumb = self.thumb().to_string();
        let duration = *self.duration();
        let position = std::time::Duration::from_secs_f64(self.position().max(0.0));
        let playing = *self.playing();
        let mut rust = self.as_mut().rust_mut();
        let Some(media) = rust.media.as_mut() else { return };
        if title.is_empty() {
            let _ = media.set_playback(souvlaki::MediaPlayback::Stopped);
            return;
        }
        let _ = media.set_metadata(souvlaki::MediaMetadata {
            title: Some(&title),
            artist: Some(&artist),
            album: None,
            cover_url: (!thumb.is_empty()).then_some(thumb.as_str()),
            duration: (duration > 0.0).then(|| std::time::Duration::from_secs_f64(duration)),
        });
        let progress = Some(souvlaki::MediaPosition(position));
        let _ = media.set_playback(if playing {
            souvlaki::MediaPlayback::Playing { progress }
        } else {
            souvlaki::MediaPlayback::Paused { progress }
        });
    }

    /// Avisa a los plugins y al sistema de que empieza una pista o se reanuda tras un salto.
    fn announce(mut self: Pin<&mut Self>) {
        if !self.announced {
            self.as_mut().rust_mut().announced = true;
            let index = *self.index() as usize;
            let video_id = self.tracks.get(index).map(|track| track.video_id.clone()).unwrap_or_default();
            plugins::emit(plugins::Event::Track(plugins::Track {
                title: self.title().to_string(),
                artist: self.artist().to_string(),
                thumb: self.thumb().to_string(),
                video_id,
                duration: *self.duration(),
            }));
        } else {
            plugins::emit(plugins::Event::Playing(*self.playing(), *self.position()));
        }
        self.publish_media();
    }

    fn restart_engine(mut self: Pin<&mut Self>) {
        self.as_mut().end_listen();
        self.as_mut().rust_mut().mpv = None;
        self.as_mut().set_playing(false);
        self.as_mut().set_loading(false);
        resolver::clear();
        self.ensure_engine();
    }

    /// Resuelve de antemano las tres pistas siguientes de la cola (con repetición, dando la
    /// vuelta). Las que necesitan la sesión tardan ~2 s en resolverse: así ya están listas.
    fn prefetch_next(&self) {
        if *self.repetir_una() {
            return;
        }
        let len = self.tracks.len();
        let at = *self.index() as usize;
        for step in 1..=3 {
            let next = at + step;
            let next = if next < len { next } else if *self.repetir() && len > 0 { next % len } else { break };
            if next != at {
                resolver::prefetch(&self.tracks[next].video_id);
            }
        }
    }

    fn prefetch_tracks(&self, tracks: &QString, count: i32) {
        let Ok(serde_json::Value::Array(list)) = serde_json::from_str(&tracks.to_string()) else { return };
        for track in list.iter().filter_map(track_from).take(count.max(0) as usize) {
            resolver::prefetch(&track.video_id);
        }
    }

    fn set_temporal_tracks(mut self: Pin<&mut Self>, tracks: Vec<Track>) {
        let json = serde_json::to_string(&tracks).unwrap_or_else(|_| "[]".to_owned());
        self.as_mut().rust_mut().temporal_tracks = tracks;
        self.set_temporal(QString::from(&json));
    }

    fn add_to_temporal(mut self: Pin<&mut Self>, item: &QString) {
        let Ok(value) = serde_json::from_str::<serde_json::Value>(&item.to_string()) else { return };
        if let Some(track) = track_from(&value) {
            resolver::prefetch(&track.video_id);
            let mut tracks = std::mem::take(&mut self.as_mut().rust_mut().temporal_tracks);
            tracks.push(track);
            self.as_mut().set_temporal_tracks(tracks);
            return;
        }
        // Un álbum o playlist: se añaden todas sus canciones cuando llegan.
        let Ok(item) = serde_json::from_value::<Item>(value) else { return };
        if item.playlist_id.is_empty() {
            return;
        }
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = album_queue(&item.playlist_id);
            let _ = qt.queue(move |mut player| match result {
                Ok(added) => {
                    let mut tracks = std::mem::take(&mut player.as_mut().rust_mut().temporal_tracks);
                    tracks.extend(added);
                    player.as_mut().set_temporal_tracks(tracks);
                }
                Err(error) => player.fail(&error),
            });
        });
    }

    fn remove_from_temporal(mut self: Pin<&mut Self>, index: i32) {
        if index < 0 || index as usize >= self.temporal_tracks.len() {
            return;
        }
        let mut tracks = std::mem::take(&mut self.as_mut().rust_mut().temporal_tracks);
        tracks.remove(index as usize);
        self.as_mut().set_temporal_tracks(tracks);
    }

    fn clear_temporal(self: Pin<&mut Self>) {
        self.set_temporal_tracks(Vec::new());
    }

    fn cycle_repeat(mut self: Pin<&mut Self>) {
        let (cola, una) = match (*self.repetir(), *self.repetir_una()) {
            (false, false) => (true, false),
            (true, false) => (false, true),
            _ => (false, false),
        };
        self.as_mut().set_repetir(cola);
        self.as_mut().set_repetir_una(una);
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.set_loop_file(una);
        }
        self.prefetch_next();
    }

    fn play_temporal(mut self: Pin<&mut Self>, index: i32) {
        let tracks = self.temporal_tracks.clone();
        if tracks.is_empty() {
            return;
        }
        let start = (index.max(0) as usize).min(tracks.len() - 1);
        self.as_mut().new_request();
        self.as_mut().set_repetir(true);
        self.as_mut().set_repetir_una(false);
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.set_loop_file(false);
        }
        self.as_mut().set_tracks(tracks);
        self.load(start);
    }

    fn apply_effects(mut self: Pin<&mut Self>) {
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.set_effects(&crate::audio::effects());
        }
    }

    fn change_volume(mut self: Pin<&mut Self>, volume: f64) {
        let volume = volume.clamp(0.0, 100.0);
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.set_volume(volume);
        }
        self.set_volume(volume);
    }

    fn enqueue(self: Pin<&mut Self>, item: &QString, next: bool) {
        let Ok(value) = serde_json::from_str::<serde_json::Value>(&item.to_string()) else { return };
        if let Some(track) = track_from(&value) {
            self.insert_tracks(vec![track], next);
            return;
        }
        let Ok(item) = serde_json::from_value::<Item>(value) else { return };
        if item.playlist_id.is_empty() {
            return;
        }
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = album_queue(&item.playlist_id);
            let _ = qt.queue(move |player| match result {
                Ok(tracks) if !tracks.is_empty() => player.insert_tracks(tracks, next),
                Ok(_) => player.fail("No se encontraron canciones."),
                Err(error) => player.fail(&error),
            });
        });
    }

    /// Mete `added` detrás de la pista que suena (`next`) o al final de la cola.
    fn insert_tracks(mut self: Pin<&mut Self>, added: Vec<Track>, next: bool) {
        for track in added.iter().take(3) {
            resolver::prefetch(&track.video_id);
        }
        if self.tracks.is_empty() {
            self.as_mut().new_request();
            self.as_mut().set_tracks(added);
            self.load(0);
            return;
        }
        let mut tracks = std::mem::take(&mut self.as_mut().rust_mut().tracks);
        let at = if next { (*self.index() as usize + 1).min(tracks.len()) } else { tracks.len() };
        tracks.splice(at..at, added);
        self.as_mut().set_tracks(tracks);
        self.prefetch_next();
    }

    fn move_in_queue(mut self: Pin<&mut Self>, from: i32, to: i32) {
        let len = self.tracks.len() as i32;
        if from == to || from < 0 || to < 0 || from >= len || to >= len {
            return;
        }
        let (from, to) = (from as usize, to as usize);
        let current = *self.index() as usize;
        let mut tracks = std::mem::take(&mut self.as_mut().rust_mut().tracks);
        let moved = tracks.remove(from);
        tracks.insert(to, moved);
        // La pista que suena conserva su sitio en la cola aunque cambie de posición.
        let current = if from == current {
            to
        } else if from < current && to >= current {
            current - 1
        } else if from > current && to <= current {
            current + 1
        } else {
            current
        };
        self.as_mut().set_tracks(tracks);
        self.as_mut().set_index(current as i32);
        self.prefetch_next();
    }

    fn remove_from_queue(mut self: Pin<&mut Self>, index: i32) {
        let current = *self.index();
        if index < 0 || index as usize >= self.tracks.len() || index == current {
            return;
        }
        let mut tracks = std::mem::take(&mut self.as_mut().rust_mut().tracks);
        tracks.remove(index as usize);
        self.as_mut().set_tracks(tracks);
        if index < current {
            self.as_mut().set_index(current - 1);
        }
        self.prefetch_next();
    }

    fn shuffle_queue(mut self: Pin<&mut Self>) {
        let start = (*self.index() + 1).max(0) as usize;
        if start + 1 >= self.tracks.len() {
            return;
        }
        let mut tracks = std::mem::take(&mut self.as_mut().rust_mut().tracks);
        shuffle_tracks(&mut tracks[start..]);
        self.as_mut().set_tracks(tracks);
        self.prefetch_next();
    }

    /// Empieza a registrar la pista que acaba de arrancar. La petición a YouTube va en un
    /// hilo: el arranque de la pista no la espera.
    fn begin_listen(mut self: Pin<&mut Self>) {
        let token = self.load_token;
        let position = *self.position();
        let video_id = self.tracks.get(*self.index() as usize).map(|track| track.video_id.clone());
        let Some(video_id) = video_id.filter(|_| history::active()) else {
            self.as_mut().rust_mut().listen = None;
            return;
        };
        self.as_mut().rust_mut().listen = Some(Listen { token, report: None, from: position, last: position });
        let qt = self.qt_thread();
        thread::spawn(move || match history::start(&video_id) {
            Ok(report) => {
                let _ = qt.queue(move |mut player| {
                    if let Some(listen) = player.as_mut().rust_mut().listen.as_mut().filter(|l| l.token == token) {
                        listen.report = Some(report);
                    }
                });
            }
            Err(error) => eprintln!("historial de {video_id}: {error}"),
        });
    }

    /// Sigue la posición para saber qué tramos se escucharon de verdad.
    fn track_listen(mut self: Pin<&mut Self>, position: f64) {
        let duration = *self.duration();
        let one = *self.repetir_una();
        let Some(listen) = self.listen.as_ref() else { return };
        let (from, last) = (listen.from, listen.last);
        // Con «repetir la canción», cada vuelta es una escucha nueva.
        if one && position < 2.0 && duration > 0.0 && last > duration - 5.0 {
            self.as_mut().end_listen();
            self.as_mut().begin_listen();
            return;
        }
        let jumped = position < last - 1.0 || position > last + 5.0;
        if jumped || last - from >= 30.0 {
            self.as_mut().flush_listen();
        }
        if let Some(listen) = self.as_mut().rust_mut().listen.as_mut() {
            if jumped {
                listen.from = position;
            }
            listen.last = position;
        }
    }

    /// Envía el tramo escuchado desde el último aviso.
    fn flush_listen(mut self: Pin<&mut Self>) {
        let mut rust = self.as_mut().rust_mut();
        let Some(listen) = rust.listen.as_mut() else { return };
        let Some(report) = listen.report.clone() else { return };
        let (from, to) = (listen.from, listen.last);
        if to - from < 1.0 {
            return;
        }
        listen.from = to;
        thread::spawn(move || {
            if let Err(error) = history::watched(&report, from, to) {
                eprintln!("historial: {error}");
            }
        });
    }

    fn end_listen(mut self: Pin<&mut Self>) {
        self.as_mut().flush_listen();
        self.as_mut().rust_mut().listen = None;
    }

    /// Empieza una petición de reproducción nueva: las respuestas de las anteriores se descartan
    /// (`request`) y se quita el error que hubiera.
    fn new_request(mut self: Pin<&mut Self>) -> u64 {
        let request = self.request + 1;
        self.as_mut().rust_mut().request = request;
        self.set_error(QString::default());
        request
    }

    fn fail(mut self: Pin<&mut Self>, message: &str) {
        self.as_mut().set_loading(false);
        self.as_mut().set_error(QString::from(message));
    }

    fn set_tracks(mut self: Pin<&mut Self>, tracks: Vec<Track>) {
        let json = serde_json::to_string(&tracks).unwrap_or_default();
        self.as_mut().rust_mut().tracks = tracks;
        self.as_mut().set_queue(QString::from(&json));
    }

    /// Instala la cola recibida de la red. Si la primera canción ya estaba sonando
    /// (`started`), solo completa sus datos; si no, empieza por la primera pista.
    fn adopt_queue(mut self: Pin<&mut Self>, tracks: Vec<Track>, started: bool) {
        if !started {
            self.as_mut().set_tracks(tracks);
            self.load(0);
            return;
        }

        let current = self.tracks.first().map(|track| track.video_id.clone()).unwrap_or_default();
        let at = tracks.iter().position(|track| track.video_id == current).unwrap_or(0);
        let track = tracks[at].clone();
        self.as_mut().set_tracks(tracks);
        self.as_mut().set_index(at as i32);
        // La cola trae el artista limpio y la duración; con eso la letra se encuentra mejor.
        self.as_mut().set_artist(QString::from(&track.artist));
        self.as_mut().fetch_lyrics(track);
        self.prefetch_next();
    }

    /// Arranca mpv la primera vez que hace falta.
    fn ensure_engine(mut self: Pin<&mut Self>) -> bool {
        if self.mpv.is_some() {
            return true;
        }
        let qt = self.qt_thread();
        let engine = Mpv::spawn(move |event| {
            let _ = qt.queue(move |player| player.on_event(event));
        });
        match engine {
            Ok(mut mpv) => {
                let _ = mpv.set_volume(*self.volume());
                let effects = crate::audio::effects();
                if !effects.is_empty() {
                    let _ = mpv.set_effects(&effects);
                }
                if *self.repetir_una() {
                    let _ = mpv.set_loop_file(true);
                }
                self.as_mut().rust_mut().mpv = Some(mpv);
                true
            }
            Err(error) => {
                self.fail(&format!("No se pudo iniciar el motor de audio (mpv): {error}"));
                false
            }
        }
    }

    fn load(mut self: Pin<&mut Self>, index: usize) {
        let defer_lyrics = std::mem::take(&mut self.as_mut().rust_mut().defer_lyrics);
        let Some(track) = self.tracks.get(index).cloned() else { return };
        if !self.as_mut().ensure_engine() {
            return;
        }
        if self.retried != Some(index) {
            self.as_mut().rust_mut().retried = None;
        }

        self.as_mut().end_listen();
        self.as_mut().set_index(index as i32);
        self.as_mut().set_title(QString::from(&track.title));
        self.as_mut().set_artist(QString::from(&track.artist));
        self.as_mut().set_thumb(QString::from(&track.thumb));
        self.as_mut().set_duration(track.duration);
        self.as_mut().set_position(0.0);
        self.as_mut().set_loading(true);
        self.as_mut().set_error(QString::default());

        self.as_mut().rust_mut().announced = false;
        let token = self.load_token + 1;
        self.as_mut().rust_mut().load_token = token;
        self.as_mut().rust_mut().load_started = Some(Instant::now());

        // Depuración: `MUSICPLAYER_DEBUG_AUDIO=archivo` suena ese archivo local en lugar de cada
        // pista (medir la letra o la interfaz sin depender de que YouTube deje reproducir).
        let debug_audio = std::env::var("MUSICPLAYER_DEBUG_AUDIO").ok().filter(|file| !file.is_empty());
        match debug_audio.or_else(|| resolver::cached(&track.video_id)) {
            // Ya resuelta: suena en unas décimas.
            Some(url) => self.as_mut().start_stream(Some(&url), &track.video_id),
            None => {
                let qt = self.qt_thread();
                let video_id = track.video_id.clone();
                thread::spawn(move || {
                    let result = resolver::resolve(&video_id);
                    let _ = qt.queue(move |player| {
                        if player.load_token != token {
                            return;
                        }
                        match &result {
                            Err(error) if error == resolver::NEEDS_SESSION => {
                                player.fail(
                                    "YouTube solo deja escuchar esta canción con tu cuenta. Inicia sesión en Opciones › Cuenta.",
                                );
                                return;
                            }
                            Err(error) => eprintln!("{error}; se usa el gancho de yt-dlp de mpv"),
                            Ok(_) => {}
                        }
                        player.start_stream(result.ok().as_deref(), &video_id);
                    });
                });
            }
        }
        if defer_lyrics {
            // La de la pista anterior no debe quedarse en pantalla mientras llega la cola.
            self.clear_lyrics();
        } else {
            self.fetch_lyrics(track);
        }
    }

    /// Ordena a mpv que reproduzca: la URL resuelta si la hay, si no la página de YouTube.
    fn start_stream(mut self: Pin<&mut Self>, stream_url: Option<&str>, video_id: &str) {
        let page = format!("https://www.youtube.com/watch?v={video_id}");
        self.as_mut().rust_mut().via_stream = stream_url.is_some();
        let loaded = self.as_mut().rust_mut().mpv.as_mut().map(|mpv| match stream_url {
            Some(url) => mpv.load(url),
            None => mpv.load(&page),
        });
        if !matches!(loaded, Some(Ok(()))) {
            self.fail("Se perdió la conexión con el motor de audio.");
        }
    }

    /// Quita la letra publicada y descarta las respuestas pendientes; devuelve el contador nuevo.
    fn clear_lyrics(mut self: Pin<&mut Self>) -> u64 {
        let token = self.lyrics_token + 1;
        self.as_mut().rust_mut().lyrics_token = token;
        self.as_mut().rust_mut().lyrics_found.clear();
        self.set_lyrics(QString::default());
        token
    }

    /// Pide la letra a todas las fuentes a la vez y publica cada una según llega, ordenadas de
    /// mejor a peor (la primera aparece en cuanto responde la fuente más rápida).
    fn fetch_lyrics(mut self: Pin<&mut Self>, track: Track) {
        let token = self.as_mut().clear_lyrics();
        let query = std::sync::Arc::new(lyrics::Query::new(&track.title, &track.artist, track.duration));
        for source in lyrics::SOURCES {
            let qt = self.qt_thread();
            let query = query.clone();
            thread::spawn(move || {
                let Some(found) = lyrics::fetch(source, &query) else { return };
                let _ = qt.queue(move |mut player| {
                    if player.lyrics_token != token {
                        return;
                    }
                    let mut rust = player.as_mut().rust_mut();
                    rust.lyrics_found.push(found);
                    lyrics::rank(&mut rust.lyrics_found);
                    let json = serde_json::to_string(&rust.lyrics_found).unwrap_or_default();
                    player.as_mut().set_lyrics(QString::from(&json));
                });
            });
        }
    }

    fn on_event(mut self: Pin<&mut Self>, event: Event) {
        match event {
            Event::Position(position) => {
                plugins::emit(plugins::Event::Position(position));
                self.as_mut().track_listen(position);
                self.set_position(position);
            }
            Event::Duration(duration) if duration > 0.0 => self.set_duration(duration),
            Event::Duration(_) => {}
            Event::Codec(codec) => {
                let rust = self.as_mut().rust_mut();
                rust.get_mut().codec = codec;
                self.update_quality();
            }
            Event::Bitrate(kbps) => {
                self.as_mut().rust_mut().get_mut().kbps = kbps;
                self.update_quality();
            }
            // mpv en reposo informa «no pausado»: solo cuenta si hay una pista cargada.
            Event::Paused(paused) => {
                self.as_mut().rust_mut().mpv_paused = paused;
                let loaded = !self.tracks.is_empty();
                let playing = !paused && loaded;
                if playing != *self.playing() && self.announced {
                    plugins::emit(plugins::Event::Playing(playing, *self.position()));
                }
                self.as_mut().set_playing(playing);
                if paused {
                    self.as_mut().flush_listen();
                }
                self.publish_media();
            }
            Event::Started => {
                if let Some(started) = self.as_mut().rust_mut().load_started.take() {
                    eprintln!("arranque de pista: {} ms", started.elapsed().as_millis());
                }
                self.as_mut().set_loading(false);
                // mpv solo avisa de la pausa cuando cambia: al empezar una pista hay que
                // aplicar la que ya tenía.
                let playing = !self.mpv_paused;
                self.as_mut().set_playing(playing);
                self.as_mut().announce();
                // mpv también avisa tras cada salto: solo cuenta la primera vez de cada carga.
                if self.listen.as_ref().map(|listen| listen.token) != Some(self.load_token) {
                    self.as_mut().begin_listen();
                }
                self.prefetch_next();
            }
            // Con `loop-file` mpv no llega a terminar la pista; esto cubre el caso raro de que
            // la opción no se aplicara (motor reiniciado a medias).
            Event::Ended if *self.repetir_una() => {
                let index = *self.index() as usize;
                self.load(index);
            }
            Event::Ended => {
                if (*self.index() as usize) + 1 < self.tracks.len() || *self.repetir() {
                    self.advance();
                } else {
                    self.as_mut().end_listen();
                    plugins::emit(plugins::Event::Stopped);
                    self.as_mut().set_playing(false);
                    self.publish_media();
                }
            }
            Event::Failed => {
                // YouTube rechaza peticiones de vez en cuando: un segundo intento suele bastar.
                let index = *self.index() as usize;
                let Some(video_id) = self.tracks.get(index).map(|track| track.video_id.clone()) else { return };
                // La URL guardada pudo caducar o ser rechazada: se olvida y se prueba con el
                // gancho de yt-dlp de mpv, que negocia la descarga por su cuenta.
                resolver::forget(&video_id);
                if self.via_stream {
                    eprintln!("la URL directa falló; se usa el gancho de yt-dlp de mpv");
                    self.start_stream(None, &video_id);
                } else if self.retried != Some(index) {
                    self.as_mut().rust_mut().retried = Some(index);
                    self.load(index);
                } else {
                    self.as_mut().fail("No se pudo reproducir esta pista.");
                    self.set_playing(false);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{artist_from_subtitle, track_from};

    #[test]
    fn el_artista_sale_limpio_del_subtitulo() {
        assert_eq!(artist_from_subtitle("Quevedo y Elvis Crespo • 75 M reproducciones"), "Quevedo y Elvis Crespo");
        assert_eq!(artist_from_subtitle("Canción • Vetusta Morla • Mi colección de duelos • 3:27"), "Vetusta Morla");
        assert_eq!(artist_from_subtitle("Vetusta Morla"), "Vetusta Morla");
    }

    #[test]
    fn convierte_tarjetas_y_pistas_en_pistas() {
        let song = serde_json::json!({ "kind": "song", "title": "Canción", "subtitle": "Canción • Artista • 3 M", "videoId": "abc", "thumb": "t" });
        let track = track_from(&song).expect("una canción es una pista");
        assert_eq!((track.title.as_str(), track.artist.as_str(), track.video_id.as_str()), ("Canción", "Artista", "abc"));

        let queued = serde_json::json!({ "title": "T", "artist": "A", "videoId": "xyz", "thumb": "", "duration": 200.0 });
        assert_eq!(track_from(&queued).map(|track| track.duration), Some(200.0));

        let album = serde_json::json!({ "kind": "album", "title": "Álbum", "playlistId": "OLAK" });
        assert!(track_from(&album).is_none());
    }
}
