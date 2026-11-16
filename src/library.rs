//! Catálogo expuesto a QML como singleton `Library`.
//!
//! Cada sección se publica como JSON (`[{ titulo, items: [...] }]`) que la interfaz
//! convierte en sus zonas. Sin sesión de usuario no hay biblioteca personal: «Álbumes»
//! muestra solo las novedades y «Playlists» y «Me gusta» quedan vacías.

use std::{pin::Pin, thread};

use cxx_qt::Threading;
use cxx_qt_lib::QString;

use crate::ytm::{self, Zone};

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    #[auto_cxx_name]
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, inicio)]
        #[qproperty(QString, explorar)]
        #[qproperty(QString, playlists)]
        #[qproperty(QString, albumes)]
        #[qproperty(QString, busqueda)]
        #[qproperty(QString, megusta)]
        /// JSON de `ytm::Detail` del álbum, playlist o artista abierto; vacío si no hay.
        #[qproperty(QString, detalle)]
        #[qproperty(bool, detalle_loading)]
        #[qproperty(bool, loading)]
        #[qproperty(bool, searching)]
        #[qproperty(QString, error)]
        type Library = super::LibraryRust;

        /// Descarga las cuatro secciones; cada una aparece en cuanto llega.
        #[qinvokable]
        fn load(self: Pin<&mut Library>);

        /// Abre el detalle de un elemento del catálogo (JSON de `ytm::Item`).
        #[qinvokable]
        fn open_detail(self: Pin<&mut Library>, item: &QString);

        /// Cierra el detalle.
        #[qinvokable]
        fn close_detail(self: Pin<&mut Library>);

        /// Busca canciones, álbumes y playlists y deja el resultado en `busqueda`.
        #[qinvokable]
        fn search(self: Pin<&mut Library>, query: &QString);

        /// Sube la imagen `path` (ruta local o `file://`) como portada de la playlist
        /// `playlist_id` de la cuenta. Termina con `portada_lista`.
        #[qinvokable]
        fn set_playlist_cover(self: Pin<&mut Library>, playlist_id: &QString, path: &QString);

        /// Resultado de `set_playlist_cover`: `error` vacío si la portada cambió.
        #[qsignal]
        fn portada_lista(self: Pin<&mut Library>, playlist_id: QString, error: QString);

        /// Guarda en la playlist propia `playlist_id` (de título `titulo`) una canción, o todas
        /// las de un álbum o playlist (`item`: JSON de `ytm::Item` o de `ytm::Track`).
        /// Termina con `guardado`.
        #[qinvokable]
        fn add_to_playlist(self: Pin<&mut Library>, playlist_id: &QString, titulo: &QString, item: &QString);

        /// Resultado de `add_to_playlist`: el aviso para el usuario y si fue un error.
        #[qsignal]
        fn guardado(self: Pin<&mut Library>, mensaje: QString, error: bool);

        /// Da (`gusta` verdadero) o quita «Me gusta» a la canción `video_id` (de título `titulo`)
        /// en la cuenta y vuelve a pedir la sección «Me gusta». Termina con `gustado`.
        #[qinvokable]
        fn like(self: Pin<&mut Library>, video_id: &QString, titulo: &QString, gusta: bool);

        /// Resultado de `like`: el aviso para el usuario, si fue un error, la canción y si ahora
        /// tiene (o tendría, si falló) «Me gusta».
        #[qsignal]
        fn gustado(self: Pin<&mut Library>, mensaje: QString, error: bool, video_id: QString, gusta: bool);
    }

    impl cxx_qt::Threading for Library {}
}

#[derive(Default)]
pub struct LibraryRust {
    inicio: QString,
    explorar: QString,
    playlists: QString,
    albumes: QString,
    busqueda: QString,
    loading: bool,
    searching: bool,
    error: QString,

    /// Descarta los resultados de búsquedas anteriores a la última.
    search_request: u64,
    /// Cambia con cada carga; descarta resultados de cargas anteriores (p. ej. sin sesión).
    load_generation: u64,
    detalle: QString,
    detalle_loading: bool,
    megusta: QString,
    /// Descarta detalles que llegan después de abrir otro.
    detail_request: u64,
}

/// Copia en disco de cada sección para mostrar algo al instante al abrir la app.
/// Las de la cuenta se guardan aparte y se borran al cerrar sesión.
pub mod cache {
    use std::{fs, path::PathBuf};

    fn dir() -> Option<PathBuf> {
        dirs::cache_dir().map(|dir| dir.join("musicplayer"))
    }

    fn path(section: &str, account: bool) -> Option<PathBuf> {
        let scope = if account { "cuenta" } else { "anonimo" };
        dir().map(|dir| dir.join(format!("{scope}-{section}.json")))
    }

    pub fn read(section: &str, account: bool) -> Option<String> {
        fs::read_to_string(path(section, account)?).ok().filter(|text| !text.is_empty())
    }

    pub fn write(section: &str, account: bool, json: &str) {
        let Some(path) = path(section, account) else { return };
        if let Some(dir) = path.parent() {
            let _ = fs::create_dir_all(dir);
        }
        let _ = fs::write(path, json);
    }

    /// Borra las copias con datos de la cuenta.
    pub fn forget_account() {
        let Some(dir) = dir() else { return };
        let Ok(entries) = fs::read_dir(dir) else { return };
        for entry in entries.flatten() {
            if entry.file_name().to_string_lossy().starts_with("cuenta-") {
                let _ = fs::remove_file(entry.path());
            }
        }
    }
}

/// Biblioteca de la cuenta; si falla (sesión caducada) se sigue con lo público.
fn personal(result: ytm::Result<Vec<Zone>>) -> Vec<Zone> {
    result.unwrap_or_else(|error| {
        eprintln!("biblioteca personal: {error}");
        Vec::new()
    })
}

fn signed_in() -> bool {
    crate::account::with_session(|_| ()).is_some()
}

type Setter = fn(Pin<&mut qobject::Library>, QString);

/// Elementos por zona que se envían a la interfaz; las páginas traen cientos.
const ZONE_LIMIT: usize = 60;

fn to_json(zones: &[Zone]) -> String {
    let trimmed: Vec<Zone> = zones
        .iter()
        .map(|zone| Zone {
            titulo: zone.titulo.clone(),
            items: zone.items.iter().take(ZONE_LIMIT).cloned().collect(),
        })
        .collect();
    serde_json::to_string(&trimmed).unwrap_or_default()
}

impl qobject::Library {
    fn load(mut self: Pin<&mut Self>) {
        let generation = {
            use cxx_qt::CxxQtType;
            let generation = self.load_generation + 1;
            self.as_mut().rust_mut().load_generation = generation;
            generation
        };
        self.as_mut().set_loading(true);
        self.as_mut().set_error(QString::default());

        let sections: [(&str, fn() -> ytm::Result<Vec<Zone>>, Setter); 5] = [
            ("inicio", || ytm::browse("FEmusic_home"), |library, json| library.set_inicio(json)),
            ("explorar", || ytm::browse("FEmusic_explore"), |library, json| library.set_explorar(json)),
            (
                "albumes",
                || {
                    // Con sesión, primero los álbumes guardados; después las novedades.
                    let mut zones = if signed_in() { personal(ytm::library_albums()) } else { Vec::new() };
                    // La página de novedades es una sola cuadrícula sin título.
                    let mut news = ytm::browse("FEmusic_new_releases_albums")?;
                    for zone in &mut news {
                        zone.titulo = "Novedades".to_owned();
                    }
                    zones.extend(news);
                    Ok(zones)
                },
                |library, json| library.set_albumes(json),
            ),
            (
                "playlists",
                // Solo las de tu biblioteca de YouTube Music; sin sesión queda vacía. Si falla la
                // red se queda la copia guardada (y con ella sus categorías) en vez de vaciarse.
                || if signed_in() { ytm::library_playlists() } else { Ok(Vec::new()) },
                |library, json| library.set_playlists(json),
            ),
            // Secciones solo con sesión; sin ella quedan vacías y la interfaz lo explica.
            ("megusta", || Ok(if signed_in() { personal(ytm::liked_songs()) } else { Vec::new() }), |library, json| library.set_megusta(json)),
        ];

        // Lo guardado la última vez se muestra ya; la red lo sustituye al llegar.
        let account = signed_in();
        for (name, _, set) in &sections {
            if let Some(json) = cache::read(name, account) {
                set(self.as_mut(), QString::from(&json));
            }
        }

        let qt = self.qt_thread();
        thread::spawn(move || {
            for (name, fetch, set) in sections {
                let result = fetch();
                let json = result.as_ref().ok().map(|zones| to_json(zones));
                if let Some(json) = &json {
                    cache::write(name, account, json);
                }
                let _ = qt.queue(move |mut library| {
                    if library.load_generation != generation {
                        return;
                    }
                    match (json, result) {
                        (Some(json), _) => set(library.as_mut(), QString::from(&json)),
                        (None, Err(error)) => library.as_mut().set_error(QString::from(&error)),
                        (None, Ok(_)) => {}
                    }
                });
            }
            let _ = qt.queue(move |library| {
                if library.load_generation == generation {
                    library.set_loading(false);
                }
            });
        });
    }

    fn open_detail(mut self: Pin<&mut Self>, item: &QString) {
        use cxx_qt::CxxQtType;
        let Ok(item) = serde_json::from_str::<ytm::Item>(&item.to_string()) else { return };
        let request = self.detail_request + 1;
        self.as_mut().rust_mut().detail_request = request;
        // Se muestra al momento lo que ya se sabe; las canciones llegan después.
        let preview = ytm::Detail {
            title: item.title.clone(),
            subtitle: item.subtitle.clone(),
            thumb: item.thumb.clone(),
            kind: item.kind.clone(),
            playlist_id: item.playlist_id.clone(),
            ..ytm::Detail::default()
        };
        self.as_mut().set_detalle(QString::from(&serde_json::to_string(&preview).unwrap_or_default()));
        self.as_mut().set_detalle_loading(true);

        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = ytm::detail(&item);
            let _ = qt.queue(move |mut library| {
                if library.detail_request != request {
                    return;
                }
                match result {
                    Ok(detail) => library.as_mut().set_detalle(QString::from(&serde_json::to_string(&detail).unwrap_or_default())),
                    Err(error) => library.as_mut().set_error(QString::from(&error)),
                }
                library.set_detalle_loading(false);
            });
        });
    }

    fn close_detail(mut self: Pin<&mut Self>) {
        use cxx_qt::CxxQtType;
        self.as_mut().rust_mut().detail_request += 1;
        self.as_mut().set_detalle_loading(false);
        self.set_detalle(QString::default());
    }

    fn set_playlist_cover(self: Pin<&mut Self>, playlist_id: &QString, path: &QString) {
        let playlist_id = playlist_id.to_string();
        let path = path.to_string();
        let path = path.strip_prefix("file://").unwrap_or(&path).to_owned();
        let qt = self.qt_thread();
        thread::spawn(move || {
            // YouTube rechaza imágenes enormes; con 10 MB sobra para una portada.
            let result = match std::fs::read(&path) {
                Ok(bytes) if bytes.len() > 10 * 1024 * 1024 => Err("La imagen pesa demasiado (máximo 10 MB).".to_owned()),
                Ok(bytes) => ytm::set_playlist_cover(&playlist_id, &bytes),
                Err(error) => Err(format!("No se pudo leer la imagen: {error}")),
            };
            if let Err(error) = &result {
                eprintln!("portada de {playlist_id}: {error}");
            }
            let error = result.err().unwrap_or_default();
            let _ = qt.queue(move |library| {
                library.portada_lista(QString::from(&playlist_id), QString::from(&error));
            });
        });
    }

    fn add_to_playlist(self: Pin<&mut Self>, playlist_id: &QString, titulo: &QString, item: &QString) {
        let playlist_id = playlist_id.to_string();
        let titulo = titulo.to_string();
        let Ok(value) = serde_json::from_str::<serde_json::Value>(&item.to_string()) else { return };
        let field = |key: &str| value[key].as_str().unwrap_or_default().to_owned();
        let (video_id, source, name) = (field("videoId"), field("playlistId"), field("title"));
        // Una pista de la cola o una canción suelta llevan `videoId`; un álbum o playlist, solo
        // su lista. (Las canciones de «Me gusta» llevan también `playlistId`: manda la canción.)
        if video_id.is_empty() && source.is_empty() {
            return;
        }
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = ytm::add_to_playlist(&playlist_id, &video_id, if video_id.is_empty() { &source } else { "" });
            let (mensaje, error) = match result {
                Ok(true) => {
                    // La cola guardada de esa playlist ya no está completa.
                    crate::player::forget_queue(&playlist_id);
                    (format!("«{name}» guardada en «{titulo}»"), false)
                }
                Ok(false) => (format!("«{name}» ya estaba en «{titulo}»"), false),
                Err(error) => {
                    eprintln!("guardar en {playlist_id}: {error}");
                    (error, true)
                }
            };
            let _ = qt.queue(move |library| library.guardado(QString::from(&mensaje), error));
        });
    }

    fn like(self: Pin<&mut Self>, video_id: &QString, titulo: &QString, gusta: bool) {
        let video_id = video_id.to_string();
        let titulo = titulo.to_string();
        let generation = self.load_generation;
        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = if gusta { ytm::like(&video_id) } else { ytm::remove_like(&video_id) };
            if let Err(error) = &result {
                eprintln!("me gusta {video_id} ({gusta}): {error}");
            }
            let (mensaje, error) = match &result {
                Ok(()) if gusta => (format!("«{titulo}» está en tus «Me gusta»"), false),
                Ok(()) => (format!("«{titulo}» ya no está en tus «Me gusta»"), false),
                Err(error) => (error.clone(), true),
            };
            let id = video_id.clone();
            let _ = qt.queue(move |library| {
                library.gustado(QString::from(&mensaje), error, QString::from(&id), gusta)
            });
            if result.is_err() {
                return;
            }
            // La sección «Me gusta» ya no está completa: se pide otra vez.
            let Ok(zones) = ytm::liked_songs() else { return };
            let json = to_json(&zones);
            cache::write("megusta", true, &json);
            let _ = qt.queue(move |library| {
                if library.load_generation == generation {
                    library.set_megusta(QString::from(&json));
                }
            });
        });
    }

    fn search(mut self: Pin<&mut Self>, query: &QString) {
        let query = query.to_string().trim().to_owned();
        if query.is_empty() {
            return;
        }
        let request = self.search_request + 1;
        {
            use cxx_qt::CxxQtType;
            self.as_mut().rust_mut().search_request = request;
        }
        self.as_mut().set_searching(true);
        self.as_mut().set_error(QString::default());

        let qt = self.qt_thread();
        thread::spawn(move || {
            let result = ytm::search(&query);
            let _ = qt.queue(move |mut library| {
                if library.search_request != request {
                    return;
                }
                match result {
                    Ok(zones) => library.as_mut().set_busqueda(QString::from(&to_json(&zones))),
                    Err(error) => library.as_mut().set_error(QString::from(&error)),
                }
                library.set_searching(false);
            });
        });
    }
}
