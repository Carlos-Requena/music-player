//! Cliente mínimo de la API interna de YouTube Music (InnerTube), sin sesión.
//!
//! Solo extrae lo que la interfaz necesita: zonas de elementos para explorar y la
//! cola de reproducción de una canción, álbum o playlist. Las respuestas de InnerTube
//! son árboles muy profundos y cambian a menudo, así que se recorren buscando los
//! "renderers" por nombre en vez de fijar rutas completas.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

const ENDPOINT: &str = "https://music.youtube.com/youtubei/v1";
const USER_AGENT: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
const CLIENT_VERSION: &str = "1.20251101.01.00";

/// Filtros de búsqueda (parámetro `params` de InnerTube).
const SEARCH_ARTISTS: &str = "EgWKAQIgAWoMEA4QChADEAQQCRAF";
const SEARCH_SONGS: &str = "EgWKAQIIAWoMEA4QChADEAQQCRAF";
const SEARCH_ALBUMS: &str = "EgWKAQIYAWoMEA4QChADEAQQCRAF";
const SEARCH_PLAYLISTS: &str = "EgeKAQQoAEABagwQDhAKEAMQBBAJEAU%3D";

pub type Result<T> = std::result::Result<T, String>;

/// Elemento navegable: canción, álbum o playlist.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Item {
    pub title: String,
    pub subtitle: String,
    pub thumb: String,
    /// "song", "album" o "playlist".
    pub kind: String,
    pub video_id: String,
    pub browse_id: String,
    pub playlist_id: String,
}

/// Grupo de elementos con título ("Selecciones rápidas", "Novedades"…).
#[derive(Clone, Debug, Default, Serialize)]
pub struct Zone {
    pub titulo: String,
    pub items: Vec<Item>,
}

/// Pista de la cola de reproducción.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Track {
    pub title: String,
    pub artist: String,
    pub thumb: String,
    pub video_id: String,
    pub duration: f64,
}

fn post(endpoint: &str, mut body: Value) -> Result<Value> {
    body["context"] = json!({
        "client": { "clientName": "WEB_REMIX", "clientVersion": CLIENT_VERSION, "hl": "es", "gl": "ES" }
    });
    let mut request = ureq::post(format!("{ENDPOINT}/{endpoint}?prettyPrint=false"))
        .header("User-Agent", USER_AGENT)
        .header("Origin", "https://music.youtube.com");
    // Con sesión, las mismas peticiones devuelven el contenido de la cuenta.
    if let Some((cookie, authorization)) = crate::account::with_session(|session| session.headers()) {
        request = request
            .header("Cookie", cookie)
            .header("Authorization", authorization)
            .header("X-Origin", "https://music.youtube.com")
            .header("X-Goog-AuthUser", "0");
    }
    let mut response = request
        .send_json(&body)
        .map_err(|error| format!("YouTube Music no responde: {error}"))?;
    response
        .body_mut()
        .with_config()
        .limit(32 * 1024 * 1024)
        .read_json()
        .map_err(|error| format!("Respuesta de YouTube Music ilegible: {error}"))
}

/// Primera aparición de `key` en profundidad.
fn find<'a>(value: &'a Value, key: &str) -> Option<&'a Value> {
    match value {
        Value::Object(map) => map
            .get(key)
            .or_else(|| map.values().find_map(|child| find(child, key))),
        Value::Array(list) => list.iter().find_map(|child| find(child, key)),
        _ => None,
    }
}

/// Todas las apariciones de `key`, en orden de documento.
fn find_all<'a>(value: &'a Value, key: &str, out: &mut Vec<&'a Value>) {
    match value {
        Value::Object(map) => {
            for (name, child) in map {
                if name == key {
                    out.push(child);
                }
                find_all(child, key, out);
            }
        }
        Value::Array(list) => list.iter().for_each(|child| find_all(child, key, out)),
        _ => {}
    }
}

/// Une los fragmentos `runs[].text` de un texto con formato.
fn text(value: Option<&Value>) -> String {
    value
        .and_then(|v| v.get("runs"))
        .and_then(Value::as_array)
        .map(|runs| {
            runs.iter()
                .filter_map(|run| run.get("text").and_then(Value::as_str))
                .collect()
        })
        .unwrap_or_default()
}

fn string(value: Option<&Value>) -> String {
    value.and_then(Value::as_str).unwrap_or_default().to_owned()
}

/// URL de la miniatura más grande, pidiendo 544 px a los servidores de carátulas.
fn thumb(value: &Value) -> String {
    let url = find(value, "thumbnails")
        .and_then(Value::as_array)
        .and_then(|list| list.last())
        .map(|last| string(last.get("url")))
        .unwrap_or_default();
    match url.rfind("=w") {
        Some(at) if url.contains("googleusercontent.com") => {
            format!("{}=w544-h544-l90-rj", &url[..at])
        }
        _ => url,
    }
}

fn kind_of(page_type: &str) -> &'static str {
    match page_type {
        "MUSIC_PAGE_TYPE_ALBUM" => "album",
        "MUSIC_PAGE_TYPE_PLAYLIST" => "playlist",
        "MUSIC_PAGE_TYPE_ARTIST" => "artist",
        _ => "",
    }
}

/// Convierte un `musicTwoRowItemRenderer` o `musicResponsiveListItemRenderer` en `Item`.
/// Devuelve `None` para lo que aún no sabemos abrir (artistas, categorías…).
fn item(entry: &Value) -> Option<Item> {
    let (renderer, title, subtitle) = if let Some(two_row) = entry.get("musicTwoRowItemRenderer") {
        (two_row, text(two_row.get("title")), text(two_row.get("subtitle")))
    } else if let Some(row) = entry.get("musicResponsiveListItemRenderer") {
        let column = |index: usize| {
            text(row.pointer(&format!(
                "/flexColumns/{index}/musicResponsiveListItemFlexColumnRenderer/text"
            )))
        };
        (row, column(0), column(1))
    } else {
        return None;
    };

    let mut out = Item { title, subtitle, thumb: thumb(renderer), ..Item::default() };

    out.video_id = string(renderer.pointer("/playlistItemData/videoId"));
    if out.video_id.is_empty() {
        // En las filas de canción el enlace de reproducción cuelga del título.
        let watch = renderer
            .pointer("/navigationEndpoint/watchEndpoint")
            .or_else(|| find(renderer.get("flexColumns").unwrap_or(&Value::Null), "watchEndpoint"));
        out.video_id = string(watch.and_then(|w| w.get("videoId")));
    }

    if out.video_id.is_empty() {
        let browse = renderer.pointer("/navigationEndpoint/browseEndpoint")?;
        out.browse_id = string(browse.get("browseId"));
        out.kind = kind_of(&string(find(browse, "pageType"))).to_owned();
        out.playlist_id = string(
            find(renderer, "watchPlaylistEndpoint").and_then(|w| w.get("playlistId")),
        );
        if out.playlist_id.is_empty() && out.kind == "playlist" {
            out.playlist_id = out.browse_id.trim_start_matches("VL").to_owned();
        }
        let playable = matches!(out.kind.as_str(), "album" | "playlist") && !out.playlist_id.is_empty();
        if !playable && out.kind != "artist" {
            return None;
        }
    } else {
        out.kind = "song".to_owned();
    }

    (!out.title.is_empty()).then_some(out)
}

/// Extrae las zonas de una página (inicio, explorar, novedades, resultados de búsqueda).
fn zones(root: &Value) -> Vec<Zone> {
    let sections = find(root, "sectionListRenderer")
        .and_then(|list| list.get("contents"))
        .and_then(Value::as_array);
    let mut out = Vec::new();
    for section in sections.into_iter().flatten() {
        // Las páginas de la biblioteca envuelven la cuadrícula en un `itemSectionRenderer`.
        let section = section
            .pointer("/itemSectionRenderer/contents/0")
            .unwrap_or(section);
        let (entries, title) = if let Some(shelf) = section.get("musicCarouselShelfRenderer") {
            (shelf.get("contents"), find(shelf.get("header").unwrap_or(&Value::Null), "title"))
        } else if let Some(grid) = section.get("gridRenderer") {
            (grid.get("items"), find(grid.get("header").unwrap_or(&Value::Null), "title"))
        } else if let Some(shelf) = section.get("musicShelfRenderer") {
            (shelf.get("contents"), shelf.get("title"))
        } else if let Some(shelf) = section.get("musicPlaylistShelfRenderer") {
            (shelf.get("contents"), None)
        } else {
            continue;
        };
        let items: Vec<Item> = entries
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(item)
            .collect();
        if !items.is_empty() {
            out.push(Zone { titulo: text(title), items });
        }
    }
    out
}

/// Nombre de la cuenta con sesión; vacío si YouTube no reconoce la sesión.
pub fn account_name() -> Result<String> {
    let menu = post("account/account_menu", json!({}))?;
    Ok(text(find(&menu, "accountName")))
}

/// Playlists guardadas en la biblioteca de la cuenta (incluye «Música que te gusta»).
pub fn library_playlists() -> Result<Vec<Zone>> {
    titled(browse("FEmusic_liked_playlists")?, "Tus playlists")
}

/// Álbumes guardados en la biblioteca de la cuenta.
pub fn library_albums() -> Result<Vec<Zone>> {
    titled(browse("FEmusic_liked_albums")?, "Tus álbumes")
}

/// Canciones guardadas en la biblioteca de la cuenta.
pub fn library_songs() -> Result<Vec<Zone>> {
    titled(browse("FEmusic_liked_videos")?, "Tus canciones")
}

/// Artistas de la biblioteca de la cuenta.
pub fn library_artists() -> Result<Vec<Zone>> {
    titled(browse("FEmusic_library_corpus_track_artists")?, "Tus artistas")
}

/// Canciones marcadas con «Me gusta». Llevan la playlist `LM` para que, al elegir una,
/// suene el resto de la lista detrás.
pub fn liked_songs() -> Result<Vec<Zone>> {
    let mut zones = titled(browse("VLLM")?, "Me gusta")?;
    for zone in &mut zones {
        for item in &mut zone.items {
            item.playlist_id = "LM".to_owned();
        }
    }
    Ok(zones)
}

/// Página de detalle de un álbum, playlist o artista.
#[derive(Clone, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Detail {
    pub title: String,
    pub subtitle: String,
    pub thumb: String,
    pub kind: String,
    pub playlist_id: String,
    pub tracks: Vec<Track>,
    /// Otras zonas de la página (álbumes y singles de un artista).
    pub zonas: Vec<Zone>,
}

/// Detalle de `item`: las canciones de un álbum o playlist, o las de un artista y su
/// discografía.
pub fn detail(target: &Item) -> Result<Detail> {
    let mut out = Detail {
        title: target.title.clone(),
        subtitle: target.subtitle.clone(),
        thumb: target.thumb.clone(),
        kind: target.kind.clone(),
        playlist_id: target.playlist_id.clone(),
        ..Detail::default()
    };
    if target.kind != "artist" {
        out.tracks = queue("", &target.playlist_id)?;
        return Ok(out);
    }

    let page = post("browse", json!({ "browseId": target.browse_id }))?;
    if let Some(header) = page.get("header") {
        let title = text(find(header, "title"));
        if !title.is_empty() {
            out.title = title;
        }
        let picture = thumb(header);
        if !picture.is_empty() {
            out.thumb = picture;
        }
        out.subtitle = text(find(header, "monthlyListenerCount"));
    }
    // «Canciones más escuchadas» enlaza con una playlist con todas las del artista.
    let mut shelves = Vec::new();
    find_all(&page, "musicShelfRenderer", &mut shelves);
    if let Some(shelf) = shelves.first() {
        let all = string(shelf.pointer("/bottomEndpoint/browseEndpoint/browseId"));
        if let Some(id) = all.strip_prefix("VL") {
            out.playlist_id = id.to_owned();
            out.tracks = queue("", id).unwrap_or_default();
        }
        if out.tracks.is_empty() {
            out.tracks = shelf
                .get("contents")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .filter_map(item)
                .map(|song| Track {
                    artist: out.title.clone(),
                    title: song.title,
                    thumb: song.thumb,
                    video_id: song.video_id,
                    duration: 0.0,
                })
                .collect();
        }
    }
    out.zonas = zones(&page).into_iter().filter(|zone| !zone.titulo.is_empty()).collect();
    Ok(out)
}

/// Une las zonas de una página de biblioteca en una sola con título.
fn titled(zones: Vec<Zone>, titulo: &str) -> Result<Vec<Zone>> {
    let items: Vec<Item> = zones.into_iter().flat_map(|zone| zone.items).collect();
    Ok(if items.is_empty() { Vec::new() } else { vec![Zone { titulo: titulo.to_owned(), items }] })
}

/// Zonas de una página de exploración (`FEmusic_home`, `FEmusic_explore`…).
pub fn browse(browse_id: &str) -> Result<Vec<Zone>> {
    Ok(zones(&post("browse", json!({ "browseId": browse_id }))?))
}

/// Playlists de las primeras categorías de "Ánimo y géneros": lo más parecido a una
/// biblioteca de playlists que ofrece la API sin sesión.
pub fn mood_playlists(categories: usize) -> Result<Vec<Zone>> {
    let explore = post("browse", json!({ "browseId": "FEmusic_explore" }))?;
    let mut buttons = Vec::new();
    find_all(&explore, "musicNavigationButtonRenderer", &mut buttons);

    let mut out = Vec::new();
    for button in buttons {
        let Some(endpoint) = button.pointer("/clickCommand/browseEndpoint") else { continue };
        if string(endpoint.get("browseId")) != "FEmusic_moods_and_genres_category" {
            continue;
        }
        let page = post("browse", json!({
            "browseId": "FEmusic_moods_and_genres_category",
            "params": string(endpoint.get("params")),
        }))?;
        let items: Vec<Item> = zones(&page)
            .into_iter()
            .flat_map(|zone| zone.items)
            .filter(|item| item.kind == "playlist")
            .collect();
        if !items.is_empty() {
            out.push(Zone { titulo: text(button.get("buttonText")), items });
        }
        if out.len() == categories {
            break;
        }
    }
    Ok(out)
}

/// Búsqueda de artistas, canciones, álbumes y playlists.
pub fn search(query: &str) -> Result<Vec<Zone>> {
    let mut out = Vec::new();
    for (titulo, params) in [
        ("Artistas", SEARCH_ARTISTS),
        ("Canciones", SEARCH_SONGS),
        ("Álbumes", SEARCH_ALBUMS),
        ("Playlists", SEARCH_PLAYLISTS),
    ] {
        let page = post("search", json!({ "query": query, "params": params }))?;
        let items: Vec<Item> = zones(&page).into_iter().flat_map(|zone| zone.items).collect();
        if !items.is_empty() {
            out.push(Zone { titulo: titulo.to_owned(), items });
        }
    }
    Ok(out)
}

fn seconds(clock: &str) -> f64 {
    clock
        .split(':')
        .filter_map(|part| part.trim().parse::<f64>().ok())
        .fold(0.0, |total, part| total * 60.0 + part)
}

/// Cola de reproducción: la radio de una canción o las pistas de un álbum o playlist.
pub fn queue(video_id: &str, playlist_id: &str) -> Result<Vec<Track>> {
    let mut body = json!({ "isAudioOnly": true, "enablePersistentPlaylistPanel": true });
    if !video_id.is_empty() {
        body["videoId"] = json!(video_id);
        // Sin playlist se pide la radio automática de la canción.
        let radio = format!("RDAMVM{video_id}");
        body["playlistId"] = json!(if playlist_id.is_empty() { radio.as_str() } else { playlist_id });
    } else {
        body["playlistId"] = json!(playlist_id);
    }

    let page = post("next", body)?;
    let mut renderers = Vec::new();
    find_all(&page, "playlistPanelVideoRenderer", &mut renderers);

    Ok(renderers
        .into_iter()
        .map(|renderer| Track {
            title: text(renderer.get("title")),
            artist: renderer
                .pointer("/longBylineText/runs/0/text")
                .or_else(|| renderer.pointer("/shortBylineText/runs/0/text"))
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_owned(),
            thumb: thumb(renderer),
            video_id: string(renderer.get("videoId")),
            duration: seconds(&text(renderer.get("lengthText"))),
        })
        .filter(|track| !track.video_id.is_empty())
        .collect())
}
