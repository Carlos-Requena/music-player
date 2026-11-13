//! yt-dlp residente (`ytdlp_daemon.py`): resuelve sin pagar el arranque de Python y
//! reutilizando el código del reproductor de YouTube ya descargado.
//!
//! Se lanza con el mismo intérprete que usa el `yt-dlp` instalado (su línea `#!`). Si yt-dlp
//! no es un script de Python (binario autónomo), `resolve` devuelve `None` y el resolver
//! usa un proceso por petición. El servidor se cierra solo tras un minuto sin uso y se puede
//! desactivar en Opciones (ocupa ~120 MB mientras vive).

use std::{
    collections::HashMap,
    fs,
    io::{BufRead, BufReader, Write},
    path::PathBuf,
    process::{Child, ChildStdin, Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc, Arc, LazyLock, Mutex,
    },
    thread,
    time::Duration,
};

use serde_json::{json, Value};

use crate::audio::{search_path, which};

const SCRIPT: &str = include_str!("ytdlp_daemon.py");
/// Más que esto y se da por perdida la petición (el resolver probará otra vía).
const TIMEOUT: Duration = Duration::from_secs(45);

type Reply = Result<String, String>;

struct Daemon {
    child: Child,
    stdin: ChildStdin,
    alive: Arc<AtomicBool>,
}

/// Opciones › Disposición › «yt-dlp residente».
static ENABLED: AtomicBool = AtomicBool::new(true);

pub fn set_enabled(enabled: bool) {
    ENABLED.store(enabled, Ordering::SeqCst);
    if !enabled {
        shutdown();
    }
}

static DAEMON: LazyLock<Mutex<Option<Daemon>>> = LazyLock::new(Default::default);
static WAITERS: LazyLock<Mutex<HashMap<String, Vec<mpsc::Sender<Reply>>>>> = LazyLock::new(Default::default);

/// Intérprete de Python del yt-dlp instalado, leído de su línea `#!`.
fn interpreter(path: &str) -> Option<Vec<String>> {
    let script = fs::canonicalize(which("yt-dlp", path)?).ok()?;
    let head = fs::read(&script).ok()?;
    let first = head.split(|&byte| byte == b'\n').next()?;
    let line = std::str::from_utf8(first).ok()?.strip_prefix("#!")?.trim();
    let parts: Vec<String> = line.split_whitespace().map(str::to_owned).collect();
    let program = parts.first()?;
    (program.contains("python") || parts.iter().any(|part| part.contains("python"))).then_some(parts)
}

fn options(path: &str) -> Value {
    let mut options = json!({
        "quiet": true,
        "no_warnings": true,
        "noplaylist": true,
        "format": "bestaudio/best",
    });
    // Los mismos clientes que `resolver::ytdlp_options` (ver allí el porqué).
    let clients = crate::resolver::ytdlp_clients();
    let list: Vec<&str> = clients.split(',').collect();
    options["extractor_args"] = json!({ "youtube": { "player_client": list } });
    if crate::account::cookies_file().is_some() {
        // Ver `resolver::ytdlp_options`: ~1,7 s en vez de ~3 s por pista.
        options["extractor_args"]["youtube"]["player_skip"] = json!(["webpage", "configs"]);
    }
    if which("deno", path).is_none() && which("node", path).is_some() {
        options["js_runtimes"] = json!({ "node": {} });
    }
    if let Some(cookies) = crate::account::cookies_copy("daemon") {
        options["cookiefile"] = json!(cookies.display().to_string());
    }
    options
}

fn spawn() -> Option<Daemon> {
    let path = search_path();
    let mut command_line = interpreter(&path)?;
    let program = command_line.remove(0);
    let mut child = Command::new(program)
        .args(command_line)
        .arg("-I")
        .arg("-c")
        .arg(SCRIPT)
        .arg(options(&path).to_string())
        .env("PATH", &path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
    let stdin = child.stdin.take()?;
    let mut lines = BufReader::new(child.stdout.take()?).lines();

    // Espera a que yt-dlp esté cargado.
    match lines.next() {
        Some(Ok(line)) if line.contains("\"ready\"") => {}
        _ => {
            let _ = child.kill();
            return None;
        }
    }

    let alive = Arc::new(AtomicBool::new(true));
    let flag = alive.clone();
    thread::spawn(move || {
        for line in lines {
            let Ok(line) = line else { break };
            let Ok(message) = serde_json::from_str::<Value>(&line) else { continue };
            let Some(id) = message["id"].as_str() else { continue };
            let reply = match message["url"].as_str() {
                Some(url) => Ok(url.to_owned()),
                None => Err(format!("yt-dlp: {}", message["error"].as_str().unwrap_or("error desconocido"))),
            };
            let waiting = WAITERS.lock().ok().and_then(|mut waiters| waiters.remove(id)).unwrap_or_default();
            for sender in waiting {
                let _ = sender.send(reply.clone());
            }
        }
        // Se cerró (inactividad o fallo): quien esperaba recibe error y usará otra vía.
        flag.store(false, Ordering::SeqCst);
        if let Ok(mut waiters) = WAITERS.lock() {
            for (_, senders) in waiters.drain() {
                for sender in senders {
                    let _ = sender.send(Err("el servidor de yt-dlp se cerró".to_owned()));
                }
            }
        }
    });

    Some(Daemon { child, stdin, alive })
}

/// Resuelve `video_id` con el servidor residente. `None` si no se puede usar (y entonces
/// conviene un proceso de yt-dlp normal).
pub fn resolve(video_id: &str) -> Option<Reply> {
    if !ENABLED.load(Ordering::SeqCst) {
        return None;
    }
    let (sender, receiver) = mpsc::channel();
    {
        let mut daemon = DAEMON.lock().ok()?;
        if !daemon.as_ref().is_some_and(|d| d.alive.load(Ordering::SeqCst)) {
            if let Some(mut old) = daemon.take() {
                let _ = old.child.kill();
                let _ = old.child.wait();
            }
            *daemon = Some(spawn()?);
        }
        WAITERS.lock().ok()?.entry(video_id.to_owned()).or_default().push(sender);
        let line = format!("{}\n", json!({ "id": video_id }));
        if daemon.as_mut()?.stdin.write_all(line.as_bytes()).is_err() {
            daemon.take();
            return None;
        }
    }
    match receiver.recv_timeout(TIMEOUT) {
        Ok(Err(error)) if error.contains("se cerró") => None,
        Ok(reply) => Some(reply),
        Err(_) => None,
    }
}

/// Cierra el servidor (al cambiar de sesión sus cookies dejan de valer).
pub fn shutdown() {
    if let Ok(mut daemon) = DAEMON.lock() {
        if let Some(mut old) = daemon.take() {
            let _ = old.child.kill();
            let _ = old.child.wait();
        }
    }
}

/// Ruta del intérprete detectado, para diagnósticos (`--probe daemon`).
#[allow(dead_code)]
pub fn interpreter_path() -> Option<PathBuf> {
    interpreter(&search_path()).map(|parts| PathBuf::from(&parts[0]))
}
