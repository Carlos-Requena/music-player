//! Resolución de URLs de audio con yt-dlp, con caché y precarga.
//!
//! Obtener la URL de una pista cuesta ~0,3 s por la API del reproductor (`stream.rs`) y
//! 2,5–4 s si hay que recurrir a yt-dlp; reproducir una URL ya resuelta, unos 0,2 s. Por eso se resuelven por adelantado la siguiente pista de la cola y el
//! elemento sobre el que el usuario deja el foco, y al hacer clic la URL ya está aquí.

use std::{
    collections::{HashMap, HashSet},
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Condvar, LazyLock, Mutex,
    },
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use crate::audio::{search_path, which};

/// Opciones › Disposición › «Calidad del audio» = Premium.
static PREMIUM: AtomicBool = AtomicBool::new(false);

/// Cambia la calidad pedida; las URLs ya resueltas se descartan.
pub fn set_premium(premium: bool) {
    if PREMIUM.swap(premium, Ordering::SeqCst) != premium {
        clear();
    }
}

/// Calidad Premium (256 kbps): pedida por el usuario y con sesión iniciada.
pub fn premium_mode() -> bool {
    PREMIUM.load(Ordering::SeqCst) && crate::account::cookies_file().is_some()
}

/// Numera las copias de cookies de cada yt-dlp para que no se pisen.
static COPY_COUNTER: AtomicU64 = AtomicU64::new(0);

/// Procesos de yt-dlp simultáneos como máximo (cada uno es un intérprete de Python).
const MAX_WORKERS: usize = 2;
/// Margen antes de la caducidad que anuncia YouTube en la URL (`expire=`).
const EXPIRY_MARGIN: u64 = 10 * 60;

/// Opciones de yt-dlp compartidas con el gancho de mpv (formato `--opción valor`).
/// Depuración: `MUSICPLAYER_YTDLP_CLIENTS=web_music,…` fuerza los clientes de yt-dlp.
pub fn clients_override() -> Option<String> {
    std::env::var("MUSICPLAYER_YTDLP_CLIENTS").ok().filter(|clients| !clients.is_empty())
}

/// Clientes de YouTube que usa yt-dlp:
/// - Sin sesión, YouTube exige comprobaciones anti-bot a sus clientes por defecto en las
///   pistas de YouTube Music; `web_embedded,mweb` las sirven sin ellas.
/// - Con sesión, `web_music`, el cliente de YouTube Music: es el único que da las pistas que
///   YouTube reserva a cuentas («Art Tracks» de muchos sellos; los demás responden «Video
///   unavailable» aun con cookies) y los formatos Premium de 256 kbps (itags 774 y 141).
pub fn ytdlp_clients() -> String {
    clients_override().unwrap_or_else(|| {
        if crate::account::cookies_file().is_some() { "web_music" } else { "web_embedded,mweb" }.to_owned()
    })
}

pub fn ytdlp_options(path: &str) -> Vec<String> {
    let mut options = Vec::new();
    // Con sesión no hace falta descargar la página del vídeo ni su configuración (yt-dlp ya
    // tiene la de la cuenta): la pista llega en ~1,7 s en vez de ~3 s.
    let skip = if crate::account::cookies_file().is_some() { ";player_skip=webpage,configs" } else { "" };
    options.push(format!("--extractor-args youtube:player_client={}{skip}", ytdlp_clients()));
    // yt-dlp necesita un runtime de JavaScript; usa deno por defecto y hay que
    // indicarle node si es lo único instalado.
    if which("deno", path).is_none() && which("node", path).is_some() {
        options.push("--js-runtimes node".to_owned());
    }
    options
}

enum Entry {
    /// URL lista y momento (segundos UNIX) a partir del cual ya no se usa.
    Ready { url: String, until: u64 },
    /// Hay un yt-dlp trabajando en ella.
    Pending,
}

struct State {
    entries: HashMap<String, Entry>,
    workers: usize,
}

static STATE: LazyLock<(Mutex<State>, Condvar)> = LazyLock::new(|| {
    (Mutex::new(State { entries: HashMap::new(), workers: 0 }), Condvar::new())
});

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs())
}

/// Caducidad de la URL según su parámetro `expire`, o una hora si no lo trae.
fn valid_until(url: &str) -> u64 {
    url.split(['?', '&'])
        .find_map(|pair| pair.strip_prefix("expire="))
        .and_then(|value| value.parse::<u64>().ok())
        .map_or(now() + 3600, |expire| expire.saturating_sub(EXPIRY_MARGIN))
}

/// URL ya resuelta y vigente, sin esperar.
pub fn cached(video_id: &str) -> Option<String> {
    let state = STATE.0.lock().ok()?;
    match state.entries.get(video_id) {
        Some(Entry::Ready { url, until }) if *until > now() => Some(url.clone()),
        _ => None,
    }
}

/// Olvida todas las URLs (al cambiar de sesión cambian los formatos disponibles).
pub fn clear() {
    if let Ok(mut state) = STATE.0.lock() {
        state.entries.retain(|_, entry| matches!(entry, Entry::Pending));
    }
    crate::daemon::shutdown();
}

/// Olvida una URL (por ejemplo, porque mpv no pudo abrirla).
pub fn forget(video_id: &str) {
    if let Ok(mut state) = STATE.0.lock() {
        state.entries.remove(video_id);
    }
}

/// Devuelve la URL de audio de `video_id`, resolviéndola si hace falta. Bloquea: hay
/// que llamarla desde un hilo de trabajo. Si otra llamada ya la está resolviendo,
/// espera a esa en vez de lanzar un segundo yt-dlp.
pub fn resolve(video_id: &str) -> Result<String, String> {
    let (lock, signal) = &*STATE;
    let mut state = lock.lock().map_err(|_| "caché envenenada".to_owned())?;
    loop {
        match state.entries.get(video_id) {
            Some(Entry::Ready { url, until }) if *until > now() => return Ok(url.clone()),
            Some(Entry::Pending) => {
                state = signal.wait(state).map_err(|_| "caché envenenada".to_owned())?;
            }
            _ if state.workers >= MAX_WORKERS => {
                state = signal.wait(state).map_err(|_| "caché envenenada".to_owned())?;
            }
            _ => break,
        }
    }
    state.entries.insert(video_id.to_owned(), Entry::Pending);
    state.workers += 1;
    drop(state);

    // YouTube responde de forma irregular a peticiones sin sesión: el mismo vídeo puede
    // salir sin formatos y, un momento después, con ellos. Un segundo intento suele bastar.
    // Si la pista necesita sesión, repetir no cambia nada.
    let result = run_ytdlp(video_id).or_else(|error| {
        if error == NEEDS_SESSION {
            return Err(error);
        }
        thread::sleep(Duration::from_millis(400));
        run_ytdlp(video_id)
    });

    let mut state = lock.lock().map_err(|_| "caché envenenada".to_owned())?;
    state.workers -= 1;
    match &result {
        Ok(url) => {
            state.entries.insert(video_id.to_owned(), Entry::Ready { url: url.clone(), until: valid_until(url) });
        }
        Err(_) => {
            state.entries.remove(video_id);
        }
    }
    signal.notify_all();
    result
}

/// Última pista que la interfaz pidió precargar y si hay un hilo atendiéndolas.
static WANTED: LazyLock<Mutex<(Option<String>, bool)>> = LazyLock::new(Default::default);

/// Precarga pedida por la interfaz (foco o ratón). Solo cuenta la última: si el usuario
/// recorre veinte carátulas no se lanzan veinte yt-dlp, se resuelve donde se detiene.
pub fn hint(video_id: &str) {
    if video_id.is_empty() || cached(video_id).is_some() {
        return;
    }
    let Ok(mut wanted) = WANTED.lock() else { return };
    wanted.0 = Some(video_id.to_owned());
    if wanted.1 {
        return;
    }
    wanted.1 = true;
    thread::spawn(|| loop {
        let next = match WANTED.lock() {
            Ok(mut wanted) => match wanted.0.take() {
                Some(id) => id,
                None => {
                    wanted.1 = false;
                    return;
                }
            },
            Err(_) => return,
        };
        let _ = resolve(&next);
    });
}

/// Resuelve en segundo plano ya, si no está hecho o en curso (p. ej. la pista siguiente).
pub fn prefetch(video_id: &str) {
    if video_id.is_empty() || cached(video_id).is_some() {
        return;
    }
    if let Ok(state) = STATE.0.lock() {
        if matches!(state.entries.get(video_id), Some(Entry::Pending)) {
            return;
        }
    }
    let video_id = video_id.to_owned();
    thread::spawn(move || {
        let _ = resolve(&video_id);
    });
}

/// Cómo debe leer mpv cada URL: las de la API del reproductor, con su cliente HTTP (con
/// ffmpeg algunas se atascan al empezar); las de yt-dlp, con ffmpeg (`lavf://`), porque el
/// cliente de mpv recibe 403 con ellas.
fn run_ytdlp(video_id: &str) -> Result<String, String> {
    fast_or_ytdlp(video_id).map(|(url, from_ytdlp)| if from_ytdlp { format!("lavf://{url}") } else { url })
}

/// Marca de error: YouTube solo da esta pista con la sesión iniciada.
pub const NEEDS_SESSION: &str = "\u{0}necesita-sesion";

/// Pistas que la vía rápida rechazó y solo llegan con la sesión: no se vuelve a probar con ellas.
static NEEDS_ACCOUNT: LazyLock<Mutex<HashSet<String>>> = LazyLock::new(Default::default);

fn fast_or_ytdlp(video_id: &str) -> Result<(String, bool), String> {
    let known = NEEDS_ACCOUNT.lock().is_ok_and(|set| set.contains(video_id));
    // Directo a yt-dlp con la sesión: en modo Premium (los 256 kbps solo llegan así) y con
    // las pistas que ya se sabe que la vía rápida rechaza.
    let session_first = premium_mode() || (known && crate::account::cookies_file().is_some());
    // Calidad normal: 1) la API del reproductor (~0,3 s, Opus ~160 kbps, lo máximo sin
    // Premium). Premium: los formatos de 256 kbps solo llegan con la sesión, vía yt-dlp.
    if !session_first {
        match crate::stream::resolve(video_id) {
            Ok(url) => return Ok((url, false)),
            // Algunas pistas (muchas «Art Tracks» de sellos japoneses, por ejemplo) YouTube
            // solo las da con sesión: ni la web de YouTube Music las reproduce sin ella. Sin
            // sesión no hay nada que probar; con ella se piden con tus cookies.
            Err(error) if crate::stream::refused(&error) && crate::account::cookies_file().is_none() => {
                eprintln!("{video_id}: {error}; necesita la sesión");
                return Err(NEEDS_SESSION.to_owned());
            }
            Err(error) => {
                if crate::stream::refused(&error) {
                    if let Ok(mut set) = NEEDS_ACCOUNT.lock() {
                        set.insert(video_id.to_owned());
                    }
                }
                eprintln!("vía rápida no disponible para {video_id}: {error}; se usa yt-dlp con la sesión");
            }
        }
    }
    // 2) El yt-dlp residente; 3) si no está disponible, un proceso nuevo.
    if let Some(reply) = crate::daemon::resolve(video_id) {
        if reply.is_ok() || !session_first {
            return reply.map(|url| (url, true));
        }
    }
    if session_first {
        if let Ok(url) = run_ytdlp_process(video_id) {
            return Ok((url, true));
        }
        // Si la vía Premium falla, mejor sonar en calidad normal que no sonar.
        return crate::stream::resolve(video_id).map(|url| (url, false));
    }
    run_ytdlp_process(video_id).map(|url| (url, true))
}

fn run_ytdlp_process(video_id: &str) -> Result<String, String> {
    let path = search_path();
    let ytdlp = which("yt-dlp", &path).ok_or("no se encuentra yt-dlp")?;
    let mut command = Command::new(ytdlp);
    command.env("PATH", &path).args(["--no-warnings", "--no-playlist", "-f", "bestaudio/best", "-g"]);
    for option in ytdlp_options(&path) {
        command.args(option.splitn(2, ' '));
    }
    // Con sesión, yt-dlp usa las cookies (calidad Premium y menos rechazos). Recibe una
    // copia propia: al terminar reescribe el archivo y no debe tocar el original.
    let cookies = crate::account::cookies_copy(&format!("ytdlp-{}", COPY_COUNTER.fetch_add(1, Ordering::Relaxed)));
    if let Some(copy) = &cookies {
        command.arg("--cookies").arg(copy);
    }
    let output = command
        .arg(format!("https://www.youtube.com/watch?v={video_id}"))
        .stdin(Stdio::null())
        .stderr(Stdio::piped())
        .output();
    if let Some(copy) = cookies {
        let _ = std::fs::remove_file(copy);
    }
    let output = output.map_err(|error| format!("no se pudo ejecutar yt-dlp: {error}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let reason = stderr.lines().rev().find(|line| line.starts_with("ERROR")).unwrap_or("error desconocido");
        return Err(format!("yt-dlp: {reason}"));
    }
    String::from_utf8_lossy(&output.stdout)
        .lines()
        .next()
        .filter(|url| url.starts_with("http"))
        .map(str::to_owned)
        .ok_or_else(|| "yt-dlp no devolvió ninguna URL".to_owned())
}

/// Espera breve usada por las pruebas para dejar terminar las precargas.
#[allow(dead_code)]
pub fn settle(timeout: Duration) {
    let deadline = std::time::Instant::now() + timeout;
    while std::time::Instant::now() < deadline {
        if STATE.0.lock().map_or(true, |state| state.workers == 0) {
            return;
        }
        thread::sleep(Duration::from_millis(50));
    }
}
