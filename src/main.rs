mod account;
mod audio;
mod daemon;
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
            let tracks = if what == "queue" { ytm::queue(argument, "") } else { ytm::queue("", argument) };
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
                println!("{id}: {} ms {}", start.elapsed().as_millis(), if result.is_ok() { "ok" } else { "ERROR" });
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
                            if let Err(error) = mpv.load_stream(&url) {
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
            let artist = args.get(at + 3).map(String::as_str).unwrap_or_default();
            match lyrics::fetch(argument, artist, 0.0) {
                Some(lines) => {
                    for line in lines.iter().take(6) {
                        println!("[{:.2}] {}", line.t, line.text);
                    }
                    println!("{} líneas", lines.len());
                }
                None => println!("sin letra sincronizada"),
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

extern "C" {
    /// `src/window.cpp`: libera los recursos gráficos de las ventanas minimizadas u ocultas.
    fn musicplayer_tune_windows();
    /// `src/window.cpp`: no usar el proxy automático del sistema (WPAD) en Qt.
    fn musicplayer_configure_network();
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if probe(&args) {
        return;
    }

    cxx_qt::init_crate!(musicplayer);
    cxx_qt::init_qml_module!("app.musicplayer");

    let mut app = QGuiApplication::new();
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
