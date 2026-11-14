//! Letra sincronizada desde LRCLIB (https://lrclib.net), una base de datos abierta.

use serde::Serialize;
use serde_json::Value;

const ENDPOINT: &str = "https://lrclib.net/api";
const USER_AGENT: &str = "musicplayer/0.1";

/// Línea de letra con su instante de inicio en segundos. Una línea vacía es una pausa
/// instrumental (la interfaz la dibuja como puntos). `w` trae el instante de cada palabra si
/// el LRC es «mejorado» (`<mm:ss.xx>` delante de cada palabra); si no, va vacío.
#[derive(Serialize, Debug, PartialEq)]
pub struct Line {
    pub t: f64,
    pub text: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub w: Vec<Word>,
}

#[derive(Serialize, Debug, PartialEq)]
pub struct Word {
    pub t: f64,
    pub text: String,
}

/// Una pausa más larga que esto al principio de la canción se muestra como pausa instrumental.
const INTRO_GAP: f64 = 4.0;

fn get(path: &str, query: &[(&str, &str)]) -> Option<Value> {
    let mut request = ureq::get(format!("{ENDPOINT}/{path}")).header("User-Agent", USER_AGENT);
    for (key, value) in query {
        request = request.query(*key, *value);
    }
    request.call().ok()?.body_mut().read_json().ok()
}

/// `mm:ss.xx` → segundos.
fn stamp(text: &str) -> Option<f64> {
    let (minutes, seconds) = text.split_once(':')?;
    Some(minutes.trim().parse::<f64>().ok()? * 60.0 + seconds.trim().parse::<f64>().ok()?)
}

/// Palabras con su instante de una línea LRC mejorada (`<00:12.30>Hola <00:12.80>mundo`).
fn words(text: &str) -> (String, Vec<Word>) {
    if !text.contains('<') {
        return (text.trim().to_owned(), Vec::new());
    }
    let mut out = Vec::new();
    for chunk in text.split('<').skip(1) {
        let Some((at, word)) = chunk.split_once('>') else { continue };
        let (Some(t), word) = (stamp(at), word.trim()) else { continue };
        if !word.is_empty() {
            out.push(Word { t, text: word.to_owned() });
        }
    }
    let plain = out.iter().map(|word| word.text.as_str()).collect::<Vec<_>>().join(" ");
    if plain.is_empty() {
        // Etiquetas que no eran tiempos: se deja el texto tal cual.
        return (text.trim().to_owned(), Vec::new());
    }
    (plain, out)
}

/// Convierte texto LRC (`[mm:ss.xx] línea`) en líneas ordenadas. Las vacías quedan como pausas
/// (sin repetir dos seguidas) y, si la letra tarda en empezar, se añade una al principio.
fn parse(lrc: &str) -> Vec<Line> {
    let mut lines: Vec<Line> = Vec::new();
    for raw in lrc.lines() {
        // Una línea puede llevar varios tiempos: `[00:12.00][01:30.00]estribillo`.
        let mut rest = raw.trim();
        let mut times = Vec::new();
        while let Some(tail) = rest.strip_prefix('[') {
            let Some((tag, after)) = tail.split_once(']') else { break };
            match stamp(tag) {
                Some(t) => times.push(t),
                None => break, // [ar:…], [ti:…]: metadatos, no letra
            }
            rest = after;
        }
        for t in times {
            let (text, w) = words(rest);
            lines.push(Line { t, text, w });
        }
    }
    lines.sort_by(|a, b| a.t.total_cmp(&b.t));
    // Sin pausas seguidas ni al final de dos en dos; si no hay ninguna línea con texto, nada.
    lines.dedup_by(|next, prev| next.text.is_empty() && prev.text.is_empty());
    if !lines.iter().any(|line| !line.text.is_empty()) {
        return Vec::new();
    }
    match lines.first() {
        Some(first) if !first.text.is_empty() && first.t > INTRO_GAP => {
            lines.insert(0, Line { t: 0.0, text: String::new(), w: Vec::new() });
        }
        _ => {}
    }
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

#[cfg(test)]
mod tests {
    use super::{parse, Line, Word};

    fn line(t: f64, text: &str) -> Line {
        Line { t, text: text.to_owned(), w: Vec::new() }
    }

    #[test]
    fn las_lineas_vacias_son_pausas_y_la_intro_larga_tambien() {
        let lines = parse("[ar:Alguien]\n[00:08.00]Hola\n[00:10.00]\n[00:11.00]\n[00:20.50]Adiós");
        assert_eq!(lines, vec![line(0.0, ""), line(8.0, "Hola"), line(10.0, ""), line(20.5, "Adiós")]);
    }

    #[test]
    fn varios_tiempos_en_una_linea_y_palabras_con_tiempo() {
        let lines = parse("[00:01.00][00:03.00]Otra vez\n[00:02.00]<00:02.00>Uno <00:02.50>dos");
        assert_eq!(lines[0], line(1.0, "Otra vez"));
        assert_eq!(lines[1].text, "Uno dos");
        assert_eq!(lines[1].w, vec![Word { t: 2.0, text: "Uno".into() }, Word { t: 2.5, text: "dos".into() }]);
        assert_eq!(lines[2], line(3.0, "Otra vez"));
    }

    #[test]
    fn sin_texto_no_hay_letra() {
        assert!(parse("[00:01.00]\n[00:02.00]").is_empty());
    }
}
