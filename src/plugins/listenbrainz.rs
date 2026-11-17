//! Escuchas en ListenBrainz: de ellas salen las recomendaciones de Explorar
//! ([ADR-19](../../docs/decisions/ADR-19-explorar-con-listenbrainz.md)).
//!
//! Basta con el token del usuario (listenbrainz.org/settings). «Escuchando ahora» al empezar una
//! pista y la escucha cuando se cumplen las mismas reglas que en Last.fm (más de 30 s de pista y
//! escuchada la mitad o 4 minutos).

use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

use super::{lastfm::should_scrobble, Track};
use crate::listenbrainz;

/// Datos de una pista para `submit-listens`.
fn metadata(track: &Track) -> Value {
    let mut info = json!({
        "media_player": "musicplayer",
        "submission_client": "musicplayer",
        "submission_client_version": env!("CARGO_PKG_VERSION"),
        "music_service": "music.youtube.com",
    });
    if !track.video_id.is_empty() {
        info["origin_url"] = json!(format!("https://music.youtube.com/watch?v={}", track.video_id));
    }
    if track.duration > 0.0 {
        info["duration_ms"] = json!((track.duration * 1000.0).round() as u64);
    }
    json!({ "artist_name": track.artist, "track_name": track.title, "additional_info": info })
}

fn submit(token: &str, kind: &str, listen: Value) -> Result<(), String> {
    let body = json!({ "listen_type": kind, "payload": [listen] });
    listenbrainz::post("/submit-listens", token, &body).map(|_| ())
}

/// Estado de escucha de la pista actual para decidir cuándo enviarla.
pub struct Submitter {
    pub token: String,
    track: Option<Track>,
    started_at: u64,
    listened: f64,
    last_position: Option<f64>,
    sent: bool,
}

impl Submitter {
    pub fn new(token: String) -> Self {
        Self { token, track: None, started_at: 0, listened: 0.0, last_position: None, sent: false }
    }

    /// Empieza una pista: «escuchando ahora».
    pub fn start(&mut self, track: &Track) -> Result<(), String> {
        self.track = Some(track.clone());
        self.started_at = SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs());
        self.listened = 0.0;
        self.last_position = None;
        self.sent = false;
        submit(&self.token, "playing_now", json!({ "track_metadata": metadata(track) }))
    }

    /// Avanza la posición; devuelve `true` si acaba de enviar la escucha.
    pub fn progress(&mut self, position: f64, playing: bool) -> Result<bool, String> {
        let previous = self.last_position.replace(position);
        let Some(track) = self.track.clone() else { return Ok(false) };
        if !playing || self.sent {
            return Ok(false);
        }
        // Solo cuenta el avance normal; un salto no suma tiempo escuchado.
        if let Some(previous) = previous {
            let delta = position - previous;
            if delta > 0.0 && delta < 2.0 {
                self.listened += delta;
            }
        }
        if !should_scrobble(track.duration, self.listened) {
            return Ok(false);
        }
        self.sent = true;
        let listen = json!({ "listened_at": self.started_at, "track_metadata": metadata(&track) });
        submit(&self.token, "single", listen).map(|_| true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn datos_de_la_escucha() {
        let track = Track { title: "Sherpa".into(), artist: "Angine de Poitrine".into(), video_id: "abc".into(), duration: 343.3, ..Track::default() };
        let data = metadata(&track);
        assert_eq!(data["track_name"], "Sherpa");
        assert_eq!(data["artist_name"], "Angine de Poitrine");
        assert_eq!(data["additional_info"]["origin_url"], "https://music.youtube.com/watch?v=abc");
        assert_eq!(data["additional_info"]["duration_ms"], 343_300);
        let unknown = metadata(&Track { title: "x".into(), ..Track::default() });
        assert!(unknown["additional_info"].get("duration_ms").is_none());
    }
}
