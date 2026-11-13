//! Letra sincronizada desde LRCLIB (https://lrclib.net), una base de datos abierta.

use serde::Serialize;
use serde_json::Value;

const ENDPOINT: &str = "https://lrclib.net/api";
const USER_AGENT: &str = "musicplayer/0.1";

/// Línea de letra con su instante de inicio en segundos.
#[derive(Serialize)]
pub struct Line {
    pub t: f64,
    pub text: String,
}

fn get(path: &str, query: &[(&str, &str)]) -> Option<Value> {
    let mut request = ureq::get(format!("{ENDPOINT}/{path}")).header("User-Agent", USER_AGENT);
    for (key, value) in query {
        request = request.query(*key, *value);
    }
    request.call().ok()?.body_mut().read_json().ok()
}

/// Convierte texto LRC (`[mm:ss.xx] línea`) en líneas ordenadas, sin las vacías.
fn parse(lrc: &str) -> Vec<Line> {
    let mut lines: Vec<Line> = lrc
        .lines()
        .filter_map(|line| {
            let (stamp, text) = line.strip_prefix('[')?.split_once(']')?;
            let (minutes, seconds) = stamp.split_once(':')?;
            let t = minutes.parse::<f64>().ok()? * 60.0 + seconds.parse::<f64>().ok()?;
            let text = text.trim();
            (!text.is_empty()).then(|| Line { t, text: text.to_owned() })
        })
        .collect();
    lines.sort_by(|a, b| a.t.total_cmp(&b.t));
    lines
}

/// Busca la letra sincronizada de una canción; `None` si LRCLIB no la tiene.
pub fn fetch(title: &str, artist: &str, duration: f64) -> Option<Vec<Line>> {
    let duration = format!("{}", duration.round() as i64);
    let mut exact = vec![("track_name", title), ("artist_name", artist)];
    if duration != "0" {
        exact.push(("duration", duration.as_str()));
    }

    // Coincidencia exacta primero; si falla, el mejor resultado de la búsqueda.
    let synced = get("get", &exact)
        .and_then(|found| found["syncedLyrics"].as_str().map(str::to_owned))
        .or_else(|| {
            let results = get("search", &[("track_name", title), ("artist_name", artist)])?;
            results
                .as_array()?
                .iter()
                .find_map(|entry| entry["syncedLyrics"].as_str().map(str::to_owned))
        })?;

    let lines = parse(&synced);
    (!lines.is_empty()).then_some(lines)
}
