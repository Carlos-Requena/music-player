# Guía para colaboradores y agentes

Léelo antes de tocar el código. La guía para usuarios está en [README.md](README.md) y el
detalle técnico en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## El proyecto en una frase

Cliente de YouTube Music para macOS y Linux: interfaz **Qt 6 / QML**, núcleo **Rust**
unido a QML con **cxx-qt 0.10**, audio con **mpv** (proceso aparte, por IPC) y URLs de audio
con **yt-dlp**. Prioridades del propietario, en este orden: **consumo bajo de memoria**,
**respuesta instantánea**, **personalización total** (vistas, disposición, skins) y
**estética cuidada**.

## Idioma

Todo en **español**: textos de la interfaz, comentarios, documentación y mensajes de commit.
Los identificadores de código siguen el idioma del archivo (`vista_inicio`, `play_item`).

## Mapa del código

```
src/
  main.rs       Arranque de Qt y la sonda de terminal (--probe).
  account.rs    Singleton QML `Account`: importa la sesión del navegador (cookies de
                youtube.com vía yt-dlp) y firma las peticiones (SAPISIDHASH).
  ytm.rs        Cliente InnerTube de YouTube Music, sin sesión: secciones, búsqueda, colas.
  stream.rs     Vía rápida: API `/player` de YouTube con el cliente de visionOS (~0,3 s).
  resolver.rs   URL de audio de cada pista (vía rápida → yt-dlp residente → yt-dlp), con
                caché y precarga.
  audio.rs      Proceso mpv controlado por su socket IPC JSON.
  lyrics.rs     Letra sincronizada de LRCLIB.
  player.rs     Singleton QML `Player`: cola, estado de reproducción, letra.
  library.rs    Singleton QML `Library`: secciones, búsqueda y detalle abierto (JSON).
  daemon.rs     yt-dlp residente (`ytdlp_daemon.py`): resuelve sin arrancar Python cada vez.
  plugins.rs    Singleton QML `Plugins` y reparto de eventos a Discord y Last.fm
                (`plugins/discord.rs`, `plugins/lastfm.rs`). Los controles del sistema
                (souvlaki) viven en `player.rs` porque en macOS van en el hilo principal.
  window.cpp    C++: libera los recursos gráficos de las ventanas ocultas.
  settings.rs   Singleton QML `AppSettings`: estilo de ventana, vista de cada sección, skin y
                opciones de disposición (mapa clave → valor genérico, `opcion`/`setOpcion`).
skins/          Skins incluidas (JSON, se compilan dentro del binario con `include_str!`).
qml/
  Main.qml          Ventana: escenario, navegación, panel, barra, opciones.
  Theme.qml         Singleton con los tokens visuales: lee los colores de la skin activa y las
                    opciones que afectan al aspecto (`Theme.blur`, `Theme.ambient`).
  Catalog.qml       Singleton que convierte el JSON de Library/Player en objetos.
  SectionView.qml   Elige la vista (Muro, Lomos, Cubeta) de una sección.
  MuroView.qml, LomosView.qml, CubetaView.qml   Las tres vistas.
  NowPlayingPanel.qml, LyricsView.qml, PlayerBar.qml   Reproducción.
  DetailView.qml    Detalle de álbum, playlist o artista (canciones, Reproducir, Aleatorio).
  InspectView.qml   Modo inspeccionar: caja 3D que se gira, se abre y suelta el disco.
  MiniPlayer.qml    Ventana pequeña siempre encima; la grande se oculta mientras tanto.
  Glass.qml, Ambient.qml, TintProbe.qml          Vidrio, modo ambiente y color dominante.
  Cover.qml, Icon.qml, IconButton.qml, PillButton.qml, Slider.qml, SearchField.qml, TopNav.qml,
  ViewSwitcher.qml, SettingsSheet.qml            Piezas reutilizables.
build.rs        Registra los archivos QML y los puentes Rust en el módulo `app.musicplayer`.
```

## Comandos

```bash
cargo build            # depuración
cargo build --release  # para medir memoria y tiempos: mide siempre en release
cargo run --release
```

### Probar sin abrir la ventana: `--probe`

```bash
./target/release/musicplayer --probe home            # inicio
./target/release/musicplayer --probe explore
./target/release/musicplayer --probe albums          # novedades
./target/release/musicplayer --probe playlists       # playlists por estado de ánimo
./target/release/musicplayer --probe search "texto"
./target/release/musicplayer --probe queue VIDEO_ID  # radio de una canción
./target/release/musicplayer --probe album PLAYLIST_ID
./target/release/musicplayer --probe lyrics "título" "artista"
MUSICPLAYER_SILENT=1 ./target/release/musicplayer --probe play VIDEO_ID   # mide el arranque
```

### Capturas y pruebas de la interfaz

`Main.qml` acepta argumentos de depuración; con `--shot` guarda una captura de la ventana,
escribe una línea `estado: …` con el estado del reproductor y sale.

```bash
MUSICPLAYER_SILENT=1 ./target/release/musicplayer \
  --shot /tmp/captura.png --delay 20000 \
  --section albumes --index 5 \
  --autoplay --autoplay-delay 6000 --then-next 15000
```

| Argumento | Efecto |
|---|---|
| `--shot ruta.png` | Captura la ventana y sale |
| `--delay ms` | Espera antes de capturar (por defecto 1500) |
| `--section id` | `inicio`, `explorar`, `playlists`, `albumes` o `buscar` |
| `--index n` | Lleva Lomos o Cubeta al elemento `n` (con `--autoplay`) |
| `--search texto` | Busca al arrancar |
| `--settings` | Abre las opciones |
| `--settings-end` | Abre las opciones desplazadas hasta el final |
| `--minimize ms` | Minimiza la ventana tras ese tiempo; con `--hide` la oculta y con `--mini` abre el mini reproductor (la captura toma entonces el mini) |
| `--no-panel` | Arranca con el panel derecho cerrado |
| `--autoplay` | Reproduce el elemento enfocado |
| `--autoplay-delay ms` | Espera antes de reproducir (deja tiempo a la precarga) |
| `--then-next ms` | Pasa a la pista siguiente tras ese tiempo |
| `--open` | (con `--autoplay`) abre el detalle del elemento enfocado en vez de reproducirlo |
| `--shuffle` | (con `--open`) pulsa «Aleatorio» a los 5 s |
| `--inspect [flip\|open\|disc]` | (con `--autoplay`) inspecciona el elemento y deja la caja girada, abierta o con el disco fuera |

- `MUSICPLAYER_SILENT=1` hace que mpv reproduzca sin sonido (`--ao=null`). Úsalo siempre en
  pruebas automáticas.
- `HOME=/ruta/temporal` aísla las preferencias de las del usuario.
- **Sesión**: nunca importes las cookies del navegador del propietario en pruebas. Para probar
  el camino con sesión, escribe un `cookies.txt` falso (con un `SAPISID` inventado) en el
  `HOME` temporal: la app debe avisar de que la sesión caducó y seguir funcionando.
- `cargo test` cubre la lectura de cookies y la firma de la sesión, el protocolo de Discord
  (contra un socket simulado), la firma de Last.fm y sus reglas de scrobble.
- **Discord de extremo a extremo**: un servidor falso que escuche en
  `$XDG_RUNTIME_DIR/discord-ipc-0` (usa una ruta relativa corta: los sockets Unix admiten
  ~104 bytes) y `plugins.json` con `{"discord": true, "discord_id": "1234"}` en el `HOME`
  temporal.
- `--probe resolve id1,id2` mide la resolución con el yt-dlp residente.
- Sin ventana visible: `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software`.
- Al arrancar una pista el programa escribe en stderr `arranque de pista: N ms`.

### No castigues a YouTube

Cada prueba hace peticiones reales. Si se encadenan muchas, YouTube empieza a rechazar la IP
durante un rato («Requested format is not available», 403, «Sign in to confirm you're not a
bot»). Agrupa las pruebas, espera unos minutos si aparecen esos errores y no los tomes por
fallos del código sin comprobarlo con `yt-dlp` directamente.

## Convenciones

- **Rust**: lo lento (red, yt-dlp, mpv) va en un hilo y devuelve el resultado al hilo de Qt
  con `qt_thread().queue(...)`. Nunca bloquees el hilo de Qt.
- **Rust → QML**: datos estructurados como JSON en una propiedad `QString`; `Catalog.qml` lo
  convierte con `JSON.parse`. Es simple y basta para el volumen actual.
- **Respuestas obsoletas**: las peticiones llevan un contador (`request`, `load_token`,
  `search_request`) y se descartan si ya no son la última.
- **QML**: colores solo a través de `Theme`; un color nuevo que deba cambiar con la skin va
  como clave nueva en `colores` (con su valor por defecto en `Theme.pick`) y en las cuatro
  skins de `skins/`.
- **Opciones nuevas de disposición**: usa `AppSettings.opcion("clave")` (vacío = valor por
  defecto) y `setOpcion`; léelas con `void AppSettings.revision` delante para que el enlace se
  actualice, y añade la fila en la sección «Disposición» de `SettingsSheet.qml`. Botones con 44 px de área como mínimo, `Accessible.name` en los de solo icono, y
  foco por teclado visible.
- **Errores**: en la interfaz, mensajes cortos en español (`Player.error`, `Library.error`);
  el detalle técnico va a stderr.

## Trampas conocidas

- **Archivo QML nuevo** → regístralo en `build.rs` (`QML_FILES` o `QML_SINGLETONS`) o QML dirá
  que el tipo no existe.
- **Puente Rust nuevo** → añádelo a `.files([...])` en `build.rs` y como `mod` en `main.rs`.
- **Nombres en QML**: `#[auto_cxx_name]` convierte `snake_case` a `camelCase`
  (`play_item` → `Player.playItem`, `vista_inicio` → `AppSettings.vistaInicio`).
- **Invocables con `&self`** y métodos de la implementación no deben colarse dentro del bloque
  `extern "RustQt"`: el generador falla con «Unsupported verbatim input in ForeignItem».
- **`font.pixelSize`** es entero: `12.5` hace fallar la carga del componente entero.
- **No llames `palette`** a una propiedad propia: choca con la de `Item` y QML la ignora.
- **Rotaciones 3D en Qt**: un ángulo positivo en el eje Y aleja el lado **derecho** del eje.
- **Máscaras de MultiEffect**: sin `maskThresholdMin: 0.5` y `maskSpreadAtMin: 1` la máscara
  recorta en seco en vez de seguir el degradado.
- **mpv y las URLs de googlevideo**: las de yt-dlp dan 403 con el cliente HTTP de mpv y se
  cargan como `lavf://URL` (ffmpeg); las de la vía rápida se atascan con ffmpeg y se cargan tal
  cual. `resolver::run_ytdlp` deja el prefijo puesto según el origen.
- **Proxy del sistema**: Qt ignora el proxy de macOS (`window.cpp`); con WPAD roto cada
  descarga fallaba con «NSURLErrorDomain -1003». Se respeta `HTTPS_PROXY`/`HTTP_PROXY`.
- **La vía rápida necesita «visitor data»** (`stream.rs`); sin él YouTube responde
  `LOGIN_REQUIRED` («confirma que no eres un bot»).
- **yt-dlp sin sesión**: con los clientes por defecto YouTube pide verificación anti-bot en
  pistas de YouTube Music. Se usan `web_embedded,mweb` (`resolver::ytdlp_options`).
- **mpv solo avisa de la pausa cuando cambia**: al empezar una pista se aplica la última
  conocida (`mpv_paused`); si no, «sonando» se queda desfasado.
- **Minimizar no libera memoria gráfica en macOS**; ocultar la ventana sí (`window.cpp`).
- **yt-dlp reescribe el archivo de `--cookies`** al terminar. Nunca le pases el
  `cookies.txt` original: usa `account::cookies_copy`.
- **Cambiar un índice dentro del aviso de cambio** de la misma propiedad (`onCurrentItemChanged`)
  deja enlaces sin actualizar: aplázalo con `Qt.callLater`.
- **Rotaciones 3D grandes** (más de ~70°) acercan la pieza a la cámara y la agrandan: para
  abrir la caja se usa un pliegue plano (`Scale` en X), no una `Rotation`.
- **Apps gráficas en macOS** no heredan el `PATH` de la terminal: `audio::search_path` añade
  `/opt/homebrew/bin` y `/usr/local/bin`.

## Antes de dar algo por terminado

1. `cargo build --release` sin errores ni avisos.
2. Captura (`--shot`) de cada pantalla que hayas tocado, revisada a ojo.
3. Si tocaste reproducción: una prueba con `--autoplay` y `MUSICPLAYER_SILENT=1` que
   termine con `sonando true` y sin `error`.
4. Si tocaste algo que afecte a memoria o tiempos: mídelo en release y apúntalo en
   [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
