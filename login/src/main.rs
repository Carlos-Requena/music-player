//! `musicplayer-login`: ventana de inicio de sesión de YouTube Music para Linux (Qt WebEngine,
//! `login_linux.cpp`) y Windows (WebView2, `login_windows.rs`).
//!
//! - `musicplayer-login --check`: sale con 0 si hay ventana (Windows siempre; Linux si se
//!   compiló con Qt WebEngine), 3 si no.
//! - `musicplayer-login <archivo>`: abre la ventana; al volver a YouTube Music con la sesión
//!   iniciada escribe las cookies de youtube.com en `<archivo>` (formato Netscape, permisos 600)
//!   y sale con 0. Si el usuario cierra la ventana, sale con 1.
//!
//! El reproductor (`account.rs`) lo lanza como proceso aparte: así no carga ningún motor web.

#![cfg_attr(windows, windows_subsystem = "windows")]

use std::process::exit;

#[cfg(windows)]
mod login_windows;

#[cfg(webengine)]
extern "C" {
    fn musicplayer_login_linux(out_path: *const std::os::raw::c_char) -> i32;
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let Some(argument) = args.get(1) else {
        eprintln!("uso: musicplayer-login <archivo de cookies> | --check");
        exit(2);
    };
    if argument == "--check" {
        exit(if cfg!(any(webengine, windows)) { 0 } else { 3 });
    }

    #[cfg(windows)]
    exit(login_windows::run(argument));

    #[cfg(webengine)]
    {
        let Ok(path) = std::ffi::CString::new(argument.as_str()) else { exit(2) };
        // SAFETY: cadena C válida durante toda la llamada; la función no la guarda.
        exit(unsafe { musicplayer_login_linux(path.as_ptr()) });
    }

    #[cfg(not(any(webengine, windows)))]
    {
        eprintln!("esta compilación no incluye la ventana de inicio de sesión (falta qt6-webengine)");
        exit(3);
    }
}
