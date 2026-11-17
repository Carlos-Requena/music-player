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

    /// Carga una URL: la de audio ya resuelta, tal cual la dejó `resolver` (con `lavf://` delante
    /// si debe leerla ffmpeg), o la de la página (la resuelve el gancho de yt-dlp de mpv: lento).
    pub fn load(&mut self, url: &str) -> io::Result<()> {
        self.command(json!(["loadfile", url, "replace"]))?;
        self.set_pause(false)
    }

    pub fn set_pause(&mut self, paused: bool) -> io::Result<()> {
        self.command(json!(["set_property", "pause", paused]))
    }

    pub fn seek(&mut self, seconds: f64) -> io::Result<()> {
        self.command(json!(["seek", seconds, "absolute"]))
    }

    /// Repite el archivo actual sin fin (sin huecos ni volver a resolver la URL). Es una
    /// opción global de mpv: sigue puesta al cargar otra pista hasta que se quite.
    pub fn set_loop_file(&mut self, on: bool) -> io::Result<()> {
        self.command(json!(["set_property", "loop-file", if on { "inf" } else { "no" }]))
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

/// Un mensaje de mpv con solo los campos que se miran. Los nombres se toman prestados de la
/// línea leída (nunca llevan escapes): mpv manda la posición muchas veces por segundo y así cada
/// mensaje no crea un árbol JSON con sus claves. El texto de los avisos sí puede llevarlos.
#[derive(serde::Deserialize)]
struct Message<'a> {
    #[serde(default)]
    event: Option<&'a str>,
    #[serde(default)]
    name: Option<&'a str>,
    #[serde(default)]
    data: Value,
    #[serde(default)]
    reason: Option<&'a str>,
    #[serde(default)]
    prefix: Option<&'a str>,
    #[serde(default)]
    text: Option<String>,
}

fn read_events(socket: UnixStream, on_event: impl Fn(Event)) {
    let mut last_position = f64::MIN;
    let mut last_bitrate = f64::MIN;
    let mut reader = BufReader::new(socket);
    // Una sola línea que se reutiliza para cada mensaje.
    let mut line = String::new();
    loop {
        line.clear();
        match reader.read_line(&mut line) {
            Ok(0) | Err(_) => break,
            Ok(_) => {}
        }
        let Ok(message) = serde_json::from_str::<Message>(&line) else { continue };
        match message.event {
            Some("property-change") => {
                let data = &message.data;
                match message.name {
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
                message.prefix.unwrap_or_default(),
                message.text.as_deref().unwrap_or_default().trim_end()
            ),
            Some("playback-restart") => on_event(Event::Started),
            Some("end-file") => match message.reason {
                Some("eof") => on_event(Event::Ended),
                Some("error") => on_event(Event::Failed),
                // "stop" y "redirect" ocurren al cambiar de pista o al resolver la URL.
                _ => {}
            },
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Message;

    #[test]
    fn lee_los_mensajes_de_mpv() {
        let position: Message = serde_json::from_str(r#"{"event":"property-change","id":1,"name":"time-pos","data":12.5}"#).unwrap();
        assert_eq!((position.event, position.name, position.data.as_f64()), (Some("property-change"), Some("time-pos"), Some(12.5)));
        // El texto de un aviso lleva escapes (el salto de línea final).
        let log: Message = serde_json::from_str(r#"{"event":"log-message","prefix":"ffmpeg","level":"error","text":"fallo \"x\"\n"}"#).unwrap();
        assert_eq!(log.text.as_deref(), Some("fallo \"x\"\n"));
        let end: Message = serde_json::from_str(r#"{"event":"end-file","reason":"eof","playlist_entry_id":1}"#).unwrap();
        assert_eq!(end.reason, Some("eof"));
        // Las respuestas a las órdenes no tienen evento.
        let reply: Message = serde_json::from_str(r#"{"request_id":0,"error":"success"}"#).unwrap();
        assert!(reply.event.is_none() && reply.data.is_null());
    }
}
