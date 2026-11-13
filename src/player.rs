//! Reproductor expuesto a QML como singleton `Player`.
//!
//! Mantiene la cola, ordena a mpv qué cargar y publica el estado (posición, pista
//! actual, letra) como propiedades. La red y mpv trabajan en hilos propios y
//! devuelven sus resultados al hilo de Qt con `qt_thread().queue`.

use std::{
    collections::HashMap,
    pin::Pin,
    sync::{LazyLock, Mutex},
    thread,
    time::Instant,
};

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;

use crate::{
    audio::{Event, Mpv},
    lyrics, plugins, resolver,
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
        #[qproperty(QString, lyrics)]
        #[qproperty(QString, error)]
        #[qproperty(f64, volume)]
        /// Formato real de lo que suena, p. ej. «Opus · 152 kbps».
        #[qproperty(QString, calidad)]
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

        /// Salta a la pista siguiente de la cola.
        #[qinvokable]
        fn next(self: Pin<&mut Player>);

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

        /// Cambia el volumen (0–100).
        #[qinvokable]
        fn change_volume(self: Pin<&mut Player>, volume: f64);
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

/// Colas de álbumes y playlists ya descargadas, por `playlist_id`.
static QUEUES: LazyLock<Mutex<HashMap<String, Vec<Track>>>> = LazyLock::new(Default::default);

fn cached_queue(playlist_id: &str) -> Option<Vec<Track>> {
    QUEUES.lock().ok()?.get(playlist_id).cloned()
}

/// Cola de un álbum o playlist, desde la caché o la red.
fn album_queue(playlist_id: &str) -> ytm::Result<Vec<Track>> {
    if let Some(tracks) = cached_queue(playlist_id) {
        return Ok(tracks);
    }
    let tracks = ytm::queue("", playlist_id)?;
    if let Ok(mut queues) = QUEUES.lock() {
        queues.insert(playlist_id.to_owned(), tracks.clone());
    }
    Ok(tracks)
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
        }
    }
}

impl qobject::Player {
    fn play_item(mut self: Pin<&mut Self>, item: &QString) {
        let Ok(item) = serde_json::from_str::<Item>(&item.to_string()) else { return };
        if item.video_id.is_empty() && item.playlist_id.is_empty() {
            return;
        }

        let request = self.request + 1;
        self.as_mut().rust_mut().request = request;
        self.as_mut().set_error(QString::default());

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
                    // La canción ya suena: quedarse sin radio no es un error visible.
                    _ => {}
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
        let request = self.request + 1;
        self.as_mut().rust_mut().request = request;
        self.as_mut().set_error(QString::default());
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

    fn next(self: Pin<&mut Self>) {
        let next = *self.index() as usize + 1;
        if next < self.tracks.len() {
            self.load(next);
        }
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
            thread::spawn(move || {
                if let Some(first) = album_queue(&item.playlist_id).ok().and_then(|t| t.into_iter().next()) {
                    resolver::hint(&first.video_id);
                }
            });
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
            plugins::emit(plugins::Event::Track(plugins::Track {
                title: self.title().to_string(),
                artist: self.artist().to_string(),
                thumb: self.thumb().to_string(),
                duration: *self.duration(),
            }));
        } else {
            plugins::emit(plugins::Event::Playing(*self.playing(), *self.position()));
        }
        self.publish_media();
    }

    fn restart_engine(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().mpv = None;
        self.as_mut().set_playing(false);
        self.as_mut().set_loading(false);
        resolver::clear();
        self.ensure_engine();
    }

    /// Resuelve de antemano la pista siguiente de la cola.
    fn prefetch_next(&self) {
        if let Some(next) = self.tracks.get(*self.index() as usize + 1) {
            resolver::prefetch(&next.video_id);
        }
    }

    fn change_volume(mut self: Pin<&mut Self>, volume: f64) {
        let volume = volume.clamp(0.0, 100.0);
        if let Some(mpv) = self.as_mut().rust_mut().mpv.as_mut() {
            let _ = mpv.set_volume(volume);
        }
        self.set_volume(volume);
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
        let Some(track) = self.tracks.get(index).cloned() else { return };
        if !self.as_mut().ensure_engine() {
            return;
        }
        if self.retried != Some(index) {
            self.as_mut().rust_mut().retried = None;
        }

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

        match resolver::cached(&track.video_id) {
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
                        if let Err(error) = &result {
                            eprintln!("{error}; se usa el gancho de yt-dlp de mpv");
                        }
                        player.start_stream(result.ok().as_deref(), &video_id);
                    });
                });
            }
        }
        self.fetch_lyrics(track);
    }

    /// Ordena a mpv que reproduzca: la URL resuelta si la hay, si no la página de YouTube.
    fn start_stream(mut self: Pin<&mut Self>, stream_url: Option<&str>, video_id: &str) {
        let page = format!("https://www.youtube.com/watch?v={video_id}");
        self.as_mut().rust_mut().via_stream = stream_url.is_some();
        let loaded = self.as_mut().rust_mut().mpv.as_mut().map(|mpv| match stream_url {
            Some(url) => mpv.load_stream(url),
            None => mpv.load(&page),
        });
        if !matches!(loaded, Some(Ok(()))) {
            self.fail("Se perdió la conexión con el motor de audio.");
        }
    }

    fn fetch_lyrics(mut self: Pin<&mut Self>, track: Track) {
        self.as_mut().set_lyrics(QString::default());
        let qt = self.qt_thread();
        thread::spawn(move || {
            let lines = lyrics::fetch(&track.title, &track.artist, track.duration);
            let json = lines.and_then(|lines| serde_json::to_string(&lines).ok()).unwrap_or_default();
            let _ = qt.queue(move |mut player| {
                // Solo vale si la pista sigue siendo la misma.
                let current = player.tracks.get(*player.index() as usize).map(|t| t.video_id.as_str());
                if current == Some(track.video_id.as_str()) {
                    player.as_mut().set_lyrics(QString::from(&json));
                }
            });
        });
    }

    fn on_event(mut self: Pin<&mut Self>, event: Event) {
        match event {
            Event::Position(position) => {
                plugins::emit(plugins::Event::Position(position));
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
                self.prefetch_next();
            }
            Event::Ended => {
                if (*self.index() as usize) + 1 < self.tracks.len() {
                    self.next();
                } else {
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
    use super::artist_from_subtitle;

    #[test]
    fn el_artista_sale_limpio_del_subtitulo() {
        assert_eq!(artist_from_subtitle("Quevedo y Elvis Crespo • 75 M reproducciones"), "Quevedo y Elvis Crespo");
        assert_eq!(artist_from_subtitle("Canción • Vetusta Morla • Mi colección de duelos • 3:27"), "Vetusta Morla");
        assert_eq!(artist_from_subtitle("Vetusta Morla"), "Vetusta Morla");
    }
}
