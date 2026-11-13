# Arquitectura

## Piezas y procesos

```
┌──────────────────── proceso musicplayer ─────────────────────┐
│  QML (Qt Quick, Metal/Vulkan)                                 │
│    Main.qml · vistas · panel · barra · opciones               │
│        │ propiedades y llamadas (cxx-qt)                      │
│  Rust                                                         │
│    Library ── ytm.rs ──────────── HTTPS → music.youtube.com   │
│    Player ─┬─ ytm.rs (colas)                                  │
│            ├─ resolver.rs ─ lanza ─→ yt-dlp (proceso corto)   │
│            ├─ lyrics.rs ───────── HTTPS → lrclib.net          │
│            └─ audio.rs ── socket IPC JSON ─┐                  │
│    AppSettings ── settings.json            │                  │
└────────────────────────────────────────────┼─────────────────┘
                                             ▼
                              proceso mpv (--idle, sin vídeo)
                              lee el audio con ffmpeg (lavf://)
```

- **Hilos.** El hilo de Qt solo pinta y responde. Red, yt-dlp y la lectura del socket de mpv
  van en hilos propios y devuelven resultados con `qt_thread().queue(...)`, que ejecuta el
  cierre en el hilo de Qt con acceso al objeto.
- **Datos hacia QML.** `Library` publica cada sección y la búsqueda como JSON
  (`[{ titulo, items: [{ title, subtitle, thumb, kind, videoId, browseId, playlistId }] }]`)
  y `Player` publica la cola y la letra igual. `Catalog.qml` hace `JSON.parse` una vez por
  cambio. Cada zona se limita a 60 elementos (`library::ZONE_LIMIT`).
- **InnerTube.** `ytm.rs` habla con la API interna de YouTube Music como el cliente web
  (`WEB_REMIX`): inicio, explorar, novedades, «Ánimo y géneros», búsqueda, colas (`next`),
  páginas de artista y, con sesión, la biblioteca (`FEmusic_liked_playlists`,
  `FEmusic_liked_albums`, `FEmusic_liked_videos`, `FEmusic_library_corpus_track_artists`,
  `VLLM`).

## Sesión

- `account.rs` lanza `yt-dlp --cookies-from-browser <navegador> --cookies <temporal>`, se queda
  solo con las cookies de `youtube.com`, las guarda en `cookies.txt` (permisos 600) y borra el
  temporal. Comprueba la sesión pidiendo el nombre de la cuenta (`account/account_menu`).
- Cada petición a InnerTube con sesión lleva `Cookie`, `X-Goog-AuthUser: 0`, `X-Origin` y
  `Authorization: SAPISIDHASH <segundos>_<sha1("<segundos> <SAPISID> https://music.youtube.com")>`.
- yt-dlp y mpv reciben una **copia** de las cookies (`account::cookies_copy`), porque yt-dlp
  reescribe el archivo al terminar.
- Al arrancar, `Account.verify` comprueba la sesión; si YouTube ya no la reconoce, la borra y
  avisa. Al iniciar o cerrar sesión se reinicia mpv (sus opciones de yt-dlp cambian) y se
  recarga la biblioteca.

## Navegación

- Elegir una **canción** la reproduce (con su radio, o dentro de «Me gusta» si viene de ahí).
- Elegir un **álbum, playlist o artista** abre `DetailView` (`Library.openDetail`): se muestra al
  instante lo conocido y las canciones llegan después. De un artista se usa la playlist de
  «todas sus canciones» y se añaden sus carruseles (álbumes, singles…).
- **Aleatorio** baraja la lista en Rust (`player::shuffle_tracks`) y la reproduce entera.
- **Inspeccionar** (`I`) muestra la caja en grande: giro de 180° para la contraportada con las
  canciones, pliegue de la tapa para ver el libreto y la bandeja, y el disco, que sale y gira
  mientras suena.

## Reproducción: de clic a sonido

1. La vista emite `activated(item)` y `Main.qml` llama a `Player.playItem(json)`.
2. **Canción:** se carga ya y su radio (cola) llega en paralelo. **Álbum o playlist:** se usa
   la cola en caché (`player::QUEUES`) o se pide a InnerTube y se carga la primera pista.
3. `Player::load` busca la URL de audio en `resolver`:
   - **Ya resuelta** → `mpv.load_stream(url)`: suena en unas décimas.
   - **No resuelta** → `resolver::resolve` en un hilo (yt-dlp, 3–4 s) y luego `load_stream`.
     Si otra petición ya la estaba resolviendo (una precarga), espera a esa en vez de lanzar
     otro yt-dlp.
4. **Plan B.** Si la URL directa falla (YouTube la rechaza o caducó), se olvida y mpv carga la
   página de YouTube con su propio gancho de yt-dlp (más lento, ~12 s, pero más tolerante). Si
   eso también falla, se reintenta una vez y después se muestra el error.
5. mpv avisa por IPC de `time-pos`, `duration`, `pause`, `playback-restart` y `end-file`;
   `audio.rs` lo traduce a `Event` y `Player::on_event` actualiza las propiedades. Al terminar
   una pista pasa a la siguiente.

### Arranque instantáneo

Dos piezas:

1. **Vía rápida** (`stream.rs`): en vez de yt-dlp, una petición a la API del reproductor de
   YouTube (`/youtubei/v1/player`) con el cliente de visionOS, que devuelve URLs de audio
   directas sin descifrado JavaScript ni tokens. Necesita un «visitor data» (identificador de
   visitante, de `/visitor_id`), que se pide una vez. Si falla (vídeo restringido, cambios de
   YouTube) se usa yt-dlp: primero el residente (`daemon.rs`) y si no, un proceso.
2. **Precarga** (`resolver.rs`): las URLs se guardan hasta 10 min antes de su `expire=` y se
   resuelven por adelantado:

| Disparador | Qué se resuelve | Función |
|---|---|---|
| El foco se detiene 250 ms en un elemento | Esa canción, o la primera pista del álbum o playlist (y su cola) | `Player.prefetchItem` → `resolver::hint` |
| El ratón pasa por una carátula (Muro, Lomos) | Igual | Igual |
| Empieza a sonar una pista | La siguiente de la cola | `Player::prefetch_next` → `resolver::prefetch` |
| Arranca la app | El proceso de mpv | `Player.warmUp` |

`resolver::hint` solo atiende la **última** petición, así que recorrer veinte carátulas no lanza
veinte resoluciones.

**Calidad**: la vía rápida elige Opus 160k (itag 251, lo máximo sin Premium), luego AAC 128k
(140). Con la opción «Premium · 256 kbps» y sesión iniciada, el orden se invierte: yt-dlp con
las cookies y sus clientes por defecto (que dan los formatos de 256 kbps a cuentas Premium);
si falla, la vía rápida. mpv informa del códec y la tasa real (`Player.calidad`).

### Medidas (macOS, Apple M4 Pro, compilación release)

| Situación | Desde el clic hasta oír audio |
|---|---|
| Al principio: gancho de yt-dlp de mpv | 8,2–9,5 s (y ~12 s si YouTube rechazaba la URL) |
| Con yt-dlp propio, sin precarga | ~4 s |
| **Vía rápida, sin precarga** | **~0,4–0,6 s** (resolver 175–360 ms + mpv ~0,2 s) |
| **Con precarga** o pasando a la siguiente | **64–254 ms** |
| Álbum sin precarga (incluye bajar su lista) | ~0,8 s |

## Memoria y arranque (macOS, ventana 1440×900 en pantalla Retina, release)

Medido con `footprint` (memoria física atribuida al proceso, la que muestra el Monitor de
Actividad):

| Caso | Memoria |
|---|---|
| Ventana Qt vacía y quieta (control, sin nuestro código) | 93 MB |
| Ventana Qt vacía con **cualquier** redibujado, de 1 a 30 por segundo (control) | 178–247 MB |
| La app, Inicio cargado, sin reproducir | 187 MB |
| La app reproduciendo, con panel de letra | 300–330 MB, estable en el tiempo |
| Proceso mpv en reposo / reproduciendo | 20 MB / ~75 MB |

- **Lo que más pesa no es nuestro código.** En cuanto una ventana de Qt Quick se redibuja de
  forma continua (la barra de progreso y la letra lo hacen mientras suena), el controlador
  gráfico de macOS reserva ~100 MB para sus fotogramas. Lo hace una ventana vacía con un
  cuadrado de 2 px girando. Con OpenGL en vez de Metal es el doble.
- Lo que añade la app sobre ese mínimo (~130 MB reproduciendo): carátulas, capas de la letra con
  desenfoque, el vidrio de la barra, el motor QML y el JSON del catálogo.
- Medidas aplicadas: capas de la letra a media resolución; el Muro solo descarga las carátulas
  de las filas visibles o cercanas; mpv sin sus scripts de interfaz y con caché de 16 MB
  (44 → 20 MB en reposo).
- **Arranque**: ventana lista en ~0,75 s. Cada sección se guarda en disco
  (`<caché>/musicplayer/<anonimo|cuenta>-<sección>.json`) y se muestra al abrir mientras llega
  la nueva (~0,5 s): a los 300 ms ya se ven contenido y carátulas. Las copias de la cuenta se
  borran al cerrar sesión.
- **Mini reproductor**: oculta la ventana grande y `window.cpp` libera su grafo de escena y
  su memoria gráfica (medido: 213 → 148 MB). Minimizar no la libera en macOS: Qt conserva
  los búferes de las ventanas minimizadas.
- **yt-dlp residente** (`daemon.rs` + `ytdlp_daemon.py`): un intérprete de yt-dlp que se queda
  cargado resuelve en 2,2–2,5 s en vez de 3,5–4,2 s. Ocupa ~120 MB (lo mismo que un yt-dlp
  normal mientras trabaja) y se cierra solo tras un minuto sin uso; desactivable en Opciones.
  Si yt-dlp no es un script de Python (binario autónomo), se usa un proceso por petición.
- Para comparar: Pear Desktop o una pestaña de YouTube Music en Chrome suelen pasar de
  500 MB a 1 GB sumando sus procesos (estimación, no medida en esta máquina).

## Personalización

- **Skins**: `settings.rs` junta las incluidas (`skins/*.json`, dentro del binario) y las de
  `<config>/musicplayer/skins/*.json` (una con el mismo id sustituye a la incluida; las mal
  formadas se ignoran con un aviso en stderr). Publica la lista (`AppSettings.skins`) y el JSON
  de la activa (`AppSettings.skinData`); `Theme.qml` lo lee con valores por defecto para lo que
  falte, así que cambiar de skin no necesita reiniciar.
- **Opciones de disposición**: un mapa genérico clave → valor en `settings.json`
  (`opciones`). Hoy: `panel` (izquierda/derecha), `ambiente`, `desenfoque`, `caratulas`. Es la
  base del futuro editor de disposición.
- **Vistas por sección**: `AppSettings.vista(seccion)` y `setVista`; `SectionView.qml` carga
  la que toque. Añadir una vista: un `XxxView.qml` con `zonas`, `currentItem` y
  `signal activated(var item)`, registrarlo en `build.rs`, en `SectionView.qml` y en
  `Catalog.views`.
- **Estilo de ventana**: `AppSettings.ventana` (`vidrio` o `escenario`) cambia la disposición en
  `Main.qml`; con el panel a la izquierda todo el escenario se desplaza con `stageX`.

## Plugins

- `Player` llama a `plugins::emit(Event)` al empezar una pista (`Track`), al pausar o reanudar
  (`Playing`), con cada posición (`Position`) y al terminar la cola (`Stopped`). Un hilo
  (`plugins::worker`) reparte a Discord y Last.fm, que hablan con la red; sus estados vuelven
  a la interfaz como `Plugins.discordStatus` y `Plugins.lastfmStatus`.
- **Discord**: socket IPC local, mensajes `[opcode u32 LE][longitud u32 LE][JSON]`; saludo
  (`opcode 0`, `client_id`) y `SET_ACTIVITY` con `type: 2` («Escuchando»), inicio y fin para la
  barra de tiempo y la carátula como imagen.
- **Last.fm**: API 2.0 firmada (md5 de los parámetros ordenados + secreto). Autorización en dos
  pasos (`auth.getToken` → web → `auth.getSession`). `track.updateNowPlaying` al empezar y
  `track.scrobble` al acumular la mitad de la pista o 4 minutos de escucha real (los saltos no
  cuentan).
- **Controles del sistema**: souvlaki (MPNowPlayingInfoCenter y MPRemoteCommandCenter en macOS,
  MPRIS por D-Bus en Linux). Sus órdenes llegan a `Player::on_media_command`.
