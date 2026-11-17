mod account;
mod audio;
mod daemon;
mod history;
mod library;
mod lyrics;
mod player;
mod plugins;
mod resolver;
mod settings;
mod stream;
mod ytm;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

/// `--probe <qué> [argumento]`: consulta la red sin abrir la ventana e imprime un
/// resumen. Sirve para comprobar el cliente de YouTube Music desde la terminal.
fn probe(args: &[String]) -> bool {
    let Some(at) = args.iter().position(|arg| arg == "--probe") else { return false };
    let what = args.get(at + 1).map(String::as_str).unwrap_or("home");
    let argument = args.get(at + 2).map(String::as_str).unwrap_or_default();

    let zones = match what {
        "home" => ytm::browse("FEmusic_home"),
        "explore" => ytm::browse("FEmusic_explore"),
        "albums" => ytm::browse("FEmusic_new_releases_albums"),
        "playlists" => ytm::mood_playlists(3),
        "search" => ytm::search(argument),
        "queue" | "album" => {
            let tracks = if what == "queue" { ytm::queue(argument, "") } else { ytm::playlist_tracks(argument) };
            match tracks {
                Ok(tracks) => {
                    for track in tracks.iter().take(8) {
                        println!("{} — {} ({} s) {}", track.title, track.artist, track.duration, track.video_id);
                    }
                    println!("{} pistas", tracks.len());
                }
                Err(error) => eprintln!("{error}"),
            }
            return true;
        }
        "cookies" => {
            // Diagnóstico del inicio de sesión: solo cuenta y nombra cookies, no guarda nada.
            print!("{}", account::diagnose(if argument.is_empty() { "chrome" } else { argument }));
            return true;
        }
        "playable" => {
            // Qué dice el reproductor de YouTube Music (con la sesión guardada) de cada pista.
            for id in argument.split(',').filter(|id| !id.is_empty()) {
                println!("{id}: {:?}", ytm::playability(id));
            }
            return true;
        }
        "account" => {
            // ¿YouTube reconoce la sesión guardada? Solo imprime el nombre de la cuenta.
            println!("sesión guardada: {}", account::cookies_file().is_some());
            println!("cuenta según YouTube: {:?}", ytm::account_name());
            return true;
        }
        "fast" => {
            // Prueba la vía rápida con varias pistas (`id1,id2,…`) e imprime por qué falla.
            for id in argument.split(',').filter(|id| !id.is_empty()) {
                let start = std::time::Instant::now();
                match stream::resolve(id) {
                    Ok(_) => println!("{id}: ok en {} ms", start.elapsed().as_millis()),
                    Err(error) => println!("{id}: FALLO {error}"),
                }
            }
            return true;
        }
        "url" => {
            match stream::resolve(argument) {
                Ok(url) => println!("{url}"),
                Err(error) => eprintln!("{error}"),
            }
            return true;
        }
        "resolve" => {
            // Mide la resolución con el yt-dlp residente: la primera arranca el servidor.
            println!("intérprete: {:?}", daemon::interpreter_path());
            for id in argument.split(',') {
                let start = std::time::Instant::now();
                let result = resolver::resolve(id);
                match result {
                    Ok(_) => println!("{id}: {} ms ok", start.elapsed().as_millis()),
                    Err(error) => println!("{id}: {} ms ERROR {}", start.elapsed().as_millis(), error.trim_start_matches('\u{0}')),
                }
            }
            return true;
        }
        "play" => {
            // Reproduce un vídeo 25 s e imprime lo que cuenta el motor de audio.
            use audio::{Event, Mpv};
            let start = std::time::Instant::now();
            let engine = Mpv::spawn(move |event| match event {
                Event::Started => println!("sonando a los {} ms", start.elapsed().as_millis()),
                Event::Failed => println!("FALLO a los {} ms", start.elapsed().as_millis()),
                Event::Position(at) if at.fract() < 0.1 && (at as u64) % 5 == 0 => println!("posición {at:.0} s"),
                Event::Paused(paused) => println!("pausa {paused}"),
                Event::Ended => println!("fin a los {} ms", start.elapsed().as_millis()),
                _ => {}
            });
            match engine {
                Ok(mut mpv) => {
                    // Mismo camino que la app: resolver con yt-dlp y cargar la URL directa.
                    let resolved = std::time::Instant::now();
                    match resolver::resolve(argument) {
                        Ok(url) => {
                            println!("resuelta en {} ms", resolved.elapsed().as_millis());
                            if let Err(error) = mpv.load(&url) {
                                eprintln!("{error}");
                            }
                        }
                        Err(error) => println!("{error}"),
                    }
                    std::thread::sleep(std::time::Duration::from_secs(25));
                }
                Err(error) => eprintln!("{error}"),
            }
            return true;
        }
        "lyrics" => {
            // `--probe lyrics <título> <artista> [segundos]`: qué tiene cada fuente.
            let artist = args.get(at + 3).map(String::as_str).unwrap_or_default();
            let duration = args.get(at + 4).and_then(|d| d.parse().ok()).unwrap_or(0.0);
            let query = lyrics::Query::new(argument, artist, duration);
            println!("buscando «{}» de «{}»", query.title, query.artist);
            for source in lyrics::SOURCES {
                match lyrics::fetch(source, &query) {
                    Some(found) => {
                        let delta = found.delta.map_or("?".to_owned(), |d| format!("{d:.1} s"));
                        let kind = if found.words { "por palabra" } else { "por línea" };
                        println!("{}: {} líneas, {kind}, diferencia de duración {delta}", found.label, found.lines.len());
                        for line in found.lines.iter().filter(|line| !line.text.is_empty()).take(3) {
                            println!("  [{:.2}] {} ({} palabras)", line.t, line.text, line.w.len());
                        }
                    }
                    None => println!("{}: sin letra sincronizada", source.id()),
                }
            }
            return true;
        }
        other => Err(format!("sonda desconocida: {other}")),
    };

    match zones {
        Ok(zones) => {
            for zone in zones {
                println!("== {} ({})", zone.titulo, zone.items.len());
                for item in zone.items.iter().take(3) {
                    println!(
                        "   [{}] {} · {} · v={} p={}",
                        item.kind, item.title, item.subtitle, item.video_id, item.playlist_id
                    );
                }
            }
        }
        Err(error) => eprintln!("{error}"),
    }
    true
}

fn login_window(out_path: &str) -> i32 {
    #[cfg(target_os = "macos")]
    if let Ok(path) = std::ffi::CString::new(out_path) {
        // SAFETY: cadena C válida durante toda la llamada; la función no la guarda.
        return unsafe { musicplayer_login(path.as_ptr()) };
    }
    let _ = out_path;
    eprintln!("la ventana de inicio de sesión solo existe en macOS");
    2
}

extern "C" {
    /// `src/window.cpp`: libera los recursos gráficos de las ventanas minimizadas u ocultas.
    fn musicplayer_tune_windows();
    /// `src/window.cpp`: no usar el proxy automático del sistema (WPAD) en Qt.
    fn musicplayer_configure_network();
    /// `src/signals.cpp`: SIGTERM, SIGINT y SIGHUP cierran la app como salir de la ventana.
    fn musicplayer_handle_signals();
}

#[cfg(target_os = "macos")]
extern "C" {
    /// `src/login_mac.mm`: ventana de inicio de sesión; escribe las cookies en `out_path`.
    fn musicplayer_login(out_path: *const std::os::raw::c_char) -> i32;
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    // `--login <archivo>`: proceso aparte que solo muestra la ventana de inicio de sesión
    // (lo lanza `Account.signInWeb`). No arranca Qt.
    if let Some(at) = args.iter().position(|arg| arg == "--login") {
        let code = login_window(args.get(at + 1).map(String::as_str).unwrap_or_default());
        std::process::exit(code);
    }
    if probe(&args) {
        return;
    }

    cxx_qt::init_crate!(musicplayer);
    cxx_qt::init_qml_module!("app.musicplayer");

    let mut app = QGuiApplication::new();
    // SAFETY: función C++ sin argumentos; con la aplicación de Qt ya creada, en su hilo. Así
    // un `kill` también destruye el `Player` y cierra mpv en vez de dejarlo huérfano.
    unsafe { musicplayer_handle_signals() };
    // SAFETY: función C++ sin argumentos; antes de que QML empiece a descargar imágenes.
    unsafe { musicplayer_configure_network() };
    let mut engine = QQmlApplicationEngine::new();

    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/app/musicplayer/qml/Main.qml"));
    }
    // SAFETY: función C++ sin argumentos; se llama en el hilo de Qt tras crear las ventanas.
    unsafe { musicplayer_tune_windows() };

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
