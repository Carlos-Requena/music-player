//! Recomendaciones de ListenBrainz para la sección Explorar
//! ([ADR-19](../docs/decisions/ADR-19-explorar-con-listenbrainz.md)).
//!
//! ListenBrainz genera con Troi, en su servidor, listas «hecho para ti» y recomendaciones a
//! partir de las escuchas de cada usuario; aquí solo se piden a su API. Lo que devuelve son
//! grabaciones de MusicBrainz (título, artista, MBID), no vídeos: cada una se busca en YouTube
//! Music y lo encontrado se guarda en disco por MBID para no repetir la búsqueda.
//!
//! ListenBrainz admite una petición por segundo por aplicación: `wait_turn` las espacia.

use std::{
    collections::HashMap,
    fs,
    path::PathBuf,
    sync::{LazyLock, Mutex},
    thread,
    time::{Duration, Instant},
};

use serde_json::Value;

use crate::ytm::{self, Detail, Item, Track, Zone};

const API: &str = "https://api.listenbrainz.org/1";

/// ListenBrainz pide un User-Agent propio («nombre/versión»).
pub const USER_AGENT: &str = concat!("musicplayer/", env!("CARGO_PKG_VERSION"));

/// Separación mínima entre dos peticiones a ListenBrainz (una por segundo, con margen).
const GAP: Duration = Duration::from_millis(1100);

/// Búsquedas en YouTube Music a la vez al convertir una lista (como la búsqueda de la app).
const PARALLEL: usize = 4;

/// Listas «hecho para ti» que se muestran, en este orden, con su nombre en la interfaz.
const PATCHES: [(&str, &str); 3] = [
    ("weekly-exploration", "Exploración semanal"),
    ("weekly-jams", "Jams semanales"),
    ("daily-jams", "Jams diarias"),
];

/// Canciones de «Recomendado para ti» y de «Lo más escuchado esta semana»; novedades.
const RECS: usize = 30;
const TOP: usize = 30;
const NEWS: usize = 15;

pub type Result<T> = std::result::Result<T, String>;

static LAST_REQUEST: LazyLock<Mutex<Option<Instant>>> = LazyLock::new(Default::default);

/// Espera hasta que haya pasado `GAP` desde la última petición (de cualquier hilo).
fn wait_turn() {
    let Ok(mut last) = LAST_REQUEST.lock() else { return };
    if let Some(at) = *last {
        let elapsed = at.elapsed();
        if elapsed < GAP {
            thread::sleep(GAP - elapsed);
        }
    }
    *last = Some(Instant::now());
}

/// Lee la respuesta: `None` si no hay contenido (204: aún sin recomendaciones; 404: usuario o
/// lista que no existe) y el mensaje de ListenBrainz si es un error.
fn answer(response: std::result::Result<ureq::http::Response<ureq::Body>, ureq::Error>) -> Result<Option<Value>> {
    let mut response = response.map_err(|error| format!("ListenBrainz no responde: {error}"))?;
    let status = response.status().as_u16();
    if status == 204 || status == 404 {
        return Ok(None);
    }
    let body: Value = response.body_mut().read_json().unwrap_or(Value::Null);
    if status >= 400 {
        let message = body["error"].as_str().unwrap_or("error desconocido");
        return Err(format!("ListenBrainz ({status}): {message}"));
    }
    Ok(Some(body))
}

/// `GET {API}{path}`, con el token del usuario si se da.
pub fn get(path: &str, token: Option<&str>) -> Result<Option<Value>> {
    wait_turn();
    let mut request = ytm::http().get(format!("{API}{path}")).header("User-Agent", USER_AGENT);
    if let Some(token) = token {
        request = request.header("Authorization", format!("Token {token}"));
    }
    answer(request.config().http_status_as_error(false).build().call())
}

/// `POST {API}{path}` con un cuerpo JSON y el token del usuario.
pub fn post(path: &str, token: &str, body: &Value) -> Result<Option<Value>> {
    wait_turn();
    let request = ytm::http()
        .post(format!("{API}{path}"))
        .header("User-Agent", USER_AGENT)
        .header("Authorization", format!("Token {token}"));
    answer(request.config().http_status_as_error(false).build().send_json(body))
}

/// Codifica un nombre de usuario para la ruta de la URL.
fn encode(text: &str) -> String {
    text.bytes()
        .map(|byte| match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => (byte as char).to_string(),
            _ => format!("%{byte:02X}"),
        })
        .collect()
}

/// Grabación de MusicBrainz tal como la recomienda ListenBrainz.
#[derive(Clone, Debug, Default)]
struct Recording {
    mbid: String,
    title: String,
    artist: String,
    /// Segundos; 0 si no se sabe.
    duration: f64,
}

// ---------------------------------------------------------------------------------------------
// De ListenBrainz a YouTube Music

/// Lo ya buscado en YouTube Music: MBID (o `release:<MBID>`) → elemento, o `None` si no se
/// encontró. Se guarda en `<caché>/musicplayer/listenbrainz-youtube.json`.
static FOUND: LazyLock<Mutex<HashMap<String, Option<Item>>>> = LazyLock::new(|| {
    let stored = found_path()
        .and_then(|path| fs::read_to_string(path).ok())
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default();
    Mutex::new(stored)
});

fn found_path() -> Option<PathBuf> {
    dirs::cache_dir().map(|dir| dir.join("musicplayer").join("listenbrainz-youtube.json"))
}

fn save_found() {
    let Some(path) = found_path() else { return };
    let Ok(found) = FOUND.lock() else { return };
    if let Some(dir) = path.parent() {
        let _ = fs::create_dir_all(dir);
    }
    if let Ok(text) = serde_json::to_string(&*found) {
        if let Err(error) = fs::write(&path, text) {
            eprintln!("listenbrainz: guardar en {}: {error}", path.display());
        }
    }
}

/// Texto comparable: minúsculas, sin lo que va entre paréntesis o corchetes y solo letras y
/// números (de cualquier alfabeto).
fn normalize(text: &str) -> String {
    let mut out = String::new();
    let mut depth = 0usize;
    for c in text.chars() {
        match c {
            '(' | '[' => depth += 1,
            ')' | ']' => depth = depth.saturating_sub(1),
            _ if depth == 0 && c.is_alphanumeric() => out.extend(c.to_lowercase()),
            _ => {}
        }
    }
    out
}

/// ¿Es `found` el mismo nombre que `wanted`? Uno puede llevar añadidos («Remastered», «feat.»).
fn same_name(wanted: &str, found: &str) -> bool {
    let (a, b) = (normalize(wanted), normalize(found));
    if a.is_empty() || b.is_empty() {
        return false;
    }
    if a.chars().count() < 3 || b.chars().count() < 3 {
        return a == b;
    }
    a.contains(&b) || b.contains(&a)
}

/// Primer artista de un crédito («A feat. B», «A & B», «A, B» → «A»).
fn main_artist(credit: &str) -> &str {
    let lower = credit.to_lowercase();
    let cut = [" feat", " ft.", " & ", ", ", " x ", " with ", " y "]
        .iter()
        .filter_map(|separator| lower.find(separator))
        .min()
        .unwrap_or(credit.len());
    credit.get(..cut).unwrap_or(credit).trim()
}

/// El resultado de la búsqueda que corresponde a `title` de `artist`: el primero (de los tres
/// primeros) cuyo título o artista coincide. Basta con uno de los dos porque ListenBrainz y
/// YouTube escriben a veces el mismo nombre en alfabetos distintos (japonés y romaji).
fn pick(results: Vec<Item>, title: &str, artist: &str) -> Option<Item> {
    let artist = normalize(main_artist(artist));
    results.into_iter().take(3).find(|item| {
        same_name(title, &item.title) || (!artist.is_empty() && normalize(&item.subtitle).contains(&artist))
    })
}

/// Busca en YouTube Music (o en la caché) la canción o el álbum de `key`. `None` si no está o
/// si la búsqueda falló (entonces no se guarda, para reintentarlo en la próxima carga).
fn find(key: &str, title: &str, artist: &str, albums: bool) -> Option<Item> {
    if let Some(known) = FOUND.lock().ok().and_then(|found| found.get(key).cloned()) {
        return known;
    }
    let query = format!("{} {title}", main_artist(artist));
    match ytm::search_one_kind(&query, albums) {
        Ok(results) => {
            let item = pick(results, title, artist);
            if let Ok(mut found) = FOUND.lock() {
                found.insert(key.to_owned(), item.clone());
            }
            item
        }
        Err(error) => {
            eprintln!("listenbrainz: buscar «{query}» en YouTube Music: {error}");
            None
        }
    }
}

/// Convierte cada grabación en una canción de YouTube Music, `PARALLEL` a la vez y en su orden;
/// las que no se encuentran se omiten.
fn to_songs(recordings: &[Recording]) -> Vec<(Recording, Item)> {
    let mut out = Vec::new();
    for chunk in recordings.chunks(PARALLEL) {
        let found: Vec<Option<Item>> = thread::scope(|scope| {
            let running: Vec<_> = chunk
                .iter()
                .map(|recording| scope.spawn(move || find(&recording.mbid, &recording.title, &recording.artist, false)))
                .collect();
            running.into_iter().map(|handle| handle.join().ok().flatten()).collect()
        });
        for (recording, item) in chunk.iter().zip(found) {
            if let Some(mut item) = item {
                item.kind = "song".to_owned();
                out.push((recording.clone(), item));
            }
        }
    }
    out
}

fn track(recording: &Recording, item: &Item) -> Track {
    Track {
        title: item.title.clone(),
        artist: if recording.artist.is_empty() { item.subtitle.clone() } else { recording.artist.clone() },
        thumb: item.thumb.clone(),
        video_id: item.video_id.clone(),
        duration: recording.duration,
    }
}

// ---------------------------------------------------------------------------------------------
// Lo que recomienda ListenBrainz

/// Listas de ListenBrainz ya convertidas, por MBID, para abrir su detalle al instante.
static PLAYLISTS: LazyLock<Mutex<HashMap<String, Detail>>> = LazyLock::new(Default::default);

/// Prefijo del `browseId` de una lista de ListenBrainz (no es una playlist de YouTube).
pub const PLAYLIST_PREFIX: &str = "lb:";

/// La lista «hecho para ti» más reciente de cada tipo de `PATCHES`: `(mbid, nombre)`.
fn created_for(user: &str) -> Result<Vec<(String, String)>> {
    let Some(page) = get(&format!("/user/{}/playlists/createdfor?count=25", encode(user)), None)? else {
        return Ok(Vec::new());
    };
    let mut newest: HashMap<String, String> = HashMap::new();
    for entry in page["playlists"].as_array().into_iter().flatten() {
        let playlist = &entry["playlist"];
        let patch = playlist
            .pointer("/extension/https:~1~1musicbrainz.org~1doc~1jspf#playlist/additional_metadata/algorithm_metadata/source_patch")
            .and_then(Value::as_str)
            .unwrap_or_default();
        let mbid = playlist["identifier"].as_str().and_then(|url| url.rsplit('/').next()).unwrap_or_default();
        // Llegan de la más nueva a la más antigua: se queda la primera de cada tipo.
        if !mbid.is_empty() && !newest.contains_key(patch) {
            newest.insert(patch.to_owned(), mbid.to_owned());
        }
    }
    Ok(PATCHES
        .iter()
        .filter_map(|(patch, name)| newest.get(*patch).map(|mbid| (mbid.clone(), (*name).to_owned())))
        .collect())
}

/// MBID de una grabación a partir de su enlace de MusicBrainz (texto o lista de textos).
fn recording_mbid(identifier: &Value) -> String {
    let url = identifier.as_str().or_else(|| identifier.get(0).and_then(Value::as_str)).unwrap_or_default();
    url.rsplit('/').next().unwrap_or_default().to_owned()
}

/// Pistas de una lista de ListenBrainz (JSPF).
fn playlist_recordings(mbid: &str) -> Result<Vec<Recording>> {
    let Some(page) = get(&format!("/playlist/{mbid}"), None)? else {
        return Err("Esa lista de ListenBrainz ya no existe.".to_owned());
    };
    Ok(page
        .pointer("/playlist/track")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .map(|track| Recording {
            mbid: recording_mbid(&track["identifier"]),
            title: track["title"].as_str().unwrap_or_default().to_owned(),
            artist: track["creator"].as_str().unwrap_or_default().to_owned(),
            duration: track["duration"].as_f64().unwrap_or_default() / 1000.0,
        })
        .filter(|recording| !recording.mbid.is_empty() && !recording.title.is_empty())
        .collect())
}

/// Convierte una lista de ListenBrainz en el detalle que abre la interfaz y la recuerda.
fn build_playlist(mbid: &str, name: &str) -> Result<Detail> {
    let songs = to_songs(&playlist_recordings(mbid)?);
    let detail = Detail {
        title: name.to_owned(),
        // El detalle ya cuenta las canciones.
        subtitle: "ListenBrainz".to_owned(),
        thumb: songs.first().map(|(_, item)| item.thumb.clone()).unwrap_or_default(),
        kind: "playlist".to_owned(),
        tracks: songs.iter().map(|(recording, item)| track(recording, item)).collect(),
        ..Detail::default()
    };
    if let Ok(mut playlists) = PLAYLISTS.lock() {
        playlists.insert(mbid.to_owned(), detail.clone());
    }
    Ok(detail)
}

/// Detalle de una lista de ListenBrainz de Explorar (`browseId` `lb:<mbid>`).
pub fn detail(target: &Item) -> Result<Detail> {
    let mbid = target.browse_id.trim_start_matches(PLAYLIST_PREFIX);
    if let Some(known) = PLAYLISTS.lock().ok().and_then(|playlists| playlists.get(mbid).cloned()) {
        return Ok(known);
    }
    let detail = build_playlist(mbid, &target.title);
    save_found();
    detail
}

/// Recomendaciones colaborativas del usuario, con su título y artista.
fn recommended(user: &str) -> Result<Vec<Recording>> {
    let path = format!("/cf/recommendation/user/{}/recording?count={RECS}", encode(user));
    let Some(page) = get(&path, None)? else { return Ok(Vec::new()) };
    let mbids: Vec<String> = page
        .pointer("/payload/mbids")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry["recording_mbid"].as_str().map(str::to_owned))
        .collect();
    if mbids.is_empty() {
        return Ok(Vec::new());
    }
    let path = format!("/metadata/recording/?recording_mbids={}&inc=artist", mbids.join(","));
    let Some(metadata) = get(&path, None)? else { return Ok(Vec::new()) };
    Ok(mbids
        .into_iter()
        .filter_map(|mbid| {
            let entry = metadata.get(&mbid)?;
            Some(Recording {
                title: entry.pointer("/recording/name")?.as_str()?.to_owned(),
                artist: entry.pointer("/artist/name").and_then(Value::as_str).unwrap_or_default().to_owned(),
                duration: entry.pointer("/recording/length").and_then(Value::as_f64).unwrap_or_default() / 1000.0,
                mbid,
            })
        })
        .collect())
}

/// Lo más escuchado esta semana en todo ListenBrainz (no necesita cuenta).
fn sitewide_top() -> Result<Vec<Recording>> {
    let Some(page) = get(&format!("/stats/sitewide/recordings?range=week&count={TOP}"), None)? else {
        return Ok(Vec::new());
    };
    Ok(page
        .pointer("/payload/recordings")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .map(|entry| {
            let field = |key: &str| entry[key].as_str().unwrap_or_default().to_owned();
            Recording {
                mbid: field("recording_mbid"),
                title: field("track_name"),
                artist: field("artist_name"),
                duration: 0.0,
            }
        })
        // Sin MBID se busca por nombre: la clave de la caché es el propio texto.
        .map(|mut recording| {
            if recording.mbid.is_empty() {
                recording.mbid = format!("texto:{} — {}", recording.artist, recording.title);
            }
            recording
        })
        .filter(|recording| !recording.title.is_empty())
        .collect())
}

/// Novedades ya publicadas de los artistas que escucha el usuario, como álbumes de YouTube Music.
fn fresh_releases(user: &str) -> Result<Vec<Item>> {
    let path = format!("/user/{}/fresh_releases?past=true&future=false", encode(user));
    let Some(page) = get(&path, None)? else { return Ok(Vec::new()) };
    let mut releases: Vec<&Value> = page.pointer("/payload/releases").and_then(Value::as_array).into_iter().flatten().collect();
    let today = today();
    releases.retain(|release| release["release_date"].as_str().is_some_and(|date| date <= today.as_str()));
    releases.sort_by(|a, b| b["release_date"].as_str().cmp(&a["release_date"].as_str()));
    releases.truncate(NEWS);
    let wanted: Vec<(String, String, String)> = releases
        .iter()
        .map(|release| {
            let field = |key: &str| release[key].as_str().unwrap_or_default().to_owned();
            (format!("release:{}", field("release_mbid")), field("release_name"), field("artist_credit_name"))
        })
        .collect();
    let mut out = Vec::new();
    for chunk in wanted.chunks(PARALLEL) {
        let found: Vec<Option<Item>> = thread::scope(|scope| {
            let running: Vec<_> = chunk
                .iter()
                .map(|(key, title, artist)| scope.spawn(move || find(key, title, artist, true)))
                .collect();
            running.into_iter().map(|handle| handle.join().ok().flatten()).collect()
        });
        out.extend(found.into_iter().flatten().filter(|item| !item.playlist_id.is_empty()));
    }
    Ok(out)
}

/// Fecha de hoy (UTC) como `AAAA-MM-DD`, para comparar con las de ListenBrainz.
fn today() -> String {
    let days = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.as_secs() / 86_400) as i64;
    // Algoritmo de días civiles de Howard Hinnant.
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    format!("{year:04}-{month:02}-{day:02}")
}

fn song_zone(titulo: &str, recordings: &[Recording]) -> Zone {
    Zone { titulo: titulo.to_owned(), items: to_songs(recordings).into_iter().map(|(_, item)| item).collect() }
}

/// Zonas de Explorar. Con usuario de ListenBrainz: sus listas «hecho para ti», sus
/// recomendaciones y las novedades de sus artistas; siempre, lo más escuchado de la semana.
/// `publish` recibe las zonas reunidas cada vez que se completa una, para que la interfaz las
/// muestre sin esperar a las demás. Una zona que falla se omite; si fallan todas, el error.
pub fn explorar(user: Option<&str>, mut publish: impl FnMut(&[Zone])) -> Result<Vec<Zone>> {
    let mut zones: Vec<Zone> = Vec::new();
    let mut last_error = None;
    let mut add = |zones: &mut Vec<Zone>, zone: Result<Zone>| match zone {
        Ok(zone) if !zone.items.is_empty() => {
            zones.push(zone);
            publish(zones);
        }
        Ok(_) => {}
        Err(error) => {
            eprintln!("listenbrainz: {error}");
            last_error = Some(error);
        }
    };

    if let Some(user) = user.filter(|user| !user.is_empty()) {
        let made_for_you = created_for(user).map(|playlists| Zone {
            titulo: "Hecho para ti".to_owned(),
            items: playlists
                .iter()
                .filter_map(|(mbid, name)| match build_playlist(mbid, name) {
                    Ok(detail) if !detail.tracks.is_empty() => Some(Item {
                        title: detail.title,
                        subtitle: format!("ListenBrainz · {} canciones", detail.tracks.len()),
                        thumb: detail.thumb,
                        kind: "playlist".to_owned(),
                        browse_id: format!("{PLAYLIST_PREFIX}{mbid}"),
                        ..Item::default()
                    }),
                    Ok(_) => None,
                    Err(error) => {
                        eprintln!("listenbrainz: lista {mbid}: {error}");
                        None
                    }
                })
                .collect(),
        });
        add(&mut zones, made_for_you);
        add(&mut zones, recommended(user).map(|recordings| song_zone("Recomendado para ti", &recordings)));
        add(&mut zones, fresh_releases(user).map(|items| Zone { titulo: "Novedades de tus artistas".to_owned(), items }));
    }
    add(&mut zones, sitewide_top().map(|recordings| song_zone("Lo más escuchado esta semana", &recordings)));
    save_found();

    match (zones.is_empty(), last_error) {
        (true, Some(error)) => Err(error),
        _ => Ok(zones),
    }
}

/// Nombre del usuario dueño de `token`, o el error que da ListenBrainz.
pub fn validate_token(token: &str) -> Result<String> {
    let answer = get("/validate-token", Some(token))?.unwrap_or(Value::Null);
    match answer["user_name"].as_str() {
        Some(user) if answer["valid"].as_bool() == Some(true) => Ok(user.to_owned()),
        _ => Err("ListenBrainz no reconoce ese token: cópialo de nuevo de listenbrainz.org/settings.".to_owned()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nombres_comparables() {
        assert_eq!(normalize("Barael’s Blade (Remastered 2020)"), "baraelsblade");
        assert!(same_name("Barael’s Blade", "Barael's Blade - Remastered"));
        assert!(same_name("夜に駆ける", "夜に駆ける"));
        assert!(!same_name("Sherpa", "Ocean"));
        assert!(!same_name("Up", "Upside Down")); // los nombres cortos han de ser iguales
        assert!(!same_name("", "algo"));
    }

    #[test]
    fn primer_artista_del_credito() {
        assert_eq!(main_artist("Daft Punk feat. Pharrell Williams"), "Daft Punk");
        assert_eq!(main_artist("Simon & Garfunkel"), "Simon");
        assert_eq!(main_artist("YOASOBI"), "YOASOBI");
    }

    #[test]
    fn elige_por_titulo_o_artista() {
        let song = |title: &str, subtitle: &str| Item { title: title.into(), subtitle: subtitle.into(), ..Item::default() };
        let results = vec![song("Otra cosa", "Nadie • 3:00"), song("Racing into the Night", "YOASOBI • THE BOOK • 4:21")];
        assert_eq!(pick(results, "夜に駆ける", "YOASOBI").map(|item| item.title), Some("Racing into the Night".into()));
        assert!(pick(vec![song("Otra cosa", "Nadie")], "Sherpa", "Angine de Poitrine").is_none());
    }

    #[test]
    fn mbid_del_enlace() {
        let list = serde_json::json!(["https://musicbrainz.org/recording/d22dc468-7412-4843-bb13-25cc52d18393"]);
        assert_eq!(recording_mbid(&list), "d22dc468-7412-4843-bb13-25cc52d18393");
        assert_eq!(encode("año x"), "a%C3%B1o%20x");
    }

    #[test]
    fn fecha_de_hoy_bien_formada() {
        let today = today();
        assert_eq!(today.len(), 10);
        assert!(today.as_str() > "2026-01-01");
    }
}
