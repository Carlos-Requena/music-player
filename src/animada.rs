//! Carátula animada de Apple Music para «Sonando».
//!
//! Algunos álbumes de Apple Music tienen un vídeo corto en bucle en lugar de la carátula fija
//! («motion artwork»). Para la pista que suena:
//!
//! 1. Se busca la canción en la API pública de iTunes (`itunes.apple.com/search`, sin cuenta) y
//!    se toma su álbum (`collectionId`) si el título y el artista coinciden.
//! 2. Se lee la página pública del álbum (`music.apple.com/us/album/<id>`): si tiene carátula
//!    animada, trae `motionDetailSquare` con la lista HLS (`.m3u8`) del vídeo cuadrado.
//! 3. `ffmpeg` copia (sin recodificar) la variante H.264 de hasta `MAX_SIDE` px a un MP4 en
//!    `<caché>/musicplayer/animadas/<id>.mp4`, que QML reproduce en bucle.
//!
//! El resultado de cada canción (álbum o «no tiene») se guarda en `indice.json`, así que a Apple
//! se le pregunta una sola vez. No es una API oficial: si Apple cambia su página, simplemente no
//! se encuentra nada y queda la carátula fija.

use std::{
    collections::HashMap,
    fs,
    io::Read,
    path::{Path, PathBuf},
    process::Stdio,
    sync::Mutex,
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use serde_json::Value;

const USER_AGENT: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";
const TIMEOUT: Duration = Duration::from_secs(10);
/// Lado máximo del vídeo que se descarga: la carátula de «Sonando» ocupa unos 700 px lógicos.
const MAX_SIDE: u32 = 960;
/// Tiempo máximo que se deja a `ffmpeg` para descargar el vídeo.
const FFMPEG_LIMIT: Duration = Duration::from_secs(90);
/// Vídeos que se guardan en la caché; al pasar de ahí se borran los más antiguos.
const MAX_VIDEOS: usize = 40;
/// Un «no tiene» se vuelve a comprobar pasado este tiempo (Apple añade animaciones a veces).
const RECHECK_NONE: u64 = 30 * 24 * 3600;

/// Una búsqueda a la vez: dos canciones del mismo álbum no lo descargan dos veces.
static LOCK: Mutex<()> = Mutex::new(());

#[derive(Serialize, Deserialize, Clone)]
struct Entry {
    /// Álbum de Apple con carátula animada; vacío si no tiene (o no se encontró).
    album: String,
    /// Cuándo se comprobó, en segundos desde 1970.
    at: u64,
}

fn dir() -> Option<PathBuf> {
    dirs::cache_dir().map(|dir| dir.join("musicplayer").join("animadas"))
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn read_index() -> HashMap<String, Entry> {
    dir()
        .and_then(|dir| fs::read_to_string(dir.join("indice.json")).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default()
}

fn write_index(index: &HashMap<String, Entry>) {
    let Some(dir) = dir() else { return };
    let path = dir.join("indice.json");
    if let Err(error) = fs::create_dir_all(&dir)
        .and_then(|()| fs::write(&path, serde_json::to_string(index).unwrap_or_default()))
    {
        eprintln!("animada: guardar en {}: {error}", path.display());
    }
}

/// Minúsculas, sin acentos de puntuación ni paréntesis: «Rude Buster (Piano)» → «rude buster».
fn normalize(text: &str) -> String {
    let mut out = String::new();
    let mut depth = 0;
    for c in text.to_lowercase().chars() {
        match c {
            '(' | '[' => depth += 1,
            ')' | ']' => depth = i32::max(depth - 1, 0),
            _ if depth > 0 => {}
            c if c.is_alphanumeric() => out.push(c),
            _ => {
                if !out.ends_with(' ') && !out.is_empty() {
                    out.push(' ');
                }
            }
        }
    }
    out.trim().to_owned()
}

/// Artistas sueltos de un texto como «Toby Fox & Trevor Alan Gomes, X feat. Y».
fn artists(text: &str) -> Vec<String> {
    let lower = text.to_lowercase();
    lower
        .split(['&', ',', '·', '/'])
        .flat_map(|part| part.split(" feat. ").flat_map(|p| p.split(" ft. ")).flat_map(|p| p.split(" x ")))
        .flat_map(|part| part.split(" and ").flat_map(|p| p.split(" y ")))
        .map(normalize)
        .filter(|name| !name.is_empty())
        .collect()
}

/// Uno dentro del otro, sin paréntesis ni mayúsculas.
fn same_name(a: &str, b: &str) -> bool {
    let (a, b) = (normalize(a), normalize(b));
    !a.is_empty() && !b.is_empty() && (a == b || a.contains(&b) || b.contains(&a))
}

/// ¿El resultado de iTunes es la misma canción? El título debe coincidir y, además, el álbum
/// (si se conoce) o al menos un artista: YouTube Music a veces solo da el compositor («Toby
/// Fox») de un álbum que Apple pone a nombre del intérprete.
fn matches(song: &Song, apple_title: &str, apple_artist: &str, apple_album: &str) -> bool {
    if !same_name(&song.title, apple_title) {
        return false;
    }
    if !song.album.is_empty() && same_name(&song.album, apple_album) {
        return true;
    }
    let artist = song.artist.as_str();
    let apple = normalize(apple_artist);
    let ours = normalize(artist);
    artists(artist).iter().any(|name| apple.contains(name.as_str()))
        || artists(apple_artist).iter().any(|name| ours.contains(name.as_str()))
}

fn get(url: &str) -> Option<String> {
    let request = crate::ytm::http()
        .get(url)
        .header("User-Agent", USER_AGENT)
        .config()
        .timeout_global(Some(TIMEOUT))
        .build();
    match request.call() {
        Ok(mut response) => response.body_mut().with_config().limit(8 << 20).read_to_string().ok(),
        Err(error) => {
            eprintln!("animada: {url}: {error}");
            None
        }
    }
}

/// La canción que se busca en Apple.
pub struct Song {
    pub title: String,
    pub artist: String,
    /// Álbum según YouTube Music; vacío si no se sabe.
    pub album: String,
}

/// Álbumes de Apple candidatos para la canción, del que mejor coincide al peor.
fn find_albums(song: &Song) -> Vec<String> {
    let mut albums = Vec::new();
    // Primero con el álbum en la búsqueda (encuentra la versión justa entre muchas), luego con
    // el artista.
    let mut terms = vec![format!("{} {}", normalize(&song.title), normalize(&song.album))];
    terms.push(format!("{} {}", song.artist, normalize(&song.title)));
    if song.album.is_empty() {
        terms.remove(0);
    }
    for term in terms {
        for id in search(song, &term) {
            if !albums.contains(&id) {
                albums.push(id);
            }
        }
        if !albums.is_empty() {
            break;
        }
    }
    albums.truncate(3);
    albums
}

fn search(song: &Song, term: &str) -> Vec<String> {
    let url = format!(
        "https://itunes.apple.com/search?entity=song&limit=10&term={}",
        encode(&term)
    );
    let Some(json) = get(&url).and_then(|text| serde_json::from_str::<Value>(&text).ok()) else {
        return Vec::new();
    };
    let mut albums = Vec::new();
    for result in json["results"].as_array().into_iter().flatten() {
        let apple_title = result["trackName"].as_str().unwrap_or_default();
        let apple_artist = result["artistName"].as_str().unwrap_or_default();
        let apple_album = result["collectionName"].as_str().unwrap_or_default();
        let Some(id) = result["collectionId"].as_u64() else { continue };
        if matches(song, apple_title, apple_artist, apple_album) && !albums.contains(&id.to_string()) {
            albums.push(id.to_string());
        }
    }
    albums
}

fn encode(text: &str) -> String {
    let mut out = String::new();
    for byte in text.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(byte as char),
            b' ' => out.push('+'),
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}

/// Lista HLS del vídeo cuadrado en la página de un álbum, si la tiene.
fn motion_playlist(page: &str) -> Option<String> {
    let start = page.find("\"motionDetailSquare\"")?;
    // El objeto es corto (la imagen de vista previa y el vídeo): no se busca más allá.
    let window = &page[start..(start + 4000).min(page.len())];
    let video = window.find("\"video\":\"")? + "\"video\":\"".len();
    let end = window[video..].find('"')? + video;
    let url = window[video..end].replace("\\u002F", "/").replace("\\/", "/");
    (url.starts_with("https://") && url.contains(".m3u8")).then_some(url)
}

/// Variante H.264 de mayor lado que no pase de `MAX_SIDE` (y, a igual lado, la de más calidad).
fn pick_variant(master: &str) -> Option<String> {
    let mut best: Option<(u32, u64, String)> = None;
    let mut lines = master.lines();
    while let Some(line) = lines.next() {
        let Some(attrs) = line.strip_prefix("#EXT-X-STREAM-INF:") else { continue };
        let Some(uri) = lines.next().map(str::trim).filter(|uri| !uri.starts_with('#')) else { continue };
        if !attrs.contains("avc1") {
            continue;
        }
        let attr = |name: &str| {
            attrs.split(',').find_map(|part| part.strip_prefix(name)).unwrap_or_default().to_owned()
        };
        let side: u32 = attr("RESOLUTION=").split('x').next().and_then(|w| w.parse().ok()).unwrap_or(0);
        let bandwidth: u64 = attr("BANDWIDTH=").parse().unwrap_or(0);
        if side == 0 || side > MAX_SIDE {
            continue;
        }
        if best.as_ref().is_none_or(|(s, b, _)| (side, bandwidth) > (*s, *b)) {
            best = Some((side, bandwidth, uri.to_owned()));
        }
    }
    best.map(|(_, _, uri)| uri)
}

/// Si todos los fragmentos de la variante son trozos (`BYTERANGE`) de un mismo archivo, como en
/// Apple, su URL: se descarga entero. `ffmpeg` con esas listas se queda en el primer fragmento.
fn single_file(variant_url: &str, playlist: &str) -> Option<String> {
    let mut files = playlist
        .lines()
        .filter_map(|line| match line.strip_prefix("#EXT-X-MAP:") {
            Some(map) => map.split("URI=\"").nth(1)?.split('"').next(),
            None => (!line.starts_with('#') && !line.trim().is_empty()).then_some(line.trim()),
        });
    let first = files.next()?;
    if files.any(|file| file != first) {
        return None;
    }
    if first.starts_with("https://") {
        return Some(first.to_owned());
    }
    let base = &variant_url[..variant_url.rfind('/')? + 1];
    Some(format!("{base}{first}"))
}

/// Descarga un archivo entero a `target` (hasta 64 MB).
fn fetch_file(url: &str, target: &Path) -> bool {
    let request = crate::ytm::http()
        .get(url)
        .header("User-Agent", USER_AGENT)
        .config()
        .timeout_global(Some(FFMPEG_LIMIT))
        .build();
    let bytes = request
        .call()
        .map_err(|error| eprintln!("animada: {url}: {error}"))
        .ok()
        .and_then(|mut response| response.body_mut().with_config().limit(64 << 20).read_to_vec().ok());
    bytes.is_some_and(|bytes| fs::write(target, bytes).is_ok())
}

/// Descarga la variante a `target` como un MP4 normal y le funde el final con el principio
/// (`loop_filter`) para que el bucle no se corte. Si no se puede recodificar, queda la copia tal
/// cual (con el corte).
fn download(variant: &str, target: &Path) -> bool {
    let source = target.with_extension("fuente.mp4");
    let input = match get(variant).and_then(|playlist| single_file(variant, &playlist)) {
        Some(file) if fetch_file(&file, &source) => source.to_string_lossy().into_owned(),
        _ => variant.to_owned(),
    };
    let copy = target.with_extension("copia.mp4");
    let mut args: Vec<String> = Vec::new();
    if input.starts_with("https://") {
        args.extend(["-user_agent".into(), USER_AGENT.into()]);
    }
    args.extend(["-i".into(), input]);
    args.extend(["-map", "0:v:0", "-c", "copy", "-an"].map(String::from));
    let copied = ffmpeg(&args, &copy);
    let _ = fs::remove_file(&source);
    if !copied {
        return false;
    }
    if !seamless(&copy, target) {
        eprintln!("animada: sin fundido de bucle; se guarda el vídeo tal cual");
        if fs::rename(&copy, target).is_err() {
            return false;
        }
    }
    let _ = fs::remove_file(&copy);
    true
}

/// Fotogramas y fotogramas por segundo del vídeo (con `ffprobe`).
fn frames(file: &Path) -> Option<(u32, f64)> {
    let ffprobe = crate::audio::which("ffprobe", &crate::audio::search_path())?;
    let output = crate::audio::command(ffprobe)
        .args(["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=nb_frames,r_frame_rate"])
        .args(["-of", "default=noprint_wrappers=1"])
        .arg(file)
        .stdin(Stdio::null())
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    let field = |name: &str| text.lines().find_map(|line| line.strip_prefix(name)).map(str::trim);
    let count = field("nb_frames=")?.parse().ok()?;
    let (num, den) = field("r_frame_rate=")?.split_once('/')?;
    let fps = num.parse::<f64>().ok()? / den.parse::<f64>().ok()?;
    (fps > 0.0).then_some((count, fps))
}

/// Filtro de `ffmpeg` que convierte un vídeo de `count` fotogramas en un bucle sin corte: el
/// vídeo empieza en el fotograma `fade + 1` y su último segundo se funde con el primero del
/// original (`xfade`), que sigue hasta el fotograma `fade`. Al volver a empezar, tras el
/// fotograma `fade` viene el `fade + 1`: la costura es como dos fotogramas seguidos cualesquiera.
/// `None` si el vídeo es demasiado corto (menos de 4 s) para fundirlo.
fn loop_filter(count: u32, fps: f64) -> Option<String> {
    let fade = fps.round() as u32;
    if fade == 0 || count < 4 * fade {
        return None;
    }
    let main = count - fade - 1;
    let offset = f64::from(main - fade) / fps;
    let duration = f64::from(fade) / fps;
    Some(format!(
        "[0:v]split[a][b];[a]trim=start_frame={start},setpts=PTS-STARTPTS[m];\
         [b]trim=end_frame={start},setpts=PTS-STARTPTS[h];\
         [m][h]xfade=transition=fade:duration={duration:.4}:offset={offset:.4},format=yuv420p[v]",
        start = fade + 1
    ))
}

/// Recodifica `copy` como bucle sin corte en `target` (H.264, sin pérdida visible).
fn seamless(copy: &Path, target: &Path) -> bool {
    let Some(filter) = frames(copy).and_then(|(count, fps)| loop_filter(count, fps)) else {
        return false;
    };
    // libx264 suele estar; si no, el codificador del sistema (macOS).
    let encoders: [&[&str]; 2] = [
        &["-c:v", "libx264", "-preset", "veryfast", "-crf", "18"],
        &["-c:v", "h264_videotoolbox", "-b:v", "6M"],
    ];
    encoders.iter().any(|encoder| {
        let mut args: Vec<String> = vec!["-i".into(), copy.to_string_lossy().into_owned()];
        args.extend(["-filter_complex".into(), filter.clone(), "-map".into(), "[v]".into(), "-an".into()]);
        args.extend(encoder.iter().map(|arg| arg.to_string()));
        ffmpeg(&args, target)
    })
}

/// Ejecuta `ffmpeg` con `args` hacia `output` (vía un `.part.mp4`, con el índice delante y un
/// límite de tiempo).
fn ffmpeg(args: &[String], output: &Path) -> bool {
    let Some(ffmpeg) = crate::audio::which("ffmpeg", &crate::audio::search_path()) else {
        eprintln!("animada: no se encontró ffmpeg");
        return false;
    };
    let part = output.with_extension("part.mp4");
    let child = crate::audio::command(ffmpeg)
        .args(["-nostdin", "-loglevel", "error", "-y"])
        .args(args)
        .args(["-movflags", "+faststart"])
        .arg(&part)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn();
    let mut child = match child {
        Ok(child) => child,
        Err(error) => {
            eprintln!("animada: ffmpeg: {error}");
            return false;
        }
    };
    let started = Instant::now();
    let status = loop {
        match child.try_wait() {
            Ok(Some(status)) => break Some(status),
            Ok(None) if started.elapsed() > FFMPEG_LIMIT => {
                let _ = child.kill();
                let _ = child.wait();
                eprintln!("animada: ffmpeg tardó demasiado");
                break None;
            }
            Ok(None) => thread::sleep(Duration::from_millis(100)),
            Err(_) => break None,
        }
    };
    if status.is_some_and(|status| status.success()) && fs::rename(&part, output).is_ok() {
        return true;
    }
    let mut detail = String::new();
    if let Some(mut stderr) = child.stderr.take() {
        let _ = stderr.read_to_string(&mut detail);
    }
    eprintln!("animada: ffmpeg falló: {}", detail.trim());
    let _ = fs::remove_file(&part);
    false
}

/// Borra los vídeos más antiguos si hay más de `MAX_VIDEOS`.
fn prune(dir: &PathBuf) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    let mut videos: Vec<(SystemTime, PathBuf)> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.extension().is_some_and(|ext| ext == "mp4"))
        .filter_map(|path| Some((fs::metadata(&path).and_then(|m| m.modified()).ok()?, path)))
        .collect();
    if videos.len() <= MAX_VIDEOS {
        return;
    }
    videos.sort();
    for (_, path) in &videos[..videos.len() - MAX_VIDEOS] {
        let _ = fs::remove_file(path);
    }
}

/// Ruta del vídeo en caché de un álbum, descargándolo si hace falta.
fn video_for(album: &str) -> Option<PathBuf> {
    let dir = dir()?;
    // `-bucle`: con el final fundido con el principio. Los de antes (`<id>.mp4`) tenían el corte.
    let target = dir.join(format!("{album}-bucle.mp4"));
    if target.exists() {
        return Some(target);
    }
    let _ = fs::remove_file(dir.join(format!("{album}.mp4")));
    let page = get(&format!("https://music.apple.com/us/album/{album}"))?;
    let master = get(&motion_playlist(&page)?)?;
    let variant = pick_variant(&master)?;
    fs::create_dir_all(&dir).ok()?;
    if !download(&variant, &target) {
        return None;
    }
    prune(&dir);
    Some(target)
}

/// Archivo con la carátula animada de la canción `video_id`, o `None` si no tiene. Hace
/// peticiones de red y puede tardar varios segundos: llámala desde un hilo aparte.
pub fn find(title: &str, artist: &str, video_id: &str) -> Option<PathBuf> {
    let _guard = LOCK.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    let key = format!("{}|{}", normalize(artist), normalize(title));
    let mut index = read_index();
    if let Some(entry) = index.get(&key) {
        if !entry.album.is_empty() {
            if let Some(path) = video_for(&entry.album) {
                return Some(path);
            }
        } else if now().saturating_sub(entry.at) < RECHECK_NONE {
            return None;
        }
    }
    // El álbum de YouTube Music, solo si no está ya en el índice (una petición más).
    let album = (!video_id.is_empty())
        .then(|| crate::ytm::song_links(video_id).ok())
        .flatten()
        .and_then(|links| links.album)
        .map(|album| album.title)
        .unwrap_or_default();
    let song = Song { title: title.to_owned(), artist: artist.to_owned(), album };
    let mut found = None;
    for album in find_albums(&song) {
        if let Some(path) = video_for(&album) {
            found = Some((album, path));
            break;
        }
    }
    let album = found.as_ref().map(|(album, _)| album.clone()).unwrap_or_default();
    index.insert(key, Entry { album, at: now() });
    write_index(&index);
    found.map(|(_, path)| path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compara_titulos_y_artistas() {
        let song = |title: &str, artist: &str, album: &str| Song {
            title: title.to_owned(),
            artist: artist.to_owned(),
            album: album.to_owned(),
        };
        let piano = "Deltarune Piano Collections, Vol. 1";
        assert!(matches(&song("Rude Buster", "Trevor Alan Gomes", ""), "Rude Buster", "Trevor Alan Gomes", piano));
        assert!(matches(&song("Rude Buster (Piano)", "Toby Fox", ""), "Rude Buster", "Toby Fox & Trevor Alan Gomes", piano));
        assert!(matches(&song("Rude Buster", "Toby Fox", "DELTARUNE Piano Collections, Vol. 1"), "Rude Buster", "Trevor Alan Gomes", piano));
        assert!(!matches(&song("Rude Buster", "Lionmight", ""), "Rude Buster", "Trevor Alan Gomes", piano));
        assert!(!matches(&song("Rude Buster", "Toby Fox", "Otro disco"), "Rude Buster", "Trevor Alan Gomes", piano));
        assert!(!matches(&song("Field of Hopes", "Toby Fox", ""), "Rude Buster", "Toby Fox", "x"));
    }

    #[test]
    fn saca_la_lista_del_video_cuadrado() {
        let page = r#"..."motionDetailTall":{"video":"https://x/tall.m3u8"},"motionDetailSquare":{"previewFrame":{"url":"https://img/{w}x{h}bb.{f}","width":3840},"video":"https://mvod.itunes.apple.com/a/P1_default.m3u8"}"#;
        assert_eq!(motion_playlist(page).as_deref(), Some("https://mvod.itunes.apple.com/a/P1_default.m3u8"));
        assert_eq!(motion_playlist("sin animación"), None);
    }

    #[test]
    fn un_solo_archivo_por_trozos() {
        let playlist = "#EXTM3U\n#EXT-X-MAP:URI=\"P1-.mp4\",BYTERANGE=\"877@0\"\n#EXTINF:4.0,\n#EXT-X-BYTERANGE:12@877\nP1-.mp4\n#EXTINF:4.0,\nP1-.mp4\n";
        assert_eq!(single_file("https://v/a/b.m3u8", playlist).as_deref(), Some("https://v/a/P1-.mp4"));
        assert_eq!(single_file("https://v/a/b.m3u8", "#EXTINF:4,\nseg1.ts\n#EXTINF:4,\nseg2.ts\n"), None);
    }

    #[test]
    fn el_bucle_cierra_sobre_fotogramas_seguidos() {
        // 20 s a 30 fps: empieza en el 31 y acaba en el 30 del original, tras fundir 1 s.
        let filter = loop_filter(600, 30.0).expect("cabe el fundido");
        assert!(filter.contains("trim=start_frame=31"));
        assert!(filter.contains("trim=end_frame=31"));
        assert!(filter.contains("duration=1.0000:offset=17.9667"));
        assert_eq!(loop_filter(90, 30.0), None);
    }

    #[test]
    fn elige_la_variante_h264_mas_grande_permitida() {
        let master = "#EXTM3U\n\
#EXT-X-STREAM-INF:BANDWIDTH=1863758,CODECS=\"avc1.64001f\",RESOLUTION=768x768\nhttps://v/768.m3u8\n\
#EXT-X-STREAM-INF:BANDWIDTH=2001364,CODECS=\"hvc1.2\",RESOLUTION=960x960\nhttps://v/hevc.m3u8\n\
#EXT-X-STREAM-INF:BANDWIDTH=2273910,CODECS=\"avc1.64001f\",RESOLUTION=960x960\nhttps://v/960a.m3u8\n\
#EXT-X-STREAM-INF:BANDWIDTH=3343184,CODECS=\"avc1.64001f\",RESOLUTION=960x960\nhttps://v/960b.m3u8\n\
#EXT-X-STREAM-INF:BANDWIDTH=3553318,CODECS=\"avc1.640020\",RESOLUTION=1080x1080\nhttps://v/1080.m3u8\n";
        assert_eq!(pick_variant(master).as_deref(), Some("https://v/960b.m3u8"));
    }
}
