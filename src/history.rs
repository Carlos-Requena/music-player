//! Registro de reproducciones en la cuenta de YouTube Music (opción `historial`).
//!
//! YouTube no cuenta una escucha al pedir el audio, sino con los avisos que su reproductor
//! envía mientras suena: uno al empezar (`videostatsPlaybackUrl`, añade la pista al
//! historial) y otros con los tramos escuchados (`videostatsWatchtimeUrl`, el tiempo que
//! cuenta como reproducción y para las recomendaciones). Sus direcciones llegan en la
//! respuesta de `/player` con la sesión.
//!
//! Nada de esto toca el arranque de la pista: se pide cuando ya suena, en un hilo aparte, y
//! un fallo solo se apunta en stderr.

use std::sync::atomic::{AtomicBool, Ordering};

static ENABLED: AtomicBool = AtomicBool::new(true);

pub fn set_enabled(enabled: bool) {
    ENABLED.store(enabled, Ordering::Relaxed);
}

/// Hay que registrar: la opción está activada y hay sesión.
pub fn active() -> bool {
    ENABLED.load(Ordering::Relaxed) && crate::account::with_session(|_| ()).is_some()
}

/// Direcciones de registro de una pista y el identificador de esta escucha.
#[derive(Clone, Debug)]
pub struct Report {
    playback: String,
    watchtime: String,
    /// «Client playback nonce»: une los avisos de una misma escucha.
    cpn: String,
}

/// Pide a YouTube Music las direcciones de registro de `video_id` y avisa de que empieza.
pub fn start(video_id: &str) -> Result<Report, String> {
    let (playback, watchtime) = crate::ytm::tracking_urls(video_id)?;
    let report = Report { playback, watchtime, cpn: nonce() };
    ping(&report.playback, &[("ver", "2".into()), ("cpn", report.cpn.clone()), ("cmt", "0".into())])?;
    Ok(report)
}

/// Avisa de que se escuchó el tramo `from`–`to` (segundos de la pista).
pub fn watched(report: &Report, from: f64, to: f64) -> Result<(), String> {
    let (from, to) = (format!("{from:.3}"), format!("{to:.3}"));
    ping(
        &report.watchtime,
        &[
            ("ver", "2".into()),
            ("cpn", report.cpn.clone()),
            ("cmt", to.clone()),
            ("st", from),
            ("et", to),
            ("state", "playing".into()),
        ],
    )
}

/// 16 caracteres al azar del alfabeto que usa el reproductor web (como yt-dlp).
fn nonce() -> String {
    const ALPHABET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    let mut seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0x9E37_79B9_7F4A_7C15, |d| d.as_nanos() as u64)
        | 1;
    (0..16)
        .map(|_| {
            seed ^= seed >> 12;
            seed ^= seed << 25;
            seed ^= seed >> 27;
            ALPHABET[(seed.wrapping_mul(0x2545_F491_4F6C_DD1D) >> 58) as usize] as char
        })
        .collect()
}

/// `base` con los parámetros `extra` puestos (sustituye los que ya traiga).
fn with_params(base: &str, extra: &[(&str, String)]) -> String {
    let (path, query) = base.split_once('?').unwrap_or((base, ""));
    let mut pairs: Vec<String> = query
        .split('&')
        .filter(|pair| !pair.is_empty())
        .filter(|pair| {
            let key = pair.split('=').next().unwrap_or_default();
            !extra.iter().any(|(name, _)| *name == key)
        })
        .map(str::to_owned)
        .collect();
    pairs.extend(extra.iter().map(|(name, value)| format!("{name}={value}")));
    format!("{path}?{}", pairs.join("&"))
}

/// Solo se mandan las cookies de la cuenta a servidores de YouTube.
fn is_youtube(url: &str) -> bool {
    let host = url.strip_prefix("https://").and_then(|rest| rest.split('/').next()).unwrap_or_default();
    host == "youtube.com" || host.ends_with(".youtube.com")
}

fn ping(base: &str, extra: &[(&str, String)]) -> Result<(), String> {
    if !is_youtube(base) {
        return Err(format!("dirección de registro inesperada: {base}"));
    }
    let Some((cookie, authorization)) = crate::account::with_session(|session| session.headers()) else {
        return Err("sin sesión".to_owned());
    };
    ureq::get(with_params(base, extra))
        .header("User-Agent", crate::ytm::USER_AGENT)
        .header("Origin", "https://music.youtube.com")
        .header("Referer", "https://music.youtube.com/")
        .header("Cookie", cookie)
        .header("Authorization", authorization)
        .header("X-Goog-AuthUser", "0")
        .call()
        .map(|_| ())
        .map_err(|error| format!("YouTube no aceptó el registro: {error}"))
}

#[cfg(test)]
mod tests {
    use super::{is_youtube, nonce, with_params};

    #[test]
    fn los_parametros_se_sustituyen() {
        let url = with_params("https://s.youtube.com/api/stats/playback?ns=yt&cpn=viejo&docid=x", &[("cpn", "nuevo".into()), ("ver", "2".into())]);
        assert_eq!(url, "https://s.youtube.com/api/stats/playback?ns=yt&docid=x&cpn=nuevo&ver=2");
    }

    #[test]
    fn el_nonce_tiene_16_caracteres_validos() {
        let cpn = nonce();
        assert_eq!(cpn.len(), 16);
        assert!(cpn.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_'));
    }

    #[test]
    fn solo_se_firman_servidores_de_youtube() {
        assert!(is_youtube("https://s.youtube.com/api/stats/playback?x"));
        assert!(is_youtube("https://music.youtube.com/api/stats/watchtime?x"));
        assert!(!is_youtube("https://youtube.com.evil.example/x"));
        assert!(!is_youtube("http://s.youtube.com/x"));
    }
}
