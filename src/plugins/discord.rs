//! Discord Rich Presence: muestra «Escuchando…» en el perfil de Discord.
//!
//! Habla con el cliente de Discord por su socket IPC local (sin dependencias): cada mensaje
//! es `[opcode u32 LE][longitud u32 LE][JSON]`. Hace falta el «Application ID» de una
//! aplicación creada por el usuario en discord.com/developers (es gratis y público).

use std::{
    env,
    io::{Read, Write},
    os::unix::net::UnixStream,
    path::PathBuf,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use serde_json::{json, Value};

use super::Track;

const HANDSHAKE: u32 = 0;
const FRAME: u32 = 1;

pub struct Discord {
    client_id: String,
    stream: Option<UnixStream>,
}

/// Rutas posibles del socket de Discord (nativo, Flatpak, Snap, Vesktop).
fn candidates() -> Vec<PathBuf> {
    let mut dirs: Vec<PathBuf> = ["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP"]
        .iter()
        .filter_map(|key| env::var_os(key).map(PathBuf::from))
        .collect();
    dirs.push(PathBuf::from("/tmp"));
    let mut out = Vec::new();
    for dir in dirs {
        for sub in ["", "app/com.discordapp.Discord", "snap.discord", ".flatpak/dev.vencord.Vesktop/xdg-run"] {
            for n in 0..10 {
                out.push(dir.join(sub).join(format!("discord-ipc-{n}")));
            }
        }
    }
    out
}

/// Codifica un mensaje IPC.
pub fn frame(opcode: u32, payload: &Value) -> Vec<u8> {
    let body = payload.to_string().into_bytes();
    let mut out = Vec::with_capacity(8 + body.len());
    out.extend_from_slice(&opcode.to_le_bytes());
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

fn read_frame(stream: &mut UnixStream) -> std::io::Result<Value> {
    let mut header = [0u8; 8];
    stream.read_exact(&mut header)?;
    let length = u32::from_le_bytes([header[4], header[5], header[6], header[7]]) as usize;
    let mut body = vec![0u8; length.min(1 << 20)];
    stream.read_exact(&mut body)?;
    Ok(serde_json::from_slice(&body).unwrap_or(Value::Null))
}

/// Discord exige textos de 2 a 128 caracteres.
fn field(text: &str) -> String {
    let mut text: String = text.chars().take(128).collect();
    while text.chars().count() < 2 {
        text.push(' ');
    }
    text
}

fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_millis() as u64)
}

/// Actividad de Discord para una pista que suena desde `position` segundos.
pub fn activity(track: &Track, position: f64) -> Value {
    let start = now_ms().saturating_sub((position * 1000.0) as u64);
    let mut activity = json!({
        "type": 2, // «Escuchando»
        "details": field(&track.title),
        "state": field(&track.artist),
        "timestamps": { "start": start },
    });
    if track.duration > 0.0 {
        activity["timestamps"]["end"] = json!(start + (track.duration * 1000.0) as u64);
    }
    if track.thumb.starts_with("https://") && track.thumb.len() <= 256 {
        activity["assets"] = json!({ "large_image": track.thumb, "large_text": field(&track.title) });
    }
    activity
}

impl Discord {
    pub fn new(client_id: &str) -> Self {
        Self { client_id: client_id.to_owned(), stream: None }
    }

    pub fn client_id(&self) -> &str {
        &self.client_id
    }

    pub fn connected(&self) -> bool {
        self.stream.is_some()
    }

    fn connect(&mut self) -> Result<(), String> {
        if self.client_id.trim().is_empty() {
            return Err("Falta el Application ID de Discord.".to_owned());
        }
        let mut stream = candidates()
            .into_iter()
            .find_map(|path| UnixStream::connect(path).ok())
            .ok_or("Discord no está abierto.")?;
        let _ = stream.set_read_timeout(Some(Duration::from_secs(3)));
        let _ = stream.set_write_timeout(Some(Duration::from_secs(3)));
        stream
            .write_all(&frame(HANDSHAKE, &json!({ "v": 1, "client_id": self.client_id.trim() })))
            .map_err(|error| format!("Discord: {error}"))?;
        let ready = read_frame(&mut stream).map_err(|error| format!("Discord no respondió: {error}"))?;
        if ready["evt"] != "READY" {
            let message = ready["data"]["message"].as_str().unwrap_or("respuesta inesperada");
            return Err(format!("Discord rechazó la conexión: {message}"));
        }
        self.stream = Some(stream);
        Ok(())
    }

    /// Publica la actividad (o la borra con `None`). Reconecta si hace falta.
    pub fn set_activity(&mut self, activity: Option<Value>) -> Result<(), String> {
        if self.stream.is_none() {
            self.connect()?;
        }
        let message = json!({
            "cmd": "SET_ACTIVITY",
            "args": { "pid": std::process::id(), "activity": activity },
            "nonce": now_ms().to_string(),
        });
        let stream = self.stream.as_mut().ok_or("sin conexión")?;
        let sent = stream.write_all(&frame(FRAME, &message)).and_then(|_| read_frame(stream).map(|_| ()));
        if let Err(error) = sent {
            // Discord se cerró: se reintentará en el próximo cambio.
            self.stream = None;
            return Err(format!("Se perdió la conexión con Discord: {error}"));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn el_mensaje_lleva_cabecera_de_ocho_bytes() {
        let bytes = frame(1, &json!({ "a": 1 }));
        assert_eq!(&bytes[0..4], &1u32.to_le_bytes());
        assert_eq!(u32::from_le_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]) as usize, bytes.len() - 8);
        assert_eq!(&bytes[8..], br#"{"a":1}"#);
    }

    #[test]
    fn habla_con_un_discord_simulado() {
        use std::os::unix::net::UnixListener;
        let dir = env::temp_dir().join(format!("discord-prueba-{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dir);
        let socket = dir.join("discord-ipc-0");
        let _ = std::fs::remove_file(&socket);
        let listener = UnixListener::bind(&socket).unwrap();
        // El cliente busca el socket en TMPDIR, entre otros.
        unsafe { env::set_var("TMPDIR", &dir) };

        let server = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let handshake = read_frame(&mut stream).unwrap();
            stream.write_all(&frame(1, &json!({ "cmd": "DISPATCH", "evt": "READY" }))).unwrap();
            let request = read_frame(&mut stream).unwrap();
            stream.write_all(&frame(1, &json!({ "cmd": "SET_ACTIVITY", "evt": null }))).unwrap();
            (handshake, request)
        });

        let mut client = Discord::new("1234");
        let track = Track { title: "Canción".into(), artist: "Grupo".into(), duration: 100.0, ..Default::default() };
        client.set_activity(Some(activity(&track, 0.0))).unwrap();
        let (handshake, request) = server.join().unwrap();
        assert_eq!(handshake["client_id"], "1234");
        assert_eq!(request["cmd"], "SET_ACTIVITY");
        assert_eq!(request["args"]["activity"]["details"], "Canción");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn la_actividad_es_de_escucha_con_fin() {
        let track = Track { title: "X".into(), artist: "Grupo".into(), duration: 200.0, thumb: "https://a/b.jpg".into(), ..Default::default() };
        let activity = activity(&track, 10.0);
        assert_eq!(activity["type"], 2);
        assert_eq!(activity["details"], "X "); // mínimo dos caracteres
        let start = activity["timestamps"]["start"].as_u64().unwrap();
        assert_eq!(activity["timestamps"]["end"].as_u64().unwrap() - start, 200_000);
    }
}
