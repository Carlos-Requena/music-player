//! Resolución de URLs de audio con yt-dlp, con caché y precarga.
//!
//! Obtener la URL de una pista cuesta ~0,3 s por la API del reproductor (`stream.rs`) y
//! 2,5–4 s si hay que recurrir a yt-dlp; reproducir una URL ya resuelta, unos 0,2 s. Por eso se resuelven por adelantado la siguiente pista de la cola y el
//! elemento sobre el que el usuario deja el foco, y al hacer clic la URL ya está aquí.

use std::{
    collections::{HashMap, HashSet},
    process::Stdio,
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
        PREMIUM_FAILED_AT.store(0, Ordering::Relaxed);
        clear();
    }
}

/// Calidad Premium (256 kbps): pedida por el usuario y con sesión iniciada.
pub fn premium_mode() -> bool {
    PREMIUM.load(Ordering::SeqCst) && crate::account::cookies_file().is_some()
}

/// Momento (segundos UNIX) en que la vía Premium falló con una pista que la vía rápida sí dio.
static PREMIUM_FAILED_AT: AtomicU64 = AtomicU64::new(0);
/// Tiempo que se usa la vía rápida tras ese fallo antes de volver a probar Premium.
const PREMIUM_PAUSE: u64 = 10 * 60;

/// yt-dlp no está dando Premium (p. ej. una versión que ya no resuelve los retos de YouTube):
/// mientras dure la pausa, la calidad normal de la vía rápida, en décimas en vez de ~5 s.
fn premium_paused() -> bool {
    now().saturating_sub(PREMIUM_FAILED_AT.load(Ordering::Relaxed)) < PREMIUM_PAUSE
}

fn pause_premium() {
    if !premium_paused() {
        eprintln!("calidad Premium: yt-dlp no la da; vía rápida durante {} min", PREMIUM_PAUSE / 60);
    }
    PREMIUM_FAILED_AT.store(now(), Ordering::Relaxed);
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

/// Devuelve la URL de audio de `video_id` para reproducirla ya (un clic, pasar de pista),
/// resolviéndola si hace falta. Bloquea: hay que llamarla desde un hilo de trabajo. Si otra
/// llamada ya la está resolviendo (una precarga), espera a esa en vez de lanzar otra.
pub fn resolve(video_id: &str) -> Result<String, String> {
    resolve_with(video_id, true)
}

/// `urgent`: la pide el usuario. No espera a que acaben las precargas (`MAX_WORKERS` solo
/// limita a estas) y, si falla, lo reintenta una vez. Una precarga no reintenta: si YouTube está
/// rechazando, insistir empeora el rechazo, y el clic ya reintentará.
fn resolve_with(video_id: &str, urgent: bool) -> Result<String, String> {
    let (lock, signal) = &*STATE;
    let mut state = lock.lock().map_err(|_| "caché envenenada".to_owned())?;
    loop {
        match state.entries.get(video_id) {
            Some(Entry::Ready { url, until }) if *until > now() => return Ok(url.clone()),
            Some(Entry::Pending) => {
                state = signal.wait(state).map_err(|_| "caché envenenada".to_owned())?;
            }
            _ if !urgent && state.workers >= MAX_WORKERS => {
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
        if error == NEEDS_SESSION || !urgent || unavailable(&error) {
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

/// YouTube dice que el vídeo no existe aquí (bloqueado en esta región o retirado): repetir no
/// cambia nada.
fn unavailable(error: &str) -> bool {
    // «Requested format is not available» no cuenta: es yt-dlp sin formatos, no la pista.
    ["no está disponible", "Video unavailable", "video is not available"].iter().any(|text| error.contains(text))
}

/// Edición equivalente de cada pista que no se pudo resolver (`videoId` original → otro).
static ALTERNATIVES: LazyLock<Mutex<HashMap<String, String>>> = LazyLock::new(Default::default);

/// Otra edición ya encontrada para `video_id`, si se buscó antes.
pub fn known_alternative(video_id: &str) -> Option<String> {
    ALTERNATIVES.lock().ok().and_then(|map| map.get(video_id).cloned())
}

/// Otra edición de la misma canción que sí suena, para una pista que no se pudo resolver.
///
/// Con la sesión, YouTube Music puede dar la edición de otra región (la japonesa de un single
/// de HOYO-MiX, por ejemplo), que solo suena con yt-dlp y las cookies: en calidad normal, o si
/// yt-dlp falla, no suena. Se busca la canción sin la cuenta y se toma el primer resultado que
/// sea la misma canción (`same_song`) y que sí se resuelva. Devuelve `(videoId, URL)`.
/// Bloquea (una búsqueda y una o varias resoluciones): desde un hilo de trabajo.
pub fn alternative(video_id: &str, title: &str, artist: &str, duration: f64) -> Option<(String, String)> {
    if let Some(other) = known_alternative(video_id) {
        return resolve(&other).ok().map(|url| (other, url));
    }
    let first_artist = main_artist(artist);
    let found = crate::ytm::search_songs_anonymous(&format!("{title} {first_artist}"))
        .map_err(|error| eprintln!("otra edición de {video_id}: {error}"))
        .ok()?;
    for candidate in found.iter().filter(|track| track.video_id != video_id && same_song(title, artist, duration, track)).take(3) {
        if let Ok(url) = resolve(&candidate.video_id) {
            eprintln!("{video_id} no está disponible: suena otra edición, {}", candidate.video_id);
            if let Ok(mut map) = ALTERNATIVES.lock() {
                map.insert(video_id.to_owned(), candidate.video_id.clone());
            }
            return Some((candidate.video_id.clone(), url));
        }
    }
    eprintln!("{video_id} no está disponible y no se encontró otra edición");
    None
}

/// Palabras de un título o artista, en minúsculas y sin signos (los kanji y kana cuentan).
fn words(text: &str) -> Vec<String> {
    text.to_lowercase().split(|c: char| !c.is_alphanumeric()).filter(|word| !word.is_empty()).map(str::to_owned).collect()
}

/// Primer artista de «A y B», «A & B», «A, B» o «A feat. B».
fn main_artist(artist: &str) -> &str {
    [" y ", " & ", ", ", " feat", " ft.", " x "]
        .iter()
        .filter_map(|separator| artist.find(separator))
        .min()
        .map_or(artist, |end| &artist[..end])
        .trim()
}

/// Si `candidate` es la misma canción: las palabras de un título dentro de las del otro
/// («さざ波 La vaguelette» y «La vaguelette»), sin que una sea otra versión (instrumental, remix,
/// en directo…), y además el mismo artista principal con la duración a ±3 s (si se conocen las
/// dos) o, si el artista viene traducido («物語シリーズ» y «MONOGATARI Series»), la duración a ±1 s.
fn same_song(title: &str, artist: &str, duration: f64, candidate: &crate::ytm::Track) -> bool {
    let difference = (duration > 0.0 && candidate.duration > 0.0).then(|| (duration - candidate.duration).abs());
    let same_artist = words(main_artist(artist)) == words(main_artist(&candidate.artist));
    let close = if same_artist { difference.is_none_or(|d| d <= 3.0) } else { difference.is_some_and(|d| d <= 1.0) };
    if !close {
        return false;
    }
    let (ours, theirs) = (words(title), words(&candidate.title));
    let variants = ["instrumental", "inst", "remix", "live", "karaoke", "acoustic", "cover", "sped", "slowed"];
    if variants.iter().any(|variant| ours.iter().any(|w| w == variant) != theirs.iter().any(|w| w == variant)) {
        return false;
    }
    let (short, long) = if ours.len() <= theirs.len() { (&ours, &theirs) } else { (&theirs, &ours) };
    !short.is_empty() && short.iter().all(|word| long.contains(word))
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
        let _ = resolve_with(&next, false);
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
        let _ = resolve_with(&video_id, false);
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

/// Pistas que YouTube da por no disponibles por todas las vías (la vía rápida y yt-dlp con la
/// sesión): no se vuelven a pedir, y `alternative` busca otra edición al momento.
static UNAVAILABLE: LazyLock<Mutex<HashSet<String>>> = LazyLock::new(Default::default);

/// Pistas que yt-dlp con la sesión da por no disponibles y la vía rápida sí da (la cuenta ve otra
/// región): en Premium van directas a la vía rápida, sin esperar a otro yt-dlp.
static FAST_ONLY: LazyLock<Mutex<HashSet<String>>> = LazyLock::new(Default::default);

fn fast_or_ytdlp(video_id: &str) -> Result<(String, bool), String> {
    if UNAVAILABLE.lock().is_ok_and(|set| set.contains(video_id)) {
        return Err("no está disponible (ya comprobado)".to_owned());
    }
    let known = NEEDS_ACCOUNT.lock().is_ok_and(|set| set.contains(video_id));
    // Directo a yt-dlp con la sesión: en modo Premium (los 256 kbps solo llegan así; salvo si
    // acaba de fallar, `premium_paused`) y con las pistas que ya se sabe que la vía rápida rechaza.
    let fast_only = FAST_ONLY.lock().is_ok_and(|set| set.contains(video_id));
    let premium = premium_mode() && !premium_paused() && !fast_only;
    let session_first = premium || (known && crate::account::cookies_file().is_some());
    let mark_unavailable = |fast: &str, ytdlp: &str| {
        if unavailable(fast) && unavailable(ytdlp) {
            if let Ok(mut set) = UNAVAILABLE.lock() {
                set.insert(video_id.to_owned());
            }
        }
    };
    // Calidad normal: 1) la API del reproductor (~0,3 s, Opus ~160 kbps, lo máximo sin
    // Premium). Premium: los formatos de 256 kbps solo llegan con la sesión, vía yt-dlp.
    if !session_first {
        let fast_error = match crate::stream::resolve(video_id) {
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
                error
            }
        };
        return ytdlp(video_id, false).map(|url| (url, true)).inspect_err(|error| mark_unavailable(&fast_error, error));
    }
    let ytdlp_error = match ytdlp(video_id, true) {
        Ok(url) => return Ok((url, true)),
        Err(error) => error,
    };
    // Si la vía Premium falla, mejor sonar en calidad normal que no sonar. Si la vía rápida sí
    // da la pista: con «no disponible», la cuenta no la ve (esa pista irá por la vía rápida);
    // con otro error, el fallo es de yt-dlp y Premium se aparca un rato para que las siguientes
    // no esperen a otro yt-dlp fallido.
    let fast = crate::stream::resolve(video_id).map(|url| (url, false));
    match &fast {
        Ok(_) if premium && unavailable(&ytdlp_error) => {
            if let Ok(mut set) = FAST_ONLY.lock() {
                set.insert(video_id.to_owned());
            }
        }
        Ok(_) if premium => pause_premium(),
        Err(error) => mark_unavailable(error, &ytdlp_error),
        Ok(_) => {}
    }
    fast
}

/// 2) El yt-dlp residente; 3) si no está disponible (o, con `process`, si falla), un proceso
/// nuevo. Si el residente dice que el vídeo no está disponible, otro yt-dlp diría lo mismo.
fn ytdlp(video_id: &str, process: bool) -> Result<String, String> {
    match crate::daemon::resolve(video_id) {
        Some(Ok(url)) => Ok(url),
        Some(Err(error)) if !process || unavailable(&error) => Err(error),
        _ => run_ytdlp_process(video_id),
    }
}

fn run_ytdlp_process(video_id: &str) -> Result<String, String> {
    let path = search_path();
    let ytdlp = which("yt-dlp", &path).ok_or("no se encuentra yt-dlp")?;
    let mut command = crate::audio::command(ytdlp);
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ytm::Track;

    fn track(title: &str, artist: &str, duration: f64) -> Track {
        Track { title: title.into(), artist: artist.into(), duration, ..Default::default() }
    }

    #[test]
    fn reconoce_otra_edicion_de_la_misma_cancion() {
        let original = ("さざ波 La vaguelette", "HOYO-MiX y Cécilia Cara", 150.0);
        let same = |candidate: &Track| same_song(original.0, original.1, original.2, candidate);
        assert!(same(&track("La vaguelette", "HOYO-MiX y Cécilia Cara", 150.0)));
        assert!(same(&track("La vaguelette", "HOYO-MiX", 151.0)));
        // Otra canción, otra duración, otro artista u otra versión: no.
        assert!(!same(&track("Comme il vous plaira", "HOYO-MiX", 115.0)));
        assert!(!same(&track("La vaguelette", "HOYO-MiX", 180.0)));
        assert!(!same(&track("La vaguelette", "Otro", 155.0)));
        assert!(!same(&track("La vaguelette (Instrumental)", "HOYO-MiX", 150.0)));
        // Artista traducido: vale con la misma duración, no con otra.
        assert!(same_song("リスキーな真似", "物語シリーズ", 160.0, &track("リスキーな真似 - Risukina Mane", "MONOGATARI Series", 160.0)));
        assert!(!same_song("リスキーな真似", "物語シリーズ", 160.0, &track("リスキーな真似", "MONOGATARI Series", 175.0)));
        assert!(!same_song("Intro", "Uno", 0.0, &track("Intro", "Otro", 90.0)));
    }

    #[test]
    fn artista_principal() {
        assert_eq!(main_artist("HOYO-MiX y Cécilia Cara"), "HOYO-MiX");
        assert_eq!(main_artist("Yu-Peng Chen & HOYO-MiX"), "Yu-Peng Chen");
        assert_eq!(main_artist("HOYO-MiX"), "HOYO-MiX");
    }

    #[test]
    fn no_disponible() {
        assert!(unavailable("player (UNPLAYABLE): Este vídeo no está disponible"));
        assert!(unavailable("yt-dlp: ERROR: [youtube] x: Video unavailable. This video is not available"));
        assert!(!unavailable("yt-dlp: ERROR: HTTP Error 403"));
        assert!(!unavailable("yt-dlp: ERROR: [youtube] x: Requested format is not available. Use --list-formats"));
    }
}
