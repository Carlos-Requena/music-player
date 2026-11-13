//! Scrobbling a Last.fm (API 2.0).
//!
//! Necesita una clave de API y su secreto (gratis en last.fm/api/account/create) y que el
//! usuario autorice la app en su navegador una vez. Reglas de Last.fm: «escuchando ahora» al
//! empezar una pista; scrobble cuando dura más de 30 s y se ha escuchado la mitad o 4 minutos.

use std::{
    collections::BTreeMap,
    time::{SystemTime, UNIX_EPOCH},
};

use serde_json::Value;

use super::Track;

const API: &str = "https://ws.audioscrobbler.com/2.0/";

/// Firma de Last.fm: md5 de los parámetros ordenados (`clave` + `valor`) más el secreto.
pub fn sign(params: &BTreeMap<String, String>, secret: &str) -> String {
    let mut text: String = params
        .iter()
        .filter(|(key, _)| key.as_str() != "format" && key.as_str() != "callback")
        .map(|(key, value)| format!("{key}{value}"))
        .collect();
    text.push_str(secret);
    format!("{:x}", md5::compute(text.as_bytes()))
}

fn call(method: &str, mut params: BTreeMap<String, String>, key: &str, secret: &str) -> Result<Value, String> {
    params.insert("method".into(), method.into());
    params.insert("api_key".into(), key.into());
    let signature = sign(&params, secret);
    params.insert("api_sig".into(), signature);
    params.insert("format".into(), "json".into());
    let form: Vec<(&str, &str)> = params.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect();
    let mut response = ureq::post(API)
        .header("User-Agent", "musicplayer/0.1")
        .config()
        .http_status_as_error(false)
        .build()
        .send_form(form)
        .map_err(|error| format!("Last.fm no responde: {error}"))?;
    let value: Value = response.body_mut().read_json().map_err(|error| format!("Respuesta de Last.fm ilegible: {error}"))?;
    if let Some(message) = value["message"].as_str().filter(|_| value["error"].is_number()) {
        return Err(format!("Last.fm: {message}"));
    }
    Ok(value)
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs())
}

/// Paso 1 de la autorización: pide un token y devuelve `(token, url para el navegador)`.
pub fn begin_auth(key: &str, secret: &str) -> Result<(String, String), String> {
    let response = call("auth.getToken", BTreeMap::new(), key, secret)?;
    let token = response["token"].as_str().ok_or("Last.fm no devolvió el token.")?.to_owned();
    let url = format!("https://www.last.fm/api/auth/?api_key={key}&token={token}");
    Ok((token, url))
}

/// Paso 2: con el token ya autorizado en el navegador, devuelve `(clave de sesión, usuario)`.
pub fn finish_auth(key: &str, secret: &str, token: &str) -> Result<(String, String), String> {
    let mut params = BTreeMap::new();
    params.insert("token".to_owned(), token.to_owned());
    let response = call("auth.getSession", params, key, secret)
        .map_err(|error| format!("{error} ¿Has pulsado «Sí, permitir acceso» en la web de Last.fm?"))?;
    let session = &response["session"];
    let sk = session["key"].as_str().ok_or("Last.fm no devolvió la sesión.")?.to_owned();
    let name = session["name"].as_str().unwrap_or_default().to_owned();
    Ok((sk, name))
}

/// Estado de escucha de la pista actual para decidir el scrobble.
pub struct Scrobbler {
    pub key: String,
    pub secret: String,
    pub session: String,
    track: Option<Track>,
    started_at: u64,
    listened: f64,
    last_position: Option<f64>,
    scrobbled: bool,
}

impl Scrobbler {
    pub fn new(key: String, secret: String, session: String) -> Self {
        Self { key, secret, session, track: None, started_at: 0, listened: 0.0, last_position: None, scrobbled: false }
    }

    fn base(&self, track: &Track) -> BTreeMap<String, String> {
        let mut params = BTreeMap::new();
        params.insert("artist".to_owned(), track.artist.clone());
        params.insert("track".to_owned(), track.title.clone());
        params.insert("sk".to_owned(), self.session.clone());
        if track.duration > 0.0 {
            params.insert("duration".to_owned(), (track.duration.round() as u64).to_string());
        }
        params
    }

    /// Empieza una pista: «escuchando ahora».
    pub fn start(&mut self, track: &Track) -> Result<(), String> {
        self.track = Some(track.clone());
        self.started_at = now();
        self.listened = 0.0;
        self.last_position = None;
        self.scrobbled = false;
        call("track.updateNowPlaying", self.base(track), &self.key, &self.secret).map(|_| ())
    }

    /// Avanza la posición; devuelve `true` si acaba de hacer el scrobble.
    pub fn progress(&mut self, position: f64, playing: bool) -> Result<bool, String> {
        let previous = self.last_position.replace(position);
        let Some(track) = self.track.clone() else { return Ok(false) };
        if !playing || self.scrobbled {
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
        self.scrobbled = true;
        let mut params = self.base(&track);
        params.insert("timestamp".to_owned(), self.started_at.to_string());
        call("track.scrobble", params, &self.key, &self.secret).map(|_| true)
    }
}

/// Regla de Last.fm: más de 30 s de pista y escuchada la mitad o 4 minutos.
pub fn should_scrobble(duration: f64, listened: f64) -> bool {
    let duration = if duration > 0.0 { duration } else { 480.0 };
    duration > 30.0 && listened >= (duration / 2.0).min(240.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn firma_como_la_documentacion() {
        // Ejemplo de last.fm/api/authspec: md5("api_keyXXmethodauth.getSessiontokenYYsecreto").
        let mut params = BTreeMap::new();
        params.insert("api_key".into(), "XX".into());
        params.insert("method".into(), "auth.getSession".into());
        params.insert("token".into(), "YY".into());
        params.insert("format".into(), "json".into());
        let expected = format!("{:x}", md5::compute(b"api_keyXXmethodauth.getSessiontokenYYsecreto"));
        assert_eq!(sign(&params, "secreto"), expected);
    }

    #[test]
    fn reglas_de_scrobble() {
        assert!(!should_scrobble(25.0, 25.0)); // demasiado corta
        assert!(!should_scrobble(200.0, 99.0));
        assert!(should_scrobble(200.0, 100.0)); // la mitad
        assert!(should_scrobble(900.0, 240.0)); // 4 minutos
    }
}
