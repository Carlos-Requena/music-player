---
area: catalogo
titulo: Catálogo de YouTube Music
resumen: Secciones (Inicio, Explorar, Álbumes, Playlists, Me gusta, Historial), búsqueda, detalle abierto y categorías de playlists, pedidos a InnerTube (Explorar, a ListenBrainz si se elige) y publicados como JSON.
archivos: [src/ytm.rs, src/library.rs, src/listenbrainz.rs, qml/Catalog.qml, qml/CategoryBar.qml]
opciones: [categoria, categorias, explorarFuente]
adr: [ADR-04, ADR-06, ADR-09, ADR-19, ADR-20, ADR-22]
---

# Catálogo de YouTube Music

Todo lo que se ve para elegir: las secciones de la navegación superior, los resultados de
búsqueda y el detalle de un álbum, playlist o artista. Cómo se pinta cada sección es cosa de
[vistas](vistas.md); el detalle abierto, de [detalle](detalle.md).

## Qué hace

- **Explorar empieza por «Recomendados»** (`ytm::recomendados`), con las dos fuentes
  ([ADR-22](../decisions/ADR-22-explorar-por-categorias-con-recomendados.md)): las filas de
  canciones del Inicio de YouTube Music («Selecciones rápidas», personalizada con la sesión; 「おすすめ」
  en la app en japonés). Cada zona de Explorar es una tarjeta ([vistas](vistas.md)) que se abre
  con `Library.openZona(zona)`: sin red, como un detalle de `kind` "zona"; si todo son canciones,
  en `tracks` (`ytm::item_track`), y si no, la zona en `zonas` ([detalle](detalle.md)).
- **Relacionado** (`ytm::related`, pedido con `Library.openRelated(item, "related")`): la
  pestaña «Relacionado» de YouTube Music para una canción. La página sale de la pestaña con
  `browseEndpoint` `MPTR…` de la respuesta de `next`; su primera fila de canciones («También te
  puede interesar») va a `tracks` y el resto («Listas recomendadas», «Artistas similares», «Más
  de <artista>») a `zonas`. Se abre como un detalle ([detalle](detalle.md)).
- **Continuación de la radio** (`ytm::queue_page`, `ytm::queue_more`): la cola de una canción
  trae `nextRadioContinuationData`; con ella se piden las siguientes ([reproduccion](reproduccion.md)).
- **Sin sesión:** Inicio, Explorar, Álbumes (novedades), «Ánimo y géneros» y búsqueda de
  canciones, álbumes, playlists y artistas.
- **Explorar sale de ListenBrainz** ([ADR-19](../decisions/ADR-19-explorar-con-listenbrainz.md))
  o, si se elige en Opciones › Vistas › «Fuente de Explorar» (opción `explorarFuente`:
  vacío = ListenBrainz, `youtube`), del Explorar de YouTube Music
  ([ADR-20](../decisions/ADR-20-fuente-de-explorar-a-elegir.md)). Con el usuario de ListenBrainz conectado en [plugins](plugins.md):
  «Hecho para ti» (Exploración semanal, Jams semanales y Jams diarias, las listas que Troi genera
  en el servidor de ListenBrainz, que se abren como un detalle con Reproducir y Aleatorio),
  «Recomendado para ti» (recomendaciones colaborativas) y «Novedades de tus artistas» (álbumes).
  Siempre, también sin cuenta: «Lo más escuchado esta semana» en ListenBrainz.
- **Con sesión:** además, la biblioteca de la cuenta: Playlists (`FEmusic_liked_playlists`),
  álbumes guardados (`FEmusic_liked_albums`), Me gusta (`VLLM`) e **Historial**
  (`FEmusic_history`: lo escuchado en la cuenta, en zonas por día como «Hoy» y «Ayer»; incluye lo
  que esta app registra, ver [historial](historial.md)). Sin sesión, Playlists, Me gusta e
  Historial quedan vacías. El historial se vuelve a pedir cada vez que se abre su sección
  (`Library.loadHistorial`), porque cambia al escuchar.
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
- **Ir al álbum o al artista de una canción, o al artista de un álbum** (`Library.openRelated(item,
  "album"|"artist")`, desde el menú de clic derecho de [ventana](ventana.md)). Las canciones y
  pistas no traen esos enlaces, así que se piden al elegir la entrada, en un hilo:
  `ytm::song_links` lee el artista y el álbum de la ficha de la canción (`next`) y
  `ytm::album_info` completa el álbum (título, carátula y su playlist `OLAK5uy_…`) y da su artista.
  El detalle se abre al momento con lo que se sabe (el nombre del artista) y comparte el contador
  `detail_request`. Si no hay álbum o artista, se cierra y avisa con `Library.aviso`.

## Reglas y decisiones

- **Los videoclips no llevan álbum** en su ficha: `song_links` busca la versión de audio de la
  misma canción (mismo título y artista, entre los cinco primeros resultados) y toma su álbum.
- **En la página de un álbum, la playlist y la carátula se toman de la cabecera**
  (`header_thumb`): fuera de ella hay otras (el carrusel «otras versiones» del artista) y `find`
  recorre las claves en orden alfabético ([TRAMPAS](../TRAMPAS.md#youtube-yt-dlp-y-mpv)).

- **Recomendados se reconoce por su forma, no por su título**: un carrusel en columnas
  (`numItemsPerColumn`) de filas `musicResponsiveListItemRenderer`; el título cambia con el
  idioma y la sesión. Va a la vez que `FEmusic_explore` (`thread::scope`) y, si falla, se queda la
  de la copia guardada para que las tarjetas no se corran bajo el ratón
  ([ADR-22](../decisions/ADR-22-explorar-por-categorias-con-recomendados.md)).
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
- **De ListenBrainz a YouTube Music, una búsqueda por canción** (`ytm::search_one_kind`, cuatro
  a la vez) que se guarda por MBID en `<caché>/musicplayer/listenbrainz-youtube.json`, también
  cuando no se encuentra; si la búsqueda falla por la red no se guarda y se reintenta en la
  próxima carga. De los tres primeros resultados vale el primero cuyo título o artista coincide
  (`pick`): basta con uno porque ListenBrainz y YouTube escriben a veces el mismo nombre en
  alfabetos distintos (japonés y romaji).
- **ListenBrainz, una petición por segundo** (`wait_turn`) y User-Agent propio
  (`musicplayer/<versión>`). Por eso Explorar va en su propio hilo (`load_explorar`) y publica cada
  zona en cuanto está lista: no retrasa las demás secciones.
- **Una lista de ListenBrainz es un elemento `playlist` con `browseId` `lb:<mbid>`** y sin
  `playlistId`: `Library.openDetail` la abre con `listenbrainz::detail` (de memoria si ya se
  convirtió al cargar Explorar). No se puede guardar entera en la cuenta; sus canciones, sí.
- **Lo que no cambia no se reconstruye en QML:** `Catalog.categorias` sale del texto guardado
  (`categoriasJson`), no de `AppSettings.revision`, para que tocar otra opción no rehaga
  Playlists. Lomos y Cubeta juntan las zonas con `Catalog.allItems`.

## Cómo funciona

- `Library.load` pide las secciones en un hilo; cada respuesta vuelve con
  `qt_thread().queue(...)` y se descarta si su `load_token` ya no es el último. La búsqueda
  igual con `search_request`.
- Con sesión, cada petición se firma con [sesion](sesion.md) (`account::with_session`).
- Caché en `<caché>/musicplayer/<anonimo|cuenta>-<sección>.json`; Explorar, en
  `anonimo-explorar-listenbrainz.json` o `anonimo-explorar.json` según su fuente (no depende de la
  sesión de YouTube); al cambiar de fuente se vacía y no se muestra la copia de la otra.
- Explorar: `listenbrainz::explorar(usuario, publicar)` pide `/user/{u}/playlists/createdfor`, cada
  `/playlist/{mbid}`, `/cf/recommendation/user/{u}/recording` (+ `/metadata/recording`),
  `/user/{u}/fresh_releases` y `/stats/sitewide/recordings?range=week`. El usuario sale de
  `plugins::listenbrainz_user()`; al cambiar, `Main.qml` vuelve a llamar a `Library.load`.

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Búsqueda («Vetusta Morla», `--probe search`, cuatro listas a la vez) | 0,50–0,57 s | 2026-11-17, M4 Pro, release |
| Explorar de ListenBrainz (`--probe explore mr_monkey`, 2 listas, 30 recomendaciones, 15 novedades, 30 más escuchadas), caché vacía | 24,7 s, 50 de 50 canciones de una lista encontradas y correctas | 2026-11-17, M4 Pro, release |
| Lo mismo con la caché de búsquedas llena (solo las peticiones a ListenBrainz, una por segundo) | 7,8 s | 2026-11-17, M4 Pro, release |
| Canciones de una playlist de 500 pistas (`playlist_tracks`) | ~3 s | 2026-11-14, M4 Pro, release |
| Sección visible al abrir, desde la caché | ~300 ms con carátulas | 2026-11-14, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `src/ytm.rs` | Cliente InnerTube: secciones, búsqueda, detalle, colas, biblioteca, guardar |
| `src/library.rs` | Singleton `Library`: publica secciones, búsqueda y detalle; caché en disco |
| `src/listenbrainz.rs` | Explorar: API de ListenBrainz, paso a YouTube Music y su caché; token de ListenBrainz |
| `qml/Catalog.qml` | Singleton: JSON → objetos, lista de secciones, categorías, retraso de la letra |
| `qml/CategoryBar.qml` | Pestañas de categorías de Playlists |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Recorrer la respuesta buscando renderers | [`find_all`](../../src/ytm.rs) |
| Relacionado de una canción | [`related`](../../src/ytm.rs), [`open_song_related`](../../src/library.rs) |
| Continuación de la radio | [`queue_more`](../../src/ytm.rs), [`panel_tracks`](../../src/ytm.rs) |
| Una sección por `browseId` | [`browse`](../../src/ytm.rs) |
| Canciones de un álbum o playlist | [`playlist_tracks`](../../src/ytm.rs) |
| Álbum y artista de una canción; artista de un álbum | [`song_links`](../../src/ytm.rs), [`album_info`](../../src/ytm.rs), [`open_related`](../../src/library.rs) |
| Carátula de la cabecera de un álbum | [`header_thumb`](../../src/ytm.rs) |
| Radio de una canción | [`queue`](../../src/ytm.rs) |
| Biblioteca de la cuenta | [`library_playlists`](../../src/ytm.rs), [`liked_songs`](../../src/ytm.rs) |
| Dar o quitar «Me gusta» | [`like`](../../src/ytm.rs), [`remove_like`](../../src/ytm.rs), [`like`](../../src/library.rs) |
| Límite de cada zona | [`ZONE_LIMIT`](../../src/library.rs) |
| Zonas de Explorar y su fuente | [`explorar`](../../src/listenbrainz.rs), [`load_explorar`](../../src/library.rs), [`set_explorar_youtube`](../../src/library.rs) |
| Recomendados (primera zona de Explorar) | [`recomendados`](../../src/ytm.rs), [`with_recomendados`](../../src/library.rs) |
| Abrir una categoría de Explorar como detalle | [`open_zona`](../../src/library.rs), [`item_track`](../../src/ytm.rs), [`all_songs`](../../src/ytm.rs) |
| Historial de escucha | [`history`](../../src/library.rs), [`load_historial`](../../src/library.rs) |
| Buscar en YouTube Music lo que recomienda ListenBrainz | [`find`](../../src/listenbrainz.rs), [`pick`](../../src/listenbrainz.rs), [`search_one_kind`](../../src/ytm.rs) |
| Detalle de una lista de ListenBrainz | [`detail`](../../src/listenbrainz.rs) |
| Una petición por segundo | [`wait_turn`](../../src/listenbrainz.rs) |
| Qué secciones hay y cuáles exigen sesión | [`sections`](../../qml/Catalog.qml) |
| Zonas de una sección para su vista | [`zonas`](../../qml/Catalog.qml) |
| Categorías de playlists | [`saveCategorias`](../../qml/Catalog.qml), [`inCategoria`](../../qml/Catalog.qml) |

## Dependencias

- **[sesion](sesion.md)** (`account::with_session`, `Account.signedIn`): firmar las peticiones y
  saber si hay biblioteca. No hace falta leerla salvo para tocar la firma.
- **[reproduccion](reproduccion.md)** (`player::forget_queue`, `Player`): olvidar la cola de una
  lista al guardarla; `Catalog` lee la cola y la letra que publica `Player`.
- **[personalizacion](personalizacion.md)** (`AppSettings`): vista elegida por sección, opciones
  de categorías y la fuente de Explorar (`library::set_explorar_youtube` desde `settings.rs`).
- **[plugins](plugins.md)** (`plugins::listenbrainz_user`): el usuario de ListenBrainz de Explorar.
- `Catalog.lyricsDelay` y `Catalog.setLyricsDelay` guardan el retraso de la letra por comodidad;
  sus reglas están en [letra](letra.md).
- **La usan:** casi todas: [vistas](vistas.md), [detalle](detalle.md), [ventana](ventana.md),
  [reproduccion](reproduccion.md), [letra](letra.md), [historial](historial.md) (`ytm::tracking_urls`),
  [resolucion](resolucion.md) (`ytm::playability`).

## Estado actual

- **Última verificación:** 2026-11-21, Recomendados en Explorar y categorías como detalle ([historial](../history/verificacion/catalogo.md)).
- **Pruebas:** ninguna en `ytm.rs` ni `library.rs` (dependen de la red); se prueban con
  `--probe home|recomendados|explore|explore-youtube|history|albums|playlists|search|album|queue|links|radio|related`
  (`--probe explore <usuario>` para otro usuario de ListenBrainz; `history` necesita sesión). `mod tests` de `src/listenbrainz.rs`: nombres comparables,
  primer artista del crédito, elección del resultado, MBID y fecha. `mod tests` de `src/ytm.rs`:
  `item_track` (artista y duración del subtítulo) y `all_songs`.
- **Sin verificar:** Recomendados con una sesión real (que la fila personalizada tenga la forma que
  se busca) y con la cuenta en japonés; la sección Historial con una sesión real (que `FEmusic_history` dé sus
  zonas por día con este recorrido); el cambio de fuente de Explorar pulsado en Opciones (sí al
  arrancar con la opción puesta); Explorar con el usuario del propietario (sin escuchas aún en ListenBrainz);
  la calidad de la búsqueda con música japonesa y anime; biblioteca con sesión en Linux; `like/like` y `like/removelike` con una
  sesión real.
- **Historial:** [docs/history/verificacion/catalogo.md](../history/verificacion/catalogo.md).

## Pendiente

- Explorar sin cuenta de ListenBrainz es pobre (solo lo más escuchado): una zona de LB Radio
  sembrada con los artistas de «Me gusta» ([ADR-19](../decisions/ADR-19-explorar-con-listenbrainz.md)).

- Guardar álbumes en la biblioteca y dar o quitar «Me gusta» desde el menú contextual (hoy desde
  la barra y la mascota) ([ROADMAP](../ROADMAP.md)).
