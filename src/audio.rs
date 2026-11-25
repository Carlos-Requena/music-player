//! Motor de audio: un proceso `mpv` sin vídeo controlado por su socket IPC JSON (en Windows,
//! una tubería con nombre: `tuberia.rs`).
//!
//! mpv resuelve las URL de YouTube con su gancho de `yt-dlp`, así que aquí basta
//! con pedirle que cargue `https://www.youtube.com/watch?v=…`.

use std::{
    env,
    ffi::OsStr,
    io::{self, BufRead, BufReader, Write},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    thread,
    time::{Duration, Instant},
};

/// Conexión con mpv: socket Unix o, en Windows, tubería con nombre.
#[cfg(unix)]
type Ipc = std::os::unix::net::UnixStream;
#[cfg(windows)]
type Ipc = crate::tuberia::Tuberia;

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

/// Frecuencias (Hz) de las diez bandas del ecualizador: una por octava, como los clásicos.
pub const EQ_BANDS: [u32; 10] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
/// Ganancia máxima de cada banda y del amplificador, en dB (hacia arriba y, las bandas, abajo).
pub const EQ_LIMIT: f64 = 12.0;

/// Cadena de filtros de audio de mpv (`af`) que piden el ecualizador y el amplificador; vacía
/// si no hay ninguno. La pone `settings` y la aplica `Player` al arrancar mpv y al cambiarla.
static EFFECTS: std::sync::Mutex<String> = std::sync::Mutex::new(String::new());

/// Cadena de filtros para unas ganancias por banda (dB, en el orden de `EQ_BANDS`; las que
/// falten cuentan como 0) y un amplificador (dB). Las bandas a 0 no se añaden; si algo sube el
/// nivel, un limitador al final evita la distorsión por saturación.
pub fn effects_chain(gains: &[f64], boost_db: f64) -> String {
    let mut filters: Vec<String> = EQ_BANDS
        .iter()
        .zip(gains)
        .map(|(freq, gain)| (freq, gain.clamp(-EQ_LIMIT, EQ_LIMIT)))
        .filter(|(_, gain)| gain.abs() >= 0.05)
        .map(|(freq, gain)| format!("equalizer=f={freq}:t=o:w=1:g={gain:.1}"))
        .collect();
    let boost = boost_db.clamp(0.0, EQ_LIMIT);
    if boost >= 0.05 {
        filters.push(format!("volume=volume={boost:.1}dB"));
    }
    if boost >= 0.05 || gains.iter().any(|gain| *gain >= 0.05) {
        filters.push("alimiter=limit=0.97:level=disabled".to_owned());
    }
    if filters.is_empty() {
        String::new()
    } else {
        format!("lavfi=[{}]", filters.join(","))
    }
}

/// Guarda la cadena de efectos a partir de las opciones: `ecualizador` ("si" lo activa),
/// `ecualizadorBandas` (ganancias separadas por comas) y `amplificador` (dB).
pub fn configure(eq_on: bool, bands: &str, boost: &str) {
    let gains: Vec<f64> = if eq_on {
        bands.split(',').map(|gain| gain.trim().parse().unwrap_or(0.0)).collect()
    } else {
        Vec::new()
    };
    let chain = effects_chain(&gains, boost.trim().parse().unwrap_or(0.0));
    if let Ok(mut effects) = EFFECTS.lock() {
        *effects = chain;
    }
}

/// La cadena de efectos vigente (ver `configure`).
pub fn effects() -> String {
    EFFECTS.lock().map(|effects| effects.clone()).unwrap_or_default()
}

/// Rutas donde suelen vivir mpv y yt-dlp y que una app gráfica no hereda en su PATH.
#[cfg(not(windows))]
fn extra_paths() -> Vec<PathBuf> {
    ["/opt/homebrew/bin", "/usr/local/bin"].iter().map(PathBuf::from).collect()
}

/// En Windows: la app instalada (su instalador lleva mpv, yt-dlp y deno; así los encuentra
/// también `target\debug\musicplayer.exe`) y las carpetas de winget, Scoop y Chocolatey.
#[cfg(windows)]
fn extra_paths() -> Vec<PathBuf> {
    let var = |name: &str| env::var_os(name).map(PathBuf::from);
    [
        var("LOCALAPPDATA").map(|dir| dir.join(r"Programs\Reproductor")),
        var("LOCALAPPDATA").map(|dir| dir.join(r"Microsoft\WinGet\Links")),
        var("USERPROFILE").map(|dir| dir.join(r"scoop\shims")),
        var("ProgramData").map(|dir| dir.join(r"chocolatey\bin")),
    ]
    .into_iter()
    .flatten()
    .collect()
}

/// El PATH del sistema con `extra_paths` detrás y, en Windows, la carpeta del ejecutable delante:
/// el instalador deja allí mpv, yt-dlp, deno y ffmpeg.
pub fn search_path() -> String {
    let mut dirs: Vec<PathBuf> = env::var_os("PATH").map(|path| env::split_paths(&path).collect()).unwrap_or_default();
    if cfg!(windows) {
        if let Some(dir) = env::current_exe().ok().and_then(|exe| exe.parent().map(Path::to_path_buf)) {
            dirs.retain(|other| *other != dir);
            dirs.insert(0, dir);
        }
    }
    for extra in extra_paths() {
        if !dirs.contains(&extra) {
            dirs.push(extra);
        }
    }
    env::join_paths(dirs).map(|path| path.to_string_lossy().into_owned()).unwrap_or_default()
}

/// Ruta de `program` en `path` (en Windows, con `.exe` si no lleva extensión).
pub fn which(program: &str, path: &str) -> Option<PathBuf> {
    let name = if cfg!(windows) && Path::new(program).extension().is_none() {
        format!("{program}.exe")
    } else {
        program.to_owned()
    };
    env::split_paths(path).map(|dir| dir.join(&name)).find(|candidate| candidate.is_file())
}

/// `Command::new` para los procesos auxiliares (mpv, yt-dlp, ffmpeg…). En Windows, sin la
/// ventana de consola que abriría cada uno al lanzarlo desde una app gráfica.
pub fn command(program: impl AsRef<OsStr>) -> Command {
    #[allow(unused_mut)]
    let mut command = Command::new(program);
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        command.creation_flags(CREATE_NO_WINDOW);
    }
    command
}

/// Motivo que se muestra si no hay mpv en ninguna carpeta de `search_path`.
#[cfg(not(windows))]
const NO_MPV: &str = "no se encuentra mpv";
#[cfg(windows)]
const NO_MPV: &str = "no se encuentra mpv.exe (instala la app o ponlo junto al programa o en el PATH)";

pub struct Mpv {
    child: Child,
    socket: Ipc,
    socket_path: PathBuf,
}

impl Mpv {
    /// Arranca mpv en reposo y entrega sus eventos a `on_event` desde un hilo propio.
    pub fn spawn(on_event: impl Fn(Event) + Send + 'static) -> io::Result<Self> {
        let path = search_path();
        let mpv = which("mpv", &path)
            .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, NO_MPV))?;
        let socket_path = socket_path();
        remove_socket(&socket_path);

        let mut command = command(mpv);
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
        let reader = clone_socket(&socket)?;
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

    /// Pone los filtros de audio (`af`): la cadena de `effects_chain`, o vacía para quitarlos.
    pub fn set_effects(&mut self, chain: &str) -> io::Result<()> {
        self.command(json!(["set_property", "af", chain]))
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
        remove_socket(&self.socket_path);
    }
}

/// Dónde escucha mpv. Los sockets Unix admiten rutas de ~104 bytes: con una carpeta temporal
/// larga se usa /tmp. En Windows es una tubería con nombre, que no deja nada en disco.
fn socket_path() -> PathBuf {
    let name = format!("musicplayer-mpv-{}", std::process::id());
    if cfg!(windows) {
        return PathBuf::from(format!(r"\\.\pipe\{name}"));
    }
    let name = format!("{name}.sock");
    let socket_path = env::temp_dir().join(&name);
    if socket_path.as_os_str().len() > 100 {
        return PathBuf::from("/tmp").join(&name);
    }
    socket_path
}

fn remove_socket(path: &Path) {
    if cfg!(unix) {
        let _ = std::fs::remove_file(path);
    }
}

#[cfg(unix)]
fn open_socket(path: &Path) -> io::Result<Ipc> {
    Ipc::connect(path)
}

#[cfg(windows)]
fn open_socket(path: &Path) -> io::Result<Ipc> {
    Ipc::open(path)
}

#[cfg(unix)]
fn clone_socket(socket: &Ipc) -> io::Result<Ipc> {
    socket.try_clone()
}

#[cfg(windows)]
fn clone_socket(socket: &Ipc) -> io::Result<Ipc> {
    Ok(socket.clone())
}

/// mpv crea el socket poco después de arrancar; se reintenta hasta `timeout`.
fn connect(path: &Path, timeout: Duration) -> io::Result<Ipc> {
    let deadline = Instant::now() + timeout;
    loop {
        match open_socket(path) {
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

fn read_events(socket: Ipc, on_event: impl Fn(Event)) {
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
    use super::{effects_chain, Message};

    #[test]
    fn sin_efectos_no_hay_filtros() {
        assert_eq!(effects_chain(&[], 0.0), "");
        assert_eq!(effects_chain(&[0.0; 10], 0.0), "");
    }

    #[test]
    fn bandas_y_amplificador() {
        assert_eq!(
            effects_chain(&[6.0, 0.0, -3.0], 4.0),
            "lavfi=[equalizer=f=31:t=o:w=1:g=6.0,equalizer=f=125:t=o:w=1:g=-3.0,volume=volume=4.0dB,alimiter=limit=0.97:level=disabled]"
        );
    }

    #[test]
    fn solo_recortes_sin_limitador_y_limites() {
        assert_eq!(effects_chain(&[-4.0], 0.0), "lavfi=[equalizer=f=31:t=o:w=1:g=-4.0]");
        assert!(effects_chain(&[40.0], 99.0).contains("g=12.0"));
        assert!(effects_chain(&[40.0], 99.0).contains("volume=12.0dB"));
    }

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
