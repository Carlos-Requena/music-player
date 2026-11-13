//! Motor de audio: un proceso `mpv` sin vídeo controlado por su socket IPC JSON.
//!
//! mpv resuelve las URL de YouTube con su gancho de `yt-dlp`, así que aquí basta
//! con pedirle que cargue `https://www.youtube.com/watch?v=…`.

use std::{
    env, fs,
    io::{self, BufRead, BufReader, Write},
    os::unix::net::UnixStream,
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    thread,
    time::{Duration, Instant},
};

use serde_json::{json, Value};

/// Lo que el reproductor necesita saber del motor.
pub enum Event {
    /// Códec del audio que suena (`opus`, `aac`…).
    Codec(String),
    /// Tasa de bits del audio, en kbps.
    Bitrate(f64),
    Position(f64),
    Duration(f64),
    Paused(bool),
    /// El audio empezó a sonar (o se reanudó tras un salto).
    Started,
    /// La pista terminó de forma natural.
    Ended,
    /// mpv no pudo abrir o reproducir la pista.
    Failed,
}

/// Rutas donde suelen vivir mpv y yt-dlp y que una app gráfica no hereda en su PATH.
const EXTRA_PATHS: &[&str] = &["/opt/homebrew/bin", "/usr/local/bin"];

pub fn search_path() -> String {
    let mut path = env::var("PATH").unwrap_or_default();
    for extra in EXTRA_PATHS {
        if !path.split(':').any(|dir| dir == *extra) {
            path.push(':');
            path.push_str(extra);
        }
    }
    path
}

pub fn which(program: &str, path: &str) -> Option<PathBuf> {
    path.split(':')
        .map(|dir| Path::new(dir).join(program))
        .find(|candidate| candidate.is_file())
}

pub struct Mpv {
    child: Child,
    socket: UnixStream,
    socket_path: PathBuf,
}

impl Mpv {
    /// Arranca mpv en reposo y entrega sus eventos a `on_event` desde un hilo propio.
    pub fn spawn(on_event: impl Fn(Event) + Send + 'static) -> io::Result<Self> {
        let path = search_path();
        let mpv = which("mpv", &path)
            .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no se encuentra mpv"))?;
        // Los sockets Unix admiten rutas de ~104 bytes: con una carpeta temporal larga se usa /tmp.
        let name = format!("musicplayer-mpv-{}.sock", std::process::id());
        let mut socket_path = env::temp_dir().join(&name);
        if socket_path.as_os_str().len() > 100 {
            socket_path = PathBuf::from("/tmp").join(&name);
        }
        let _ = fs::remove_file(&socket_path);

        let mut command = Command::new(mpv);
        command
            .arg("--idle=yes")
            .arg("--no-video")
            .arg("--no-terminal")
            .arg("--no-config")
            .arg("--audio-display=no")
            // Sin los scripts de interfaz de mpv (no hay ventana) y con una caché acorde a
            // pistas de audio: ~10 MB menos.
            .args(["--osc=no", "--load-stats-overlay=no", "--load-console=no", "--load-auto-profiles=no"])
            .args(["--load-select=no", "--load-positioning=no", "--load-commands=no", "--load-context-menu=no"])
            .args(["--demuxer-max-bytes=16MiB", "--demuxer-max-back-bytes=4MiB"])
            .arg("--ytdl-format=bestaudio/best")
            .arg(format!("--input-ipc-server={}", socket_path.display()))
            .env("PATH", &path)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null());
        // Plan B cuando no hay URL resuelta: el gancho de yt-dlp de mpv, con las mismas
        // opciones que usa `resolver`.
        for option in crate::resolver::ytdlp_options(&path) {
            command.arg(format!("--ytdl-raw-options-append={}", option.trim_start_matches("--").replacen(' ', "=", 1)));
        }
        // Las cookies van en una copia: yt-dlp reescribe el archivo al terminar.
        if let Some(copy) = crate::account::cookies_copy("mpv") {
            command.arg(format!("--ytdl-raw-options-append=cookies={}", copy.display()));
        }
        // Para pruebas automáticas: reproduce sin enviar sonido a los altavoces.
        if env::var_os("MUSICPLAYER_SILENT").is_some() {
            command.arg("--ao=null");
        }
        let mut child = command.spawn()?;

        let socket = match connect(&socket_path, Duration::from_secs(5)) {
            Ok(socket) => socket,
            Err(error) => {
                let _ = child.kill();
                return Err(error);
            }
        };
        let reader = socket.try_clone()?;
        thread::spawn(move || read_events(reader, on_event));

        let mut mpv = Self { child, socket, socket_path };
        for (id, property) in [(1, "time-pos"), (2, "duration"), (3, "pause"), (4, "audio-codec-name"), (5, "audio-bitrate")] {
            mpv.command(json!(["observe_property", id, property]))?;
        }
        // Los errores de mpv y de yt-dlp salen por stderr para poder diagnosticarlos.
        mpv.command(json!(["request_log_messages", "error"]))?;
        Ok(mpv)
    }

    fn command(&mut self, args: Value) -> io::Result<()> {
        let mut line = json!({ "command": args }).to_string();
        line.push('\n');
        self.socket.write_all(line.as_bytes())
    }

    /// Carga una URL de página (la resuelve el gancho de yt-dlp de mpv: lento).
    pub fn load(&mut self, url: &str) -> io::Result<()> {
        self.command(json!(["loadfile", url, "replace"]))?;
        self.set_pause(false)
    }

    /// Carga una URL de audio ya resuelta, tal cual la dejó `resolver` (con `lavf://`
    /// delante si debe leerla ffmpeg).
    pub fn load_stream(&mut self, stream_url: &str) -> io::Result<()> {
        self.load(stream_url)
    }

    pub fn set_pause(&mut self, paused: bool) -> io::Result<()> {
        self.command(json!(["set_property", "pause", paused]))
    }

    pub fn seek(&mut self, seconds: f64) -> io::Result<()> {
        self.command(json!(["seek", seconds, "absolute"]))
    }

    /// Volumen de 0 a 100.
    pub fn set_volume(&mut self, volume: f64) -> io::Result<()> {
        self.command(json!(["set_property", "volume", volume]))
    }
}

impl Drop for Mpv {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
        let _ = fs::remove_file(&self.socket_path);
    }
}

/// mpv crea el socket poco después de arrancar; se reintenta hasta `timeout`.
fn connect(path: &Path, timeout: Duration) -> io::Result<UnixStream> {
    let deadline = Instant::now() + timeout;
    loop {
        match UnixStream::connect(path) {
            Ok(socket) => return Ok(socket),
            Err(error) if Instant::now() >= deadline => return Err(error),
            Err(_) => thread::sleep(Duration::from_millis(50)),
        }
    }
}

fn read_events(socket: UnixStream, on_event: impl Fn(Event)) {
    let mut last_position = f64::MIN;
    let mut last_bitrate = f64::MIN;
    for line in BufReader::new(socket).lines() {
        let Ok(line) = line else { break };
        let Ok(message) = serde_json::from_str::<Value>(&line) else { continue };
        match message["event"].as_str() {
            Some("property-change") => {
                let data = &message["data"];
                match message["name"].as_str() {
                    Some("time-pos") => {
                        // mpv informa muchas veces por segundo; a la interfaz le bastan diez.
                        if let Some(position) = data.as_f64() {
                            if (position - last_position).abs() >= 0.1 {
                                last_position = position;
                                on_event(Event::Position(position));
                            }
                        }
                    }
                    Some("duration") => {
                        if let Some(duration) = data.as_f64() {
                            on_event(Event::Duration(duration));
                        }
                    }
                    Some("pause") => {
                        if let Some(paused) = data.as_bool() {
                            on_event(Event::Paused(paused));
                        }
                    }
                    Some("audio-codec-name") => {
                        if let Some(codec) = data.as_str() {
                            on_event(Event::Codec(codec.to_owned()));
                        }
                    }
                    Some("audio-bitrate") => {
                        // Varía a cada momento (VBR): solo se avisa de cambios apreciables.
                        if let Some(bitrate) = data.as_f64() {
                            let kbps = (bitrate / 1000.0).round();
                            if (kbps - last_bitrate).abs() >= 8.0 {
                                last_bitrate = kbps;
                                on_event(Event::Bitrate(kbps));
                            }
                        }
                    }
                    _ => {}
                }
            }
            Some("log-message") => eprintln!(
                "mpv[{}] {}",
                message["prefix"].as_str().unwrap_or_default(),
                message["text"].as_str().unwrap_or_default().trim_end()
            ),
            Some("playback-restart") => on_event(Event::Started),
            Some("end-file") => match message["reason"].as_str() {
                Some("eof") => on_event(Event::Ended),
                Some("error") => on_event(Event::Failed),
                // "stop" y "redirect" ocurren al cambiar de pista o al resolver la URL.
                _ => {}
            },
            _ => {}
        }
    }
}
