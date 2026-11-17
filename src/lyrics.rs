//! Letra sincronizada de varias fuentes abiertas, sin sesión:
//!
//! - **LRCLIB** (https://lrclib.net): LRC línea a línea; a veces, palabra a palabra.
//! - **NetEase Cloud Music** (music.163.com): YRC, con el tiempo de cada sílaba. Mucho anime,
//!   J-pop y C-pop.
//! - **Kugou** (lyrics.kugou.com): KRC, también por sílaba. Mucho anime y J-pop.
//!
//! El reproductor pide las tres a la vez y la interfaz elige cuál mostrar (`rank` las ordena de
//! mejor a peor para la elección automática).

use std::io::Read;
use std::time::Duration;

use base64::Engine;
use serde::Serialize;
use serde_json::Value;

const USER_AGENT: &str = "musicplayer/0.1";
/// Ninguna fuente debe hacer esperar a la letra más que esto.
const TIMEOUT: Duration = Duration::from_secs(8);

/// Línea de letra con su instante de inicio en segundos. Una línea vacía es una pausa
/// instrumental (la interfaz la dibuja como puntos). `w` trae el instante de cada palabra (o
/// sílaba) si la fuente lo da; si no, va vacío.
#[derive(Serialize, Debug, PartialEq)]
pub struct Line {
    pub t: f64,
    pub text: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub w: Vec<Word>,
}

/// Palabra o sílaba con tiempo. `d` es lo que dura (0 si la fuente no lo dice: entonces dura
/// hasta la siguiente). `join`: va pegada a la siguiente, sin espacio (sílabas de una misma
/// palabra, o japonés y chino, que no separan las palabras).
#[derive(Serialize, Debug, PartialEq)]
pub struct Word {
    pub t: f64,
    #[serde(skip_serializing_if = "is_zero")]
    pub d: f64,
    pub text: String,
    #[serde(skip_serializing_if = "is_false")]
    pub join: bool,
}

fn is_zero(value: &f64) -> bool {
    *value == 0.0
}

fn is_false(value: &bool) -> bool {
    !*value
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Source {
    Lrclib,
    Netease,
    Kugou,
}

pub const SOURCES: [Source; 3] = [Source::Lrclib, Source::Netease, Source::Kugou];

impl Source {
    pub fn id(self) -> &'static str {
        match self {
            Source::Lrclib => "lrclib",
            Source::Netease => "netease",
            Source::Kugou => "kugou",
        }
    }

    fn label(self) -> &'static str {
        match self {
            Source::Lrclib => "LRCLIB",
            Source::Netease => "NetEase",
            Source::Kugou => "Kugou",
        }
    }
}

/// Letra encontrada en una fuente. Es lo que recibe la interfaz (una lista, en JSON).
#[derive(Serialize, Debug)]
pub struct Found {
    pub id: &'static str,
    pub label: &'static str,
    /// Trae el tiempo de cada palabra.
    pub words: bool,
    /// Diferencia, en segundos, entre la duración de la letra y la de la pista (si se saben las
    /// dos). Una versión distinta (la de TV, el videoclip con intro) no encaja.
    #[serde(skip)]
    pub delta: Option<f64>,
    pub lines: Vec<Line>,
}

impl Found {
    fn new(source: Source, lines: Vec<Line>, delta: Option<f64>) -> Option<Found> {
        let lines = finish(lines);
        if lines.is_empty() {
            return None;
        }
        let words = lines.iter().any(|line| !line.w.is_empty());
        Some(Found { id: source.id(), label: source.label(), words, delta, lines })
    }

    /// Duración que encaja con la de la pista: 2 sí, 1 no se sabe, 0 no.
    fn fits(&self) -> u8 {
        match self.delta {
            Some(delta) if delta <= MAX_DELTA => 2,
            Some(_) => 0,
            None => 1,
        }
    }
}

/// Más diferencia de duración que esto es otra versión de la canción.
const MAX_DELTA: f64 = 3.0;

/// Ordena de mejor a peor: primero las que encajan con la duración de la pista, luego las que
/// traen tiempos por palabra y, a igualdad, NetEase y Kugou si van por palabra (suelen estar
/// mejor cronometradas) y LRCLIB si van por línea.
pub fn rank(found: &mut [Found]) {
    fn order(found: &Found) -> usize {
        let preference: [&str; 3] = if found.words { ["netease", "kugou", "lrclib"] } else { ["lrclib", "netease", "kugou"] };
        preference.iter().position(|id| *id == found.id).unwrap_or(3)
    }
    found.sort_by_key(|found| (std::cmp::Reverse(found.fits()), !found.words, order(found)));
}

/// Lo que se busca, ya limpio: el título sin «(Official Video)» ni el nombre del artista.
pub struct Query {
    pub title: String,
    pub artist: String,
    /// Segundos; 0 si no se sabe.
    pub duration: f64,
}

impl Query {
    pub fn new(title: &str, artist: &str, duration: f64) -> Query {
        let artist = clean_artist(artist);
        Query { title: clean_title(title, &artist), artist, duration }
    }

    fn delta(&self, seconds: f64) -> Option<f64> {
        (self.duration > 0.0 && seconds > 0.0).then(|| (self.duration - seconds).abs())
    }
}

/// Busca la letra en una fuente; `None` si no la tiene.
pub fn fetch(source: Source, query: &Query) -> Option<Found> {
    if query.title.is_empty() {
        return None;
    }
    let found = match source {
        Source::Lrclib => lrclib(query),
        Source::Netease => netease(query),
        Source::Kugou => kugou(query),
    };
    if found.is_none() {
        eprintln!("letra: {} no tiene «{}» de {}", source.label(), query.title, query.artist);
    }
    found
}

fn get(url: &str, query: &[(&str, &str)]) -> Option<Value> {
    let mut request = crate::ytm::http().get(url).header("User-Agent", USER_AGENT);
    for (key, value) in query {
        request = request.query(*key, *value);
    }
    let request = request.config().timeout_global(Some(TIMEOUT)).build();
    match request.call() {
        Ok(mut response) => response.body_mut().read_json().ok(),
        Err(error) => {
            eprintln!("letra: {url}: {error}");
            None
        }
    }
}

// ---- LRCLIB ----

fn lrclib(query: &Query) -> Option<Found> {
    const ENDPOINT: &str = "https://lrclib.net/api";
    let duration = format!("{}", query.duration.round() as i64);
    let mut exact = vec![("track_name", query.title.as_str()), ("artist_name", query.artist.as_str())];
    if query.duration > 0.0 {
        exact.push(("duration", duration.as_str()));
    }

    // Coincidencia exacta primero (LRCLIB ya comprueba la duración); si falla, el resultado de la
    // búsqueda con la duración más parecida.
    let entry = get(&format!("{ENDPOINT}/get"), &exact)
        .filter(|found| found["syncedLyrics"].is_string())
        .or_else(|| {
            let results = get(&format!("{ENDPOINT}/search"), &[("track_name", &query.title), ("artist_name", &query.artist)])?;
            results
                .as_array()?
                .iter()
                .filter(|entry| entry["syncedLyrics"].is_string())
                .min_by(|a, b| {
                    let delta = |entry: &Value| query.delta(entry["duration"].as_f64().unwrap_or(0.0)).unwrap_or(0.0);
                    delta(a).total_cmp(&delta(b))
                })
                .cloned()
        })?;
    let delta = query.delta(entry["duration"].as_f64().unwrap_or(0.0));
    Found::new(Source::Lrclib, parse(entry["syncedLyrics"].as_str()?), delta)
}

// ---- NetEase ----

fn netease(query: &Query) -> Option<Found> {
    let keyword = format!("{} {}", query.title, query.artist);
    let results = get("https://music.163.com/api/search/get", &[("s", &keyword), ("type", "1"), ("limit", "10")])?;
    let songs = results["result"]["songs"].as_array()?;
    let candidates = songs.iter().map(|song| {
        let mut names = vec![song["name"].as_str().unwrap_or_default()];
        names.extend(song["alias"].as_array().into_iter().flatten().filter_map(Value::as_str));
        Candidate { names, seconds: song["duration"].as_f64().unwrap_or(0.0) / 1000.0, value: song }
    });
    let (song, delta) = best(query, candidates)?;
    let id = song["id"].as_i64()?.to_string();

    let lyric = get(
        "https://music.163.com/api/song/lyric/v1",
        &[("id", &id), ("lv", "1"), ("yv", "1"), ("tv", "-1"), ("rv", "-1")],
    )?;
    let names = [song["name"].as_str().unwrap_or_default()];
    // YRC (por sílaba) si lo tiene; si no, el LRC de siempre.
    let yrc = lyric["yrc"]["lyric"].as_str().map(|text| parse_timed(text, '(', ')', false));
    let lines = match yrc {
        Some(lines) if lines.iter().any(|line| !line.w.is_empty()) => lines,
        _ => parse(lyric["lrc"]["lyric"].as_str()?),
    };
    Found::new(Source::Netease, without_credits(lines, query, &names), delta)
}

// ---- Kugou ----

/// Clave con la que Kugou cifra los KRC (con XOR, byte a byte, tras la cabecera `krc1`).
const KRC_KEY: [u8; 16] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105];

fn kugou(query: &Query) -> Option<Found> {
    let keyword = format!("{} - {}", query.artist, query.title);
    let milliseconds = format!("{}", (query.duration * 1000.0).round() as i64);
    let results = get(
        "https://lyrics.kugou.com/search",
        &[("ver", "1"), ("man", "yes"), ("client", "pc"), ("keyword", &keyword), ("duration", &milliseconds), ("hash", "")],
    )?;
    let candidates = results["candidates"].as_array()?.iter().map(|entry| Candidate {
        names: vec![entry["song"].as_str().unwrap_or_default()],
        seconds: entry["duration"].as_f64().unwrap_or(0.0) / 1000.0,
        value: entry,
    });
    let (entry, delta) = best(query, candidates)?;

    let download = get(
        "https://lyrics.kugou.com/download",
        &[
            ("ver", "1"),
            ("client", "pc"),
            ("id", entry["id"].as_str()?),
            ("accesskey", entry["accesskey"].as_str()?),
            ("fmt", "krc"),
            ("charset", "utf8"),
        ],
    )?;
    let krc = decrypt_krc(download["content"].as_str()?)?;
    let names = [entry["song"].as_str().unwrap_or_default()];
    Found::new(Source::Kugou, without_credits(parse_timed(&krc, '<', '>', true), query, &names), delta)
}

/// KRC cifrado (base64) → texto.
fn decrypt_krc(content: &str) -> Option<String> {
    let bytes = base64::engine::general_purpose::STANDARD.decode(content).ok()?;
    let body = bytes.strip_prefix(b"krc1")?;
    let plain: Vec<u8> = body.iter().enumerate().map(|(i, byte)| byte ^ KRC_KEY[i % KRC_KEY.len()]).collect();
    let mut text = String::new();
    flate2::read::ZlibDecoder::new(plain.as_slice()).read_to_string(&mut text).ok()?;
    Some(text.trim_start_matches('\u{feff}').to_owned())
}

// ---- Elegir el resultado de una búsqueda ----

struct Candidate<'a> {
    names: Vec<&'a str>,
    seconds: f64,
    value: &'a Value,
}

/// El resultado que mejor casa con lo buscado: con el mismo título (o un alias) y la duración
/// más parecida. Sin título parecido solo vale si la duración coincide casi al segundo (los
/// títulos de YouTube pueden ir en romaji y la fuente en japonés).
fn best<'a>(query: &Query, candidates: impl Iterator<Item = Candidate<'a>>) -> Option<(&'a Value, Option<f64>)> {
    let wanted = norm(&query.title);
    candidates
        .filter_map(|candidate| {
            let named = candidate.names.iter().any(|name| similar(&norm(name), &wanted));
            let delta = query.delta(candidate.seconds);
            let close = delta.is_some_and(|delta| delta <= 1.5);
            (named || close).then_some((candidate.value, delta, named))
        })
        // Primero los que encajan en duración; después, con el título; y el más cercano.
        .min_by(|a, b| {
            let key = |(_, delta, named): &(&Value, Option<f64>, bool)| {
                (!delta.is_some_and(|delta| delta <= MAX_DELTA), !named, delta.unwrap_or(f64::MAX))
            };
            let (ka, kb) = (key(a), key(b));
            (ka.0, ka.1).cmp(&(kb.0, kb.1)).then(ka.2.total_cmp(&kb.2))
        })
        .map(|(value, delta, _)| (value, delta))
}

/// Minúsculas y solo letras y números (de cualquier alfabeto).
fn norm(text: &str) -> String {
    text.chars().filter(|c| c.is_alphanumeric()).flat_map(char::to_lowercase).collect()
}

fn similar(a: &str, b: &str) -> bool {
    !a.is_empty() && !b.is_empty() && (a.contains(b) || b.contains(a))
}

// ---- Limpiar lo que da YouTube ----

fn clean_artist(artist: &str) -> String {
    let artist = artist.trim().trim_end_matches(" - Topic").trim_end_matches("VEVO").trim();
    // El primero de varios.
    let first = [", ", " & ", " x ", " × ", "、", " feat. ", " ft. "]
        .iter()
        .filter_map(|sep| artist.find(sep))
        .min()
        .map_or(artist, |at| &artist[..at]);
    first.trim().to_owned()
}

/// Título para buscar: lo de dentro de 『』 o 「」 si lo hay (los canales japoneses ponen así
/// el nombre), sin paréntesis ni corchetes («(Official Video)», «[MV]»), sin «feat.» y sin el
/// artista delante («LiSA - 紅蓮華»).
fn clean_title(title: &str, artist: &str) -> String {
    for (open, close) in [('『', '』'), ('「', '」')] {
        if let Some(inner) = title.split_once(open).and_then(|(_, rest)| rest.split_once(close)).map(|(inner, _)| inner.trim()) {
            if !inner.is_empty() {
                return inner.to_owned();
            }
        }
    }

    let mut out = String::new();
    let mut depth = 0;
    for c in title.chars() {
        match c {
            '(' | '[' | '【' | '（' => depth += 1,
            ')' | ']' | '】' | '）' if depth > 0 => depth -= 1,
            _ if depth == 0 => out.push(c),
            _ => {}
        }
    }
    // Coletillas entre guiones: «-TV ver.-», «-MUSiC CLiP-».
    let mut out = out.split(" -").filter(|piece| !(piece.ends_with('-') && !piece.starts_with(' '))).collect::<Vec<_>>().join(" -");
    out = out.trim().to_owned();
    for marker in [" feat. ", " ft. ", " Feat. ", " Ft. "] {
        if let Some(at) = out.find(marker) {
            out.truncate(at);
        }
    }
    if let Some((left, right)) = out.split_once(" - ") {
        let artist = norm(artist);
        if similar(&norm(left), &artist) {
            out = right.to_owned();
        } else if similar(&norm(right), &artist) || (!left.is_ascii() && right.is_ascii()) {
            // También «紅蓮華 - Gurenge»: el título original y su versión en romaji.
            out = left.to_owned();
        }
    }
    let out = out.trim();
    if out.is_empty() { title.trim().to_owned() } else { out.to_owned() }
}

// ---- Formatos ----

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
            out.push(Word { t, d: 0.0, text: word.to_owned(), join: false });
        }
    }
    let plain = out.iter().map(|word| word.text.as_str()).collect::<Vec<_>>().join(" ");
    if plain.is_empty() {
        // Etiquetas que no eran tiempos: se deja el texto tal cual.
        return (text.trim().to_owned(), Vec::new());
    }
    (plain, out)
}

/// Convierte texto LRC (`[mm:ss.xx] línea`) en líneas.
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
    lines
}

/// Trozos con tiempo de una línea KRC o YRC: `(inicio,duración,0)texto`, con `(`/`)` en YRC
/// y `<`/`>` en KRC. Un paréntesis que no sea de tiempo («(yeah)») es parte del texto.
fn chunks(content: &str, open: char, close: char) -> Vec<(i64, i64, String)> {
    let mut out: Vec<(i64, i64, String)> = Vec::new();
    let mut rest = content;
    while !rest.is_empty() {
        if let Some(tail) = rest.strip_prefix(open) {
            if let Some((tag, after)) = tail.split_once(close) {
                let numbers: Vec<Option<i64>> = tag.split(',').map(|n| n.trim().parse().ok()).collect();
                if let [Some(start), Some(length), Some(_)] = numbers[..] {
                    out.push((start, length, String::new()));
                    rest = after;
                    continue;
                }
            }
        }
        let c = rest.chars().next().unwrap_or_default();
        if let Some(last) = out.last_mut() {
            last.2.push(c);
        }
        rest = &rest[c.len_utf8()..];
    }
    out
}

/// Convierte KRC (Kugou) o YRC (NetEase) en líneas: `[inicio,duración]` y cada sílaba con su
/// tiempo, en milisegundos. En KRC el tiempo de la sílaba cuenta desde el comienzo de la línea
/// (`relative`); en YRC es absoluto. Si entre dos líneas hay un hueco largo, se añade una pausa.
fn parse_timed(text: &str, open: char, close: char, relative: bool) -> Vec<Line> {
    let mut lines: Vec<Line> = Vec::new();
    let mut previous_end: Option<i64> = None;
    for raw in text.lines() {
        let Some((head, content)) = raw.trim().strip_prefix('[').and_then(|tail| tail.split_once(']')) else { continue };
        let Some((start, length)) = head.split_once(',') else { continue }; // [ti:…]: metadatos
        let (Ok(start), Ok(length)) = (start.trim().parse::<i64>(), length.trim().parse::<i64>()) else { continue };

        let mut w: Vec<Word> = Vec::new();
        for (at, duration, text) in chunks(content, open, close) {
            let t = (if relative { start + at } else { at }) as f64 / 1000.0;
            // Un espacio suelto o al principio separa de la palabra anterior.
            if text.starts_with(char::is_whitespace) || text.trim().is_empty() {
                if let Some(last) = w.last_mut() {
                    last.join = false;
                }
            }
            let trimmed = text.trim();
            if trimmed.is_empty() {
                continue;
            }
            let join = !text.ends_with(char::is_whitespace);
            w.push(Word { t, d: duration.max(0) as f64 / 1000.0, text: trimmed.to_owned(), join });
        }
        if let Some(last) = w.last_mut() {
            last.join = false;
        }
        let mut plain = String::new();
        for word in &w {
            plain.push_str(&word.text);
            if !word.join {
                plain.push(' ');
            }
        }
        let plain = plain.trim().to_owned();
        if plain.is_empty() {
            continue;
        }

        if let Some(end) = previous_end {
            if start - end >= PAUSE_GAP {
                lines.push(Line { t: end as f64 / 1000.0, text: String::new(), w: Vec::new() });
            }
        }
        previous_end = Some(start + length);
        lines.push(Line { t: start as f64 / 1000.0, text: plain, w });
    }
    lines
}

/// Un hueco así de largo (en ms) entre dos líneas KRC o YRC es una pausa instrumental.
const PAUSE_GAP: i64 = 4000;

/// Quita los créditos del principio («作词: LiSA», «曲：草野華余子», «紅蓮華 - LiSA»): las
/// fuentes chinas los ponen como líneas de la letra.
fn without_credits(lines: Vec<Line>, query: &Query, names: &[&str]) -> Vec<Line> {
    const ROLES: [&str; 22] = [
        "词", "詞", "曲", "编", "編", "制作", "监制", "混音", "录音", "和声", "吉他", "贝斯", "鼓", "弦", "母带", "演唱",
        "lyric", "compos", "arrang", "produc", "vocal", "mix",
    ];
    let titles: Vec<String> = std::iter::once(query.title.as_str()).chain(names.iter().copied()).map(norm).collect();
    let is_credit = |text: &str| {
        if let Some(at) = text.find([':', '：']) {
            let role = text[..at].trim().to_lowercase();
            if role.chars().count() <= 16 && ROLES.iter().any(|r| role.contains(r)) {
                return true;
            }
        }
        // «Título - Artista» como primera línea.
        text.contains(" - ") && titles.iter().any(|title| similar(&norm(text.split(" - ").next().unwrap_or("")), title))
    };
    let mut head = true;
    lines
        .into_iter()
        .filter(|line| {
            if head && (line.text.is_empty() || is_credit(&line.text)) {
                return line.text.is_empty();
            }
            head = false;
            true
        })
        .collect()
}

/// Una pausa más larga que esto al principio de la canción se muestra como pausa instrumental.
const INTRO_GAP: f64 = 4.0;

/// Ordena las líneas, quita las pausas seguidas y, si la letra tarda en empezar, añade una al
/// principio. Sin ninguna línea con texto, no hay letra.
fn finish(mut lines: Vec<Line>) -> Vec<Line> {
    lines.sort_by(|a, b| a.t.total_cmp(&b.t));
    lines.dedup_by(|next, prev| next.text.is_empty() && prev.text.is_empty());
    // Las pausas del principio sobran: la de la intro se pone abajo si hace falta.
    while lines.first().is_some_and(|line| line.text.is_empty()) {
        lines.remove(0);
    }
    if lines.is_empty() {
        return lines;
    }
    if lines[0].t > INTRO_GAP {
        lines.insert(0, Line { t: 0.0, text: String::new(), w: Vec::new() });
    }
    lines
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(t: f64, text: &str) -> Line {
        Line { t, text: text.to_owned(), w: Vec::new() }
    }

    fn word(t: f64, d: f64, text: &str, join: bool) -> Word {
        Word { t, d, text: text.to_owned(), join }
    }

    #[test]
    fn las_lineas_vacias_son_pausas_y_la_intro_larga_tambien() {
        let lines = finish(parse("[ar:Alguien]\n[00:08.00]Hola\n[00:10.00]\n[00:11.00]\n[00:20.50]Adiós"));
        assert_eq!(lines, vec![line(0.0, ""), line(8.0, "Hola"), line(10.0, ""), line(20.5, "Adiós")]);
    }

    #[test]
    fn varios_tiempos_en_una_linea_y_palabras_con_tiempo() {
        let lines = finish(parse("[00:01.00][00:03.00]Otra vez\n[00:02.00]<00:02.00>Uno <00:02.50>dos"));
        assert_eq!(lines[0], line(1.0, "Otra vez"));
        assert_eq!(lines[1].text, "Uno dos");
        assert_eq!(lines[1].w, vec![word(2.0, 0.0, "Uno", false), word(2.5, 0.0, "dos", false)]);
        assert_eq!(lines[2], line(3.0, "Otra vez"));
    }

    #[test]
    fn sin_texto_no_hay_letra() {
        assert!(finish(parse("[00:01.00]\n[00:02.00]")).is_empty());
    }

    #[test]
    fn krc_silabas_relativas_a_la_linea_y_sin_espacios_en_japones() {
        let krc = "[ti:紅蓮華]\n[1219,1000]<0,561,0>強<561,439,0>く\n[7632,1149]<0,162,0>I'll <162,220,0>spend<382,100,0>ing <500,0,0> <500,200,0>夜";
        let lines = parse_timed(krc, '<', '>', true);
        assert_eq!(lines[0].text, "強く");
        assert_eq!(lines[0].w, vec![word(1.219, 0.561, "強", true), word(1.78, 0.439, "く", false)]);
        // Más de 4 s entre el final de una línea y la siguiente: pausa.
        assert_eq!(lines[1], line(2.219, ""));
        // Sílabas de una palabra pegadas; espacio suelto, separa.
        assert_eq!(lines[2].text, "I'll spending 夜");
        assert_eq!(lines[2].w.iter().map(|w| w.join).collect::<Vec<_>>(), vec![false, true, false, false]);
        assert_eq!(lines[2].w[0].t, 7.632);
    }

    #[test]
    fn yrc_con_tiempos_absolutos_parentesis_de_texto_y_pausas() {
        let yrc = "{\"t\":0,\"c\":[{\"tx\":\"作词: \"}]}\n[930,1000](930,730,0)強(1660,270,0)く\n[9000,800](9000,400,0)(yeah) (9400,400,0)go";
        let lines = parse_timed(yrc, '(', ')', false);
        assert_eq!(lines[0].w[1], word(1.66, 0.27, "く", false));
        // Hueco de 7 s: pausa al final de la primera línea.
        assert_eq!(lines[1], line(1.93, ""));
        assert_eq!(lines[2].text, "(yeah) go");
    }

    #[test]
    fn los_creditos_del_principio_se_quitan() {
        let query = Query::new("Gurenge", "LiSA", 0.0);
        let lines = vec![
            line(0.0, "紅蓮華 - LiSA (織部里沙)"),
            line(0.3, "词：LiSA"),
            line(0.5, "作曲: 草野華余子"),
            line(0.8, "Composed by：Ayase/Konnie Aoki"),
            line(1.2, "強くなれる理由を知った"),
            line(9.0, "曲：これは歌詞"),
        ];
        let kept = without_credits(lines, &query, &["紅蓮華"]);
        assert_eq!(kept.iter().map(|l| l.text.as_str()).collect::<Vec<_>>(), vec!["強くなれる理由を知った", "曲：これは歌詞"]);
    }

    #[test]
    fn titulos_de_youtube_limpios_para_buscar() {
        assert_eq!(clean_title("YOASOBI「アイドル」 Official Music Video", "YOASOBI"), "アイドル");
        assert_eq!(clean_title("LiSA『紅蓮華』 -MUSiC CLiP-", "LiSA"), "紅蓮華");
        assert_eq!(clean_title("LiSA - Gurenge (Official Video) [4K]", "LiSA"), "Gurenge");
        assert_eq!(clean_title("Blinding Lights feat. Someone", "The Weeknd"), "Blinding Lights");
        assert_eq!(clean_title("(Intro)", "X"), "(Intro)");
        assert_eq!(clean_title("紅蓮華 -TV ver.- - Gurenge -TV version-", "LiSA"), "紅蓮華");
        assert_eq!(clean_title("Rock - Paper", "Band"), "Rock - Paper");
        assert_eq!(clean_artist("Kenshi Yonezu, Hikaru Utada"), "Kenshi Yonezu");
        assert_eq!(clean_artist("LiSA - Topic"), "LiSA");
    }

    #[test]
    fn el_resultado_con_la_duracion_buena_gana() {
        let query = Query::new("紅蓮華", "LiSA", 236.0);
        let tv = serde_json::json!({ "n": "tv" });
        let full = serde_json::json!({ "n": "full" });
        let other = serde_json::json!({ "n": "other" });
        let candidates = vec![
            Candidate { names: vec!["紅蓮華"], seconds: 89.0, value: &tv },
            Candidate { names: vec!["Otra canción"], seconds: 200.0, value: &other },
            Candidate { names: vec!["紅蓮華 (TV size)", "Gurenge"], seconds: 237.0, value: &full },
        ];
        let (value, delta) = best(&query, candidates.into_iter()).unwrap();
        assert_eq!(value["n"], "full");
        assert_eq!(delta, Some(1.0));
    }

    #[test]
    fn primero_lo_que_encaja_y_trae_palabras() {
        let found = |source: Source, words: bool, delta: Option<f64>| Found {
            id: source.id(),
            label: source.label(),
            words,
            delta,
            lines: Vec::new(),
        };
        let mut all = vec![
            found(Source::Lrclib, false, Some(0.5)),
            found(Source::Kugou, true, Some(0.0)),
            found(Source::Netease, true, Some(40.0)),
        ];
        rank(&mut all);
        assert_eq!(all.iter().map(|f| f.id).collect::<Vec<_>>(), vec!["kugou", "lrclib", "netease"]);
    }
}
