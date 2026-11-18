# Historial de verificación · Catálogo de YouTube Music

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/catalogo.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-18 · Ir al álbum o al artista (rama `feature/artista-y-ecualizador`)

- **Cambio:** `ytm::song_links`, `ytm::album_info`, `header_thumb` y `Library.openRelated` con su
  aviso; sonda `--probe links ID`. `playlist_tracks` toma la carátula de la cabecera (`thumbnail`),
  no la foto del artista (`straplineThumbnail`).
- **Verificado:** `--probe links` con dos videoclips (dQw4w9WgXcQ, kJQP7kiw5Fk): álbum, su lista
  y artista correctos; en la app, búsqueda «despacito» → clic derecho en la canción → «Ir al
  álbum» abre «Despacito (con Daddy Yankee)» con su carátula y su canción, y «Ver artista» abre
  Luis Fonsi con sus canciones.
- **No verificado:** con sesión; una canción sin álbum (el aviso); «Ver artista» de un álbum y
  desde la cola.

## 2026-11-17 · Fuente de Explorar a elegir y sección Historial (rama `feature/explorar-listenbrainz`)

- **Cambio:** opción `explorarFuente` (ListenBrainz o YouTube Music,
  [ADR-20](../../decisions/ADR-20-fuente-de-explorar-a-elegir.md)); sección Historial
  (`FEmusic_history`, con sesión) que se vuelve a pedir al abrirla; `--probe explore-youtube|history`.
- **Verificado:** compila sin avisos y `cargo test` en verde; capturas de Opciones › Vistas (fila
  nueva y vista de Historial), de Explorar con `explorarFuente: youtube` en el `settings.json` de
  prueba (zonas de YouTube) y de Historial sin sesión (aviso de iniciar sesión). Sin errores de QML.
- **No verificado:** Historial con sesión real (no se usan las cookies del propietario); cambiar la
  fuente pulsando en Opciones con la app abierta.

## 2026-11-17 · Explorar con ListenBrainz (rama `feature/explorar-listenbrainz`)

- **Cambio:** Explorar deja `FEmusic_explore` y sale de ListenBrainz (`src/listenbrainz.rs`,
  [ADR-19](../../decisions/ADR-19-explorar-con-listenbrainz.md)), en su propio hilo; las listas de
  ListenBrainz se abren como detalle (`lb:<mbid>`); `ytm::search_one_kind`.
- **Verificado:** `--probe explore mr_monkey` (usuario público de la documentación de
  ListenBrainz) con `HOME` temporal: 24,7 s con la caché vacía y 7,8 s con ella llena; las 50
  canciones de «Exploración semanal» encontradas y comprobadas a mano contra la lista. Capturas de
  Explorar con usuario (`plugins.json` de prueba con token falso) y sin él, y del detalle de una
  lista con Aleatorio (`--autoplay --open --shuffle`): `sonando true`, cola de 50, sin `error` ni
  errores de QML. `cargo test` en verde.
- **No verificado:** con el usuario del propietario (aún sin escuchas en ListenBrainz); música
  japonesa y anime; Linux.

## 2026-11-17 · Cliente HTTP común y búsqueda en paralelo (rama `perf/letra`)

- **Cambio:** `ytm::http`, un cliente HTTP para toda la app que reutiliza las conexiones; la
  búsqueda pide sus cuatro listas a la vez; `to_json` recorta las zonas sin copiarlas;
  `Catalog.categorias` sale de `categoriasJson`; `Catalog.allItems` para Lomos y Cubeta; fuera
  `Catalog.lineProgress`, que no usaba nadie.
- **Verificado:** `--probe search "Vetusta Morla"`, tres veces con cada versión: 1,6–1,8 s → 0,50–0,57 s.
  `cargo test` en verde; capturas de Inicio, Lomos y Opciones sin errores de QML.
- **No verificado:** con sesión (la búsqueda y las secciones de la cuenta); cambiar de categoría de
  playlists tocando otra opción.

## 2026-11-16 · `ytm::remove_like`

- **Cambio:** `Library.like` lleva `gusta` y llama a `ytm::like` o `ytm::remove_like`
  (`like/removelike`); `gustado` añade `videoId` y `gusta`.
- **Verificado:** el camino sin sesión (mensaje de error); compila sin avisos.
- **No verificado:** `like/removelike` con una sesión real.

## 2026-11-15 · `Library.like`

`ytm::like` (`like/like` de InnerTube) y `Library.like` → `gustado`, que después vuelve a pedir
«Me gusta». Compila sin avisos; **no verificado** contra YouTube con una sesión real (no se usan
las cookies del propietario en pruebas). Sin sesión responde «Hace falta iniciar sesión…».

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
