---
area: resolucion
titulo: Resolución del audio y arranque instantáneo
resumen: Obtiene la URL de audio de cada pista (vía rápida, yt-dlp residente o yt-dlp) con caché y precarga, para que suene en décimas de segundo.
archivos: [src/stream.rs, src/resolver.rs, src/daemon.rs, src/ytdlp_daemon.py]
opciones: [calidad, ytdlp]
adr: [ADR-03, ADR-05, ADR-08, ADR-24, ADR-25]
---

# Resolución del audio y arranque instantáneo

La pieza que hace que una pista suene al hacer clic. Lo que pasa después (mpv, la cola) es de
[reproduccion](reproduccion.md).

## Qué hace

- Da la URL de audio de un `videoId` en ~0,3 s (vía rápida) o 2–4 s (yt-dlp).
- La **precarga** resuelve por adelantado lo que probablemente se va a pedir, y al hacer clic la
  URL ya está.
- **Calidad** (Opciones › Reproducción): «Alta» da Opus 160k (itag 251) y, si no, AAC 128k (140).
  «Premium · 256 kbps», con sesión, invierte el orden: yt-dlp con las cookies primero.

## Reglas y decisiones

- **Vía rápida primero, yt-dlp de respaldo**
  ([ADR-03](../decisions/ADR-03-via-rapida-y-yt-dlp-de-respaldo.md)): `/player` con el cliente de
  visionOS, que da URLs directas sin descifrado ni tokens. **Necesita «visitor data»**; sin él,
  `LOGIN_REQUIRED`.
- **Pistas reservadas a cuentas** (`UNPLAYABLE`, muchas «Art Tracks»): sin sesión se avisa al
  momento (`NEEDS_SESSION`, ~0,3 s) en vez de probar yt-dlp. Con sesión van directas a yt-dlp con
  el cliente `web_music` y las cookies, y se recuerdan.
- **Ediciones de otra región:** con la sesión, YouTube Music puede dar la edición de otro país
  de una canción (la japonesa de un single de HOYO-MiX, por ejemplo). Solo la da yt-dlp con las
  cookies (Premium); la vía rápida, sin la cuenta, la ve no disponible. Si una pista no se resuelve
  (calidad normal, o yt-dlp roto), `alternative` busca la canción **sin
  la cuenta** (`ytm::search_songs_anonymous`) y suena el primer resultado con un título
  compatible y, o el mismo artista principal y la duración a ±3 s, o (artista traducido,
  «物語シリーズ» y «MONOGATARI Series») la duración a ±1 s. La cola apunta a esa edición
  (`Player::replace_video_id`) y se recuerda. Lo que la vía rápida y yt-dlp dan por no
  disponible se apunta (`UNAVAILABLE`): no se reintenta ni se vuelve a pedir, y como la precarga
  ya lo averigua, el clic va directo a la otra edición.
- **Premium se aparca si yt-dlp falla:** si la vía Premium falla con una pista que la vía rápida
  sí da y yt-dlp no dice «no disponible», el fallo es de yt-dlp (p. ej. una versión que ya no
  resuelve los retos de YouTube): durante 10 min (`PREMIUM_PAUSE`) se usa la vía rápida y después
  se vuelve a probar sola. Cambiar la calidad en Opciones anula la pausa. Si yt-dlp dice «no
  disponible» (la cuenta no ve esa pista), solo esa pista pasa a la vía rápida (`FAST_ONLY`).
- **Clientes de yt-dlp:** sin sesión, `web_embedded,mweb` (los de por defecto piden verificación
  anti-bot); con sesión, `web_music` con `player_skip=webpage,configs`. Se pueden forzar con
  `MUSICPLAYER_YTDLP_CLIENTS`.
- **Prefijo según el origen:** las URLs de yt-dlp se cargan como `lavf://URL` y las de la vía
  rápida tal cual ([TRAMPAS](../TRAMPAS.md#youtube-yt-dlp-y-mpv)).
- **Precarga solo de la última petición** (`hint`): recorrer veinte carátulas no lanza veinte
  resoluciones ([ADR-05](../decisions/ADR-05-precarga-de-urls.md)). Lo mismo con las listas de
  álbumes y playlists (`hint_list`, en `player.rs`), que además se guardan como mucho 24 y no se
  descargan dos veces a la vez.
- **El clic no espera a las precargas:** `resolve` (lo que pide el usuario) no cuenta en el límite
  de dos a la vez (`MAX_WORKERS`) y reintenta una vez si falla; una precarga no reintenta (si
  YouTube está rechazando, insistir lo empeora).
- **yt-dlp residente** ([ADR-08](../decisions/ADR-08-yt-dlp-residente.md)), desactivable (`ytdlp`).

## Cómo funciona

`resolve` (en un hilo): caché válida → vía rápida → yt-dlp residente → yt-dlp en un proceso. Si
otra petición ya está resolviendo la misma pista (una precarga), espera a esa. Las URLs se guardan
hasta 10 min antes de su `expire=`.

| Disparador | Qué se resuelve | Dónde |
|---|---|---|
| El foco o el puntero se detienen 250 ms en un elemento (Muro, Lomos; si el puntero sale antes, nada) | Esa canción, o la primera pista del álbum o playlist (y su cola) | `Main.hint` → `Player.prefetchItem` → `hint` o `hint_list` |
| Empieza a sonar una pista | Las tres siguientes de la cola (con repetición, dando la vuelta) | `Player::prefetch_next` → `prefetch` |
| Se abre un álbum o playlist | Sus seis primeras canciones | `DetailView` → `Player.prefetchTracks` |
| Se carga una sección | Las cuatro primeras canciones sueltas de su primera fila | `SectionView` → `Player.prefetchTracks` |
| Se añade algo a la lista temporal | Esa canción | `Player.addToTemporal` |

El residente (`ytdlp_daemon.py`) se lanza con el intérprete de la línea `#!` del `yt-dlp`
instalado; si yt-dlp es un binario autónomo, `daemon::resolve` devuelve `None` y se usa un proceso
por petición. Se cierra solo tras un minuto sin uso. En Windows, el `yt-dlp.exe` es autónomo y el
residente usa el Python embebido del instalador: el primer `python\python.exe` con `yt-dlp.zip` al
lado en las carpetas de `search_path` ([ADR-25](../decisions/ADR-25-yt-dlp-residente-en-windows.md)).

## Medidas

| Situación | Desde el clic hasta oír audio | Fecha y máquina |
|---|---|---|
| Vía rápida, sin precarga | ~0,4–0,6 s (resolver 175–360 ms + mpv ~0,2 s) | 2026-11-13, M4 Pro, release |
| Con precarga, o pasando a la siguiente | 64–254 ms | 2026-11-13, M4 Pro, release |
| Álbum sin precarga (incluye bajar su lista) | ~0,8 s | 2026-11-13, M4 Pro, release |
| yt-dlp residente / en un proceso | 2,2–2,5 s / 3,5–4,2 s | 2026-11-13, M4 Pro, release |
| yt-dlp con sesión (`web_music`) | ~1,7–2,9 s | 2026-11-14, M4 Pro, release |
| Memoria del residente | ~120 MB mientras vive | 2026-11-13, M4 Pro |
| Windows: vía rápida | ~0,1 s (la primera, 0,3–0,7 s) | 2026-11-22, PC del propietario, Windows 11, release |
| Windows: residente / `yt-dlp.exe` en un proceso (sin sesión) | 2,4–2,5 s (la primera, 4,8 s) / 7,2–7,8 s | 2026-11-22, PC del propietario, Windows 11, release |
| Windows: memoria del residente | ~77 MB en uso, 60 MB privados | 2026-11-22, PC del propietario |

La vía rápida sirve unas 9 de cada 10 pistas.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/stream.rs` | Vía rápida: `/player` con el cliente de visionOS y «visitor data» |
| `src/resolver.rs` | Orden de las vías, caché, precarga, clientes y opciones de yt-dlp |
| `src/daemon.rs` | yt-dlp residente: lanzarlo, pedirle, cerrarlo |
| `src/ytdlp_daemon.py` | El servidor de yt-dlp (Python) |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Resolver una pista | [`resolve`](../../src/resolver.rs) |
| Precarga de la última petición | [`hint`](../../src/resolver.rs) |
| Precarga de varias | [`prefetch`](../../src/resolver.rs) |
| Orden vía rápida → yt-dlp | [`fast_or_ytdlp`](../../src/resolver.rs) |
| Clientes de yt-dlp | [`ytdlp_clients`](../../src/resolver.rs) |
| Prefijo `lavf://` | [`run_ytdlp`](../../src/resolver.rs) |
| Pistas que exigen cuenta | [`NEEDS_SESSION`](../../src/resolver.rs) |
| Otra edición de una pista no disponible | [`alternative`](../../src/resolver.rs), [`same_song`](../../src/resolver.rs) |
| Premium aparcado tras un fallo de yt-dlp | [`premium_paused`](../../src/resolver.rs) |
| Mejor formato de audio | [`best_audio`](../../src/stream.rs) |
| Visitor data | [`visitor_data`](../../src/stream.rs) |

## Dependencias

- **[sesion](sesion.md)** (`account::cookies_copy`, `account::with_session`): cookies para yt-dlp
  y la vía con cuenta.
- **[reproduccion](reproduccion.md)** (`audio::which`): encontrar `yt-dlp` en el `PATH` ampliado.
- **[catalogo](catalogo.md)** (`ytm::http`): el cliente HTTP común para la vía rápida.
- **La usan:** [reproduccion](reproduccion.md) (todas las cargas y precargas),
  [personalizacion](personalizacion.md) (las opciones `calidad` y `ytdlp`).

## Estado actual

- **Última verificación:** 2026-11-24, otra edición para las pistas de otra región, con la sesión del propietario (macOS); 2026-11-22, residente en Windows 11 con Python embebido, `--probe resolve` sin sesión ([historial](../history/verificacion/resolucion.md)).
- **Pruebas:** `mod tests` de `src/stream.rs` (elección del mejor audio) y de `src/resolver.rs`
  (misma canción en otra edición, artista principal, «no disponible»). El resto, con
  `--probe fast`, `--probe resolve` (solo el residente) y `--probe playable` ([verificar-reproduccion](../runbooks/verificar-reproduccion.md)).
- **Sin verificar:** Premium 256 kbps con una cuenta Premium real en Linux; en Windows, el
  residente con sesión (`web_music` y cookies), desde la app instalada y con la ventana abierta, y
  las ediciones de otra región y la pausa de Premium.
- **Historial:** [docs/history/verificacion/resolucion.md](../history/verificacion/resolucion.md).
