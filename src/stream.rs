//! Vía rápida para obtener el audio: la API del reproductor de YouTube (`/player`) con el
//! cliente de visionOS, que devuelve URLs directas sin descifrado JavaScript ni tokens.
//!
//! Tarda ~0,3 s frente a los 2,5–4 s de yt-dlp, que queda como respaldo cuando esta vía
//! falla (vídeos con restricciones, cambios de YouTube). YouTube exige un «visitor data»
//! (identificador de visitante) para no pedir la verificación anti-bot; se obtiene una vez
//! con `/visitor_id` y se reutiliza.

use std::sync::{LazyLock, Mutex};

use serde_json::{json, Value};

const PLAYER: &str = "https://www.youtube.com/youtubei/v1/player?prettyPrint=false";
const VISITOR: &str = "https://music.youtube.com/youtubei/v1/visitor_id?prettyPrint=false";

// Datos del cliente de visionOS tal como los usa yt-dlp (extractor/youtube/_base.py).
const CLIENT_NAME: &str = "VISIONOS";
const CLIENT_ID: &str = "101";
const CLIENT_VERSION: &str = "1.02";
const USER_AGENT: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 \
     (KHTML, like Gecko) Version/26.0 Safari/605.1.15";

/// Formatos de solo audio por preferencia: Opus 160k, AAC 128k, Opus 64k y 48k, AAC 48k.
const AUDIO_ITAGS: &[u64] = &[251, 140, 250, 249, 139];

static VISITOR_DATA: LazyLock<Mutex<String>> = LazyLock::new(Default::default);

fn visitor_data() -> Result<String, String> {
    if let Ok(current) = VISITOR_DATA.lock() {
        if !current.is_empty() {
            return Ok(current.clone());
        }
    }
    let body = json!({
        "context": { "client": { "clientName": "WEB_REMIX", "clientVersion": "1.20251101.01.00", "hl": "es", "gl": "ES" } }
    });
    let response: Value = ureq::post(VISITOR)
        .header("Origin", "https://music.youtube.com")
        .header("User-Agent", USER_AGENT)
        .send_json(&body)
        .map_err(|error| format!("visitor_id: {error}"))?
        .body_mut()
        .read_json()
        .map_err(|error| format!("visitor_id ilegible: {error}"))?;
    let visitor = response["responseContext"]["visitorData"].as_str().unwrap_or_default().to_owned();
    if visitor.is_empty() {
        return Err("YouTube no devolvió visitor data".to_owned());
    }
    if let Ok(mut current) = VISITOR_DATA.lock() {
        *current = visitor.clone();
    }
    Ok(visitor)
}

/// Olvida el visitor data (si YouTube empieza a pedir verificación, se pide otro).
fn reset_visitor() {
    if let Ok(mut current) = VISITOR_DATA.lock() {
        current.clear();
    }
}

fn request(video_id: &str, visitor: &str) -> Result<Value, String> {
    let body = json!({
        "context": { "client": {
            "clientName": CLIENT_NAME,
            "clientVersion": CLIENT_VERSION,
            "deviceMake": "Apple",
            "deviceModel": "RealityDevice17,1",
            "osName": "visionOS",
            "osVersion": "26.5.23O471",
            "userAgent": USER_AGENT,
            "visitorData": visitor,
            "hl": "es",
            "gl": "ES",
        } },
        "videoId": video_id,
        "contentCheckOk": true,
        "racyCheckOk": true,
    });
    ureq::post(PLAYER)
        .header("User-Agent", USER_AGENT)
        .header("Origin", "https://www.youtube.com")
        .header("X-YouTube-Client-Name", CLIENT_ID)
        .header("X-YouTube-Client-Version", CLIENT_VERSION)
        .header("X-Goog-Visitor-Id", visitor)
        .send_json(&body)
        .map_err(|error| format!("player: {error}"))?
        .body_mut()
        .with_config()
        .limit(8 * 1024 * 1024)
        .read_json()
        .map_err(|error| format!("player ilegible: {error}"))
}

/// Mejor URL de solo audio de una respuesta de `/player`.
fn best_audio(player: &Value) -> Option<String> {
    let formats = player["streamingData"]["adaptiveFormats"].as_array()?;
    AUDIO_ITAGS.iter().find_map(|itag| {
        formats
            .iter()
            .find(|format| format["itag"].as_u64() == Some(*itag))
            .and_then(|format| format["url"].as_str())
            .map(str::to_owned)
    })
}

/// ¿YouTube se negó a dar la pista (no disponible sin sesión, restringida…)? Distinto de un
/// fallo de red o de la verificación anti-bot, que sí merecen otro intento.
pub fn refused(error: &str) -> bool {
    error.starts_with("player (")
}

/// URL de audio de `video_id` por la vía rápida.
pub fn resolve(video_id: &str) -> Result<String, String> {
    for attempt in 0..2 {
        let visitor = visitor_data()?;
        let player = request(video_id, &visitor)?;
        let status = player["playabilityStatus"]["status"].as_str().unwrap_or_default();
        if status == "OK" {
            return best_audio(&player).ok_or_else(|| "sin formatos de audio directos".to_owned());
        }
        let reason = player["playabilityStatus"]["reason"].as_str().unwrap_or(status).to_owned();
        // Verificación anti-bot: con un visitor data nuevo suele pasar.
        if status == "LOGIN_REQUIRED" && attempt == 0 {
            reset_visitor();
            continue;
        }
        return Err(format!("player ({status}): {reason}"));
    }
    Err("player: YouTube pide verificación".to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn elige_el_mejor_audio_disponible() {
        let player = json!({ "streamingData": { "adaptiveFormats": [
            { "itag": 137, "url": "video" },
            { "itag": 140, "url": "aac" },
            { "itag": 251, "signatureCipher": "cifrado" },
            { "itag": 250, "url": "opus64" },
        ] } });
        // 251 está cifrado (sin `url`): se salta y gana AAC 128k.
        assert_eq!(best_audio(&player).as_deref(), Some("aac"));
    }
}
