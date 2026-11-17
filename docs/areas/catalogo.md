---
area: catalogo
titulo: Catálogo de YouTube Music
resumen: Secciones (Inicio, Explorar, Álbumes, Playlists, Me gusta), búsqueda, detalle abierto y categorías de playlists, pedidos a InnerTube y publicados como JSON.
archivos: [src/ytm.rs, src/library.rs, qml/Catalog.qml, qml/CategoryBar.qml]
opciones: [categoria, categorias]
adr: [ADR-04, ADR-06, ADR-09]
---

# Catálogo de YouTube Music

Todo lo que se ve para elegir: las secciones de la navegación superior, los resultados de
búsqueda y el detalle de un álbum, playlist o artista. Cómo se pinta cada sección es cosa de
[vistas](vistas.md); el detalle abierto, de [detalle](detalle.md).

## Qué hace

- **Sin sesión:** Inicio, Explorar, Álbumes (novedades), «Ánimo y géneros» y búsqueda de
  canciones, álbumes, playlists y artistas.
- **Con sesión:** además, la biblioteca de la cuenta: Playlists (`FEmusic_liked_playlists`),
  álbumes guardados (`FEmusic_liked_albums`) y Me gusta (`VLLM`). Sin sesión, Playlists y Me gusta
  quedan vacías.
- **Categorías de playlists:** pestañas propias sobre la sección Playlists («Todas», las del
  usuario y «+»), con clic derecho para renombrar o borrar, y ↑/↓ o RePág/AvPág desde la
  estantería. Son locales (opción `categorias`, JSON) y la elegida se recuerda (`categoria`).
- **Guardar en una playlist** (`Library.addToPlaylist`) y **portada propia** de una playlist
  (`Library.setPlaylistCover`).
- **Dar o quitar «Me gusta» a una canción en la cuenta** (`Library.like(id, titulo, gusta)` →
  `ytm::like` o `ytm::remove_like`; termina con `gustado(mensaje, error, videoId, gusta)`); después
  vuelve a pedir la sección Me gusta. Lo usan el corazón de la barra ([reproduccion](reproduccion.md))
  y la mascota al pincharla ([mascotas](mascotas.md)). Quitarlo deja la canción sin valorar, no en
  «No me gusta».

## Reglas y decisiones

- **InnerTube como el cliente web (`WEB_REMIX`)**, recorriendo las respuestas buscando los
  *renderers* por nombre en vez de fijar rutas completas: cambian a menudo.
- **JSON hacia QML** ([ADR-04](../decisions/ADR-04-json-hacia-qml.md)): cada sección es
  `[{ titulo, items: [{ title, subtitle, thumb, kind, videoId, browseId, playlistId }] }]` y
  `Catalog.qml` hace `JSON.parse` una vez por cambio. Cada zona, hasta 60 elementos
  (`ZONE_LIMIT`).
- **Canciones de un álbum o playlist por su página `VL<id>`**, no por la cola `next`
  ([ADR-06](../decisions/ADR-06-canciones-por-la-pagina-de-la-lista.md)).
- **Cada sección se guarda en disco** y se muestra al abrir mientras llega la nueva
  ([ADR-09](../decisions/ADR-09-cache-de-secciones-en-disco.md)); las copias de la cuenta se
  borran al cerrar sesión.
- **Guardar sin duplicar:** `browse/edit_playlist` con `ACTION_ADD_VIDEO` y
  `DEDUPE_OPTION_CHECK` (si ya estaba, YouTube responde con un diálogo y no la duplica), o
  `ACTION_ADD_PLAYLIST` para una lista entera; después se olvida la cola guardada de esa lista.
- **Un solo cliente HTTP para toda la app** (`ytm::http`): guarda unos segundos las conexiones y
  las reutiliza (catálogo, vía rápida, letra, historial, Last.fm). `ureq::get` y `ureq::post`
  crean uno de un solo uso y cada petición pagaba una conexión TLS nueva: no se usan.
- **La búsqueda pide sus cuatro listas a la vez** (artistas, canciones, álbumes y playlists): tarda
  lo que la más lenta.
- **Lo que no cambia no se reconstruye en QML:** `Catalog.categorias` sale del texto guardado
  (`categoriasJson`), no de `AppSettings.revision`, para que tocar otra opción no rehaga
  Playlists. Lomos y Cubeta juntan las zonas con `Catalog.allItems`.

## Cómo funciona

- `Library.load` pide las secciones en un hilo; cada respuesta vuelve con
  `qt_thread().queue(...)` y se descarta si su `load_token` ya no es el último. La búsqueda
  igual con `search_request`.
- Con sesión, cada petición se firma con [sesion](sesion.md) (`account::with_session`).
- Caché en `<caché>/musicplayer/<anonimo|cuenta>-<sección>.json`.

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Búsqueda («Vetusta Morla», `--probe search`, cuatro listas a la vez) | 0,50–0,57 s | 2026-11-17, M4 Pro, release |
| Canciones de una playlist de 500 pistas (`playlist_tracks`) | ~3 s | 2026-11-14, M4 Pro, release |
| Sección visible al abrir, desde la caché | ~300 ms con carátulas | 2026-11-14, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `src/ytm.rs` | Cliente InnerTube: secciones, búsqueda, detalle, colas, biblioteca, guardar |
| `src/library.rs` | Singleton `Library`: publica secciones, búsqueda y detalle; caché en disco |
| `qml/Catalog.qml` | Singleton: JSON → objetos, lista de secciones, categorías, retraso de la letra |
| `qml/CategoryBar.qml` | Pestañas de categorías de Playlists |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Recorrer la respuesta buscando renderers | [`find_all`](../../src/ytm.rs) |
| Una sección por `browseId` | [`browse`](../../src/ytm.rs) |
| Canciones de un álbum o playlist | [`playlist_tracks`](../../src/ytm.rs) |
| Radio de una canción | [`queue`](../../src/ytm.rs) |
| Biblioteca de la cuenta | [`library_playlists`](../../src/ytm.rs), [`liked_songs`](../../src/ytm.rs) |
| Dar o quitar «Me gusta» | [`like`](../../src/ytm.rs), [`remove_like`](../../src/ytm.rs), [`like`](../../src/library.rs) |
| Límite de cada zona | [`ZONE_LIMIT`](../../src/library.rs) |
| Qué secciones hay y cuáles exigen sesión | [`sections`](../../qml/Catalog.qml) |
| Zonas de una sección para su vista | [`zonas`](../../qml/Catalog.qml) |
| Categorías de playlists | [`saveCategorias`](../../qml/Catalog.qml), [`inCategoria`](../../qml/Catalog.qml) |

## Dependencias

- **[sesion](sesion.md)** (`account::with_session`, `Account.signedIn`): firmar las peticiones y
  saber si hay biblioteca. No hace falta leerla salvo para tocar la firma.
- **[reproduccion](reproduccion.md)** (`player::forget_queue`, `Player`): olvidar la cola de una
  lista al guardarla; `Catalog` lee la cola y la letra que publica `Player`.
- **[personalizacion](personalizacion.md)** (`AppSettings`): vista elegida por sección y opciones
  de categorías.
- `Catalog.lyricsDelay` y `Catalog.setLyricsDelay` guardan el retraso de la letra por comodidad;
  sus reglas están en [letra](letra.md).
- **La usan:** casi todas: [vistas](vistas.md), [detalle](detalle.md), [ventana](ventana.md),
  [reproduccion](reproduccion.md), [letra](letra.md), [historial](historial.md) (`ytm::tracking_urls`),
  [resolucion](resolucion.md) (`ytm::playability`).

## Estado actual

- **Última verificación:** 2026-11-17, cliente HTTP común y búsqueda en paralelo ([historial](../history/verificacion/catalogo.md)).
- **Pruebas:** ninguna en `ytm.rs` ni `library.rs` (dependen de la red); se prueban con
  `--probe home|explore|albums|playlists|search|album|queue`.
- **Sin verificar:** biblioteca con sesión en Linux; `like/like` y `like/removelike` con una
  sesión real.
- **Historial:** [docs/history/verificacion/catalogo.md](../history/verificacion/catalogo.md).

## Pendiente

- Guardar álbumes en la biblioteca y dar o quitar «Me gusta» desde el menú contextual (hoy desde
  la barra y la mascota) ([ROADMAP](../ROADMAP.md)).
