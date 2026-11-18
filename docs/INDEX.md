# Índice de la documentación

Qué leer para cada tarea. Las tablas a partir de [Áreas](#áreas) las escribe
`python3 scripts/docs.py index` desde el código y el frontmatter de las fichas, y
`python3 scripts/docs.py check` falla si se desfasan.

## Por tarea

| Quiero… | Lee, en este orden |
|---|---|
| Entender el proyecto desde cero (no sé Rust ni QML) | [GUIA](GUIA.md) → [ARCHITECTURE](ARCHITECTURE.md) |
| Cambiar algo de un área | Su ficha ([áreas](#áreas); si solo sabes el archivo, [archivo → área](#archivo--área)) → la sección de [TRAMPAS](TRAMPAS.md) que toque → [verificar-interfaz](runbooks/verificar-interfaz.md) o [verificar-reproduccion](runbooks/verificar-reproduccion.md) |
| Tocar algo que usan varias áreas (`Main.qml`, `Catalog.qml`, `Theme.qml`, `player.rs`) | [Dependencias](#dependencias-entre-áreas) (quién lo usa) → las fichas de esas áreas → [ARCHITECTURE](ARCHITECTURE.md) |
| Añadir una opción | [nueva-opcion](runbooks/nueva-opcion.md) |
| Añadir un color a las skins | [nuevo-color-de-skin](runbooks/nuevo-color-de-skin.md) |
| Añadir un archivo QML o un puente de Rust | [nuevo-componente](runbooks/nuevo-componente.md) |
| Empezar algo que no encaja en ningún área | [nueva-area](runbooks/nueva-area.md) → [plantilla](templates/area.md) |
| Tomar una decisión de arquitectura | [decisions/](decisions/README.md) (¿ya está decidido?) → [registrar-decision](runbooks/registrar-decision.md) |
| Probar la interfaz sin tocar mis datos | [verificar-interfaz](runbooks/verificar-interfaz.md) |
| Probar que suena, o por qué no suena una pista | [verificar-reproduccion](runbooks/verificar-reproduccion.md) → [resolucion](areas/resolucion.md) |
| Probar con sesión | [probar-sesion](runbooks/probar-sesion.md) |
| Probar Discord o Last.fm | [probar-plugins](runbooks/probar-plugins.md) |
| Medir memoria o CPU | [medir-rendimiento](runbooks/medir-rendimiento.md) → la sección «Medidas» de la ficha |
| Retomar una tarea a medias (otra sesión, contexto compactado) | [EN-CURSO](EN-CURSO.md) → [retomar-trabajo](runbooks/retomar-trabajo.md) |
| Saber qué falta y en qué orden | [ROADMAP](ROADMAP.md) |
| Saber por qué algo es como es, o qué medía antes | La ficha («Reglas y decisiones») → su ADR → [history/](history/README.md) |
| Compilar e instalar la app | [COMPILAR](../COMPILAR.md) |

## Áreas

<!-- generado:areas -->
> Esta tabla se genera con `python3 scripts/docs.py index`. No la edites a mano: se pierde al regenerarla.

| Área | Qué es | Opciones | ADR |
|---|---|---|---|
| [Catálogo de YouTube Music](areas/catalogo.md) | Secciones (Inicio, Explorar, Álbumes, Playlists, Me gusta, Historial), búsqueda, detalle abierto y categorías de playlists, pedidos a InnerTube (Explorar, a ListenBrainz si se elige) y publicados como JSON. | `categoria`, `categorias`, `explorarFuente` | [ADR-04](decisions/ADR-04-json-hacia-qml.md), [ADR-06](decisions/ADR-06-canciones-por-la-pagina-de-la-lista.md), [ADR-09](decisions/ADR-09-cache-de-secciones-en-disco.md), [ADR-19](decisions/ADR-19-explorar-con-listenbrainz.md), [ADR-20](decisions/ADR-20-fuente-de-explorar-a-elegir.md) |
| [Detalle e inspeccionar](areas/detalle.md) | Detalle de un álbum, playlist o artista con Reproducir y Aleatorio, y el modo inspeccionar que gira la caja, la abre y saca el disco. | — | — |
| [Registro de escuchas](areas/historial.md) | Apunta en el historial de YouTube Music lo que suena, con los mismos avisos que manda su reproductor, sin retrasar el arranque. | `historial` | [ADR-12](decisions/ADR-12-historial-con-los-avisos-del-reproductor.md) |
| [Piezas comunes de la interfaz](areas/interfaz-comun.md) | Vidrio, carátula, icono, botones, deslizador, pestañas y campo de texto que usan todas las pantallas. | — | — |
| [Letra sincronizada](areas/letra.md) | Letra de LRCLIB, NetEase y Kugou, a elegir, palabra a palabra con los tiempos reales de cada sílaba, al estilo Better Lyrics, con tres calidades y retraso ajustable por canción. | `letraOrigen`, `letraSinTiempos`, `letraCalidad`, `letraTamano`, `letraFuente`, `letraPeso`, `letraAlineacion`, `letraAnimada`, `retraso:*`, `origen:*` | [ADR-13](decisions/ADR-13-letra-de-lrclib-con-un-solo-gestor.md), [ADR-18](decisions/ADR-18-letra-de-varias-fuentes.md) |
| [Mascotas](areas/mascotas.md) | Una imagen que cambia de pose según lo que pasa en el reproductor, reacciona unos segundos a lo que haces (pincharla, pasar canción, guardar en una playlist) y puede dar «Me gusta»; carpetas del usuario con PNG por pose. | — | — |
| [Opciones, skins y aspecto](areas/personalizacion.md) | Preferencias guardadas (vista por sección, skin, opciones genéricas), la hoja de Opciones, los tokens visuales de Theme, el vidrio y el modo ambiente. | `ambiente`, `ambienteMovimiento`, `desenfoque` | [ADR-11](decisions/ADR-11-skins-en-json-y-opciones-genericas.md), [ADR-17](decisions/ADR-17-fondo-fluido-con-sombreador-propio.md) |
| [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md) | Discord Rich Presence («Escuchando…»), scrobbling a Last.fm y escuchas en ListenBrainz, alimentados por los eventos del reproductor en un hilo propio. | — | [ADR-15](decisions/ADR-15-plugins-en-un-hilo-propio.md), [ADR-19](decisions/ADR-19-explorar-con-listenbrainz.md) |
| [Reproducción y cola](areas/reproduccion.md) | Cola, lista temporal, siguiente y anterior, repetición, volumen y estado de lo que suena, con mpv como motor en un proceso aparte. | `barra`, `ecualizador`, `ecualizadorBandas`, `amplificador` | [ADR-02](decisions/ADR-02-mpv-en-proceso-aparte.md) |
| [Resolución del audio y arranque instantáneo](areas/resolucion.md) | Obtiene la URL de audio de cada pista (vía rápida, yt-dlp residente o yt-dlp) con caché y precarga, para que suene en décimas de segundo. | `calidad`, `ytdlp` | [ADR-03](decisions/ADR-03-via-rapida-y-yt-dlp-de-respaldo.md), [ADR-05](decisions/ADR-05-precarga-de-urls.md), [ADR-08](decisions/ADR-08-yt-dlp-residente.md) |
| [Sesión de YouTube Music](areas/sesion.md) | Iniciar sesión (ventana propia o cookies del navegador), guardar solo las cookies de youtube.com y firmar las peticiones con SAPISIDHASH. | — | [ADR-07](decisions/ADR-07-inicio-de-sesion-en-proceso-aparte.md) |
| [Ventana y navegación](areas/ventana.md) | Arranque, ventana principal con escenario, navegación superior, panel de letra y cola, pantalla «Sonando», mini reproductor, búsqueda y menú de clic derecho. | `panel`, `sonando`, `sonandoTitulo`, `caratulaCalidad` | [ADR-10](decisions/ADR-10-mini-reproductor-oculta-la-ventana.md) |
| [Vistas de las secciones](areas/vistas.md) | Muro, Lomos y Cubeta, elegibles por sección, y el selector que las alterna al vuelo. | `caratulas` | [ADR-14](decisions/ADR-14-lomos-con-matrices-propias.md) |
<!-- /generado -->

## Archivo → área

<!-- generado:archivos -->
> Esta tabla se genera con `python3 scripts/docs.py index`. No la edites a mano: se pierde al regenerarla.

| Archivo | Área |
|---|---|
| [`login/src/login_linux.cpp`](../login/src/login_linux.cpp) | [Sesión de YouTube Music](areas/sesion.md) |
| [`login/src/main.rs`](../login/src/main.rs) | [Sesión de YouTube Music](areas/sesion.md) |
| [`qml/Ambient.qml`](../qml/Ambient.qml) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`qml/ArtistHero.qml`](../qml/ArtistHero.qml) | [Detalle e inspeccionar](areas/detalle.md) |
| [`qml/Catalog.qml`](../qml/Catalog.qml) | [Catálogo de YouTube Music](areas/catalogo.md) |
| [`qml/CategoryBar.qml`](../qml/CategoryBar.qml) | [Catálogo de YouTube Music](areas/catalogo.md) |
| [`qml/ContextMenu.qml`](../qml/ContextMenu.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/Cover.qml`](../qml/Cover.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/CubetaView.qml`](../qml/CubetaView.qml) | [Vistas de las secciones](areas/vistas.md) |
| [`qml/DetailView.qml`](../qml/DetailView.qml) | [Detalle e inspeccionar](areas/detalle.md) |
| [`qml/Glass.qml`](../qml/Glass.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/Icon.qml`](../qml/Icon.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/IconButton.qml`](../qml/IconButton.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/InspectView.qml`](../qml/InspectView.qml) | [Detalle e inspeccionar](areas/detalle.md) |
| [`qml/LomosView.qml`](../qml/LomosView.qml) | [Vistas de las secciones](areas/vistas.md) |
| [`qml/LyricsTiming.qml`](../qml/LyricsTiming.qml) | [Letra sincronizada](areas/letra.md) |
| [`qml/LyricsView.qml`](../qml/LyricsView.qml) | [Letra sincronizada](areas/letra.md) |
| [`qml/Main.qml`](../qml/Main.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/Mascot.qml`](../qml/Mascot.qml) | [Mascotas](areas/mascotas.md) |
| [`qml/MiniPlayer.qml`](../qml/MiniPlayer.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/MuroView.qml`](../qml/MuroView.qml) | [Vistas de las secciones](areas/vistas.md) |
| [`qml/NowPlayingPanel.qml`](../qml/NowPlayingPanel.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/NowPlayingView.qml`](../qml/NowPlayingView.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/PillButton.qml`](../qml/PillButton.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/PlayerBar.qml`](../qml/PlayerBar.qml) | [Reproducción y cola](areas/reproduccion.md) |
| [`qml/QueueList.qml`](../qml/QueueList.qml) | [Reproducción y cola](areas/reproduccion.md) |
| [`qml/SearchField.qml`](../qml/SearchField.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/SectionView.qml`](../qml/SectionView.qml) | [Vistas de las secciones](areas/vistas.md) |
| [`qml/SettingsSheet.qml`](../qml/SettingsSheet.qml) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`qml/Slider.qml`](../qml/Slider.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/TabStrip.qml`](../qml/TabStrip.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/TextField.qml`](../qml/TextField.qml) | [Piezas comunes de la interfaz](areas/interfaz-comun.md) |
| [`qml/Theme.qml`](../qml/Theme.qml) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`qml/TintProbe.qml`](../qml/TintProbe.qml) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`qml/TopNav.qml`](../qml/TopNav.qml) | [Ventana y navegación](areas/ventana.md) |
| [`qml/ViewSwitcher.qml`](../qml/ViewSwitcher.qml) | [Vistas de las secciones](areas/vistas.md) |
| [`skins/grafito.json`](../skins/grafito.json) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`skins/medianoche.json`](../skins/medianoche.json) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`skins/neon.json`](../skins/neon.json) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`skins/vidrio.json`](../skins/vidrio.json) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`src/account.rs`](../src/account.rs) | [Sesión de YouTube Music](areas/sesion.md) |
| [`src/audio.rs`](../src/audio.rs) | [Reproducción y cola](areas/reproduccion.md) |
| [`src/daemon.rs`](../src/daemon.rs) | [Resolución del audio y arranque instantáneo](areas/resolucion.md) |
| [`src/history.rs`](../src/history.rs) | [Registro de escuchas](areas/historial.md) |
| [`src/library.rs`](../src/library.rs) | [Catálogo de YouTube Music](areas/catalogo.md) |
| [`src/listenbrainz.rs`](../src/listenbrainz.rs) | [Catálogo de YouTube Music](areas/catalogo.md) |
| [`src/login_mac.mm`](../src/login_mac.mm) | [Sesión de YouTube Music](areas/sesion.md) |
| [`src/lyrics.rs`](../src/lyrics.rs) | [Letra sincronizada](areas/letra.md) |
| [`src/main.rs`](../src/main.rs) | [Ventana y navegación](areas/ventana.md) |
| [`src/player.rs`](../src/player.rs) | [Reproducción y cola](areas/reproduccion.md) |
| [`src/plugins.rs`](../src/plugins.rs) | [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md) |
| [`src/plugins/discord.rs`](../src/plugins/discord.rs) | [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md) |
| [`src/plugins/lastfm.rs`](../src/plugins/lastfm.rs) | [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md) |
| [`src/plugins/listenbrainz.rs`](../src/plugins/listenbrainz.rs) | [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md) |
| [`src/resolver.rs`](../src/resolver.rs) | [Resolución del audio y arranque instantáneo](areas/resolucion.md) |
| [`src/settings.rs`](../src/settings.rs) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| [`src/signals.cpp`](../src/signals.cpp) | [Reproducción y cola](areas/reproduccion.md) |
| [`src/stream.rs`](../src/stream.rs) | [Resolución del audio y arranque instantáneo](areas/resolucion.md) |
| [`src/window.cpp`](../src/window.cpp) | [Ventana y navegación](areas/ventana.md) |
| [`src/ytdlp_daemon.py`](../src/ytdlp_daemon.py) | [Resolución del audio y arranque instantáneo](areas/resolucion.md) |
| [`src/ytm.rs`](../src/ytm.rs) | [Catálogo de YouTube Music](areas/catalogo.md) |
<!-- /generado -->

## Opciones

Claves de `AppSettings.opcion`. Vacío es el valor por defecto (el `fallback` de su fila en
`SettingsSheet.qml`).

<!-- generado:opciones -->
> Esta tabla se genera con `python3 scripts/docs.py index`. No la edites a mano: se pierde al regenerarla.

| Clave | En Opciones | Área |
|---|---|---|
| `ambiente` | Modo ambiente (apariencia) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| `ambienteMovimiento` | Movimiento del ambiente (apariencia) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| `amplificador` | — (interna) | [Reproducción y cola](areas/reproduccion.md) |
| `barra` | Barra de reproducción (apariencia) | [Reproducción y cola](areas/reproduccion.md) |
| `calidad` | Calidad del audio (reproduccion) | [Resolución del audio y arranque instantáneo](areas/resolucion.md) |
| `caratulaCalidad` | Carátula de «Sonando» (apariencia) | [Ventana y navegación](areas/ventana.md) |
| `caratulas` | Carátulas del Muro (vistas) | [Vistas de las secciones](areas/vistas.md) |
| `categoria` | — (interna) | [Catálogo de YouTube Music](areas/catalogo.md) |
| `categorias` | — (interna) | [Catálogo de YouTube Music](areas/catalogo.md) |
| `desenfoque` | Desenfoque (apariencia) | [Opciones, skins y aspecto](areas/personalizacion.md) |
| `ecualizador` | — (interna) | [Reproducción y cola](areas/reproduccion.md) |
| `ecualizadorBandas` | — (interna) | [Reproducción y cola](areas/reproduccion.md) |
| `explorarFuente` | Fuente de Explorar (vistas) | [Catálogo de YouTube Music](areas/catalogo.md) |
| `historial` | Registrar en YouTube Music (reproduccion) | [Registro de escuchas](areas/historial.md) |
| `letraAlineacion` | Alineación de la letra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `letraAnimada` | — (interna) | [Letra sincronizada](areas/letra.md) |
| `letraCalidad` | Calidad de la letra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `letraFuente` | Fuente de la letra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `letraOrigen` | Origen de la letra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `letraPeso` | Grosor de la letra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `letraSinTiempos` | Letra sin tiempo por palabra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `letraTamano` | Tamaño de la letra (apariencia) | [Letra sincronizada](areas/letra.md) |
| `origen:*` | — (interna) | [Letra sincronizada](areas/letra.md) |
| `panel` | Panel de letra y cola (vistas) | [Ventana y navegación](areas/ventana.md) |
| `retraso:*` | — (interna) | [Letra sincronizada](areas/letra.md) |
| `sonando` | Pantalla Sonando (vistas) | [Ventana y navegación](areas/ventana.md) |
| `sonandoTitulo` | Título en Sonando (vistas) | [Ventana y navegación](areas/ventana.md) |
| `ytdlp` | yt-dlp residente (reproduccion) | [Resolución del audio y arranque instantáneo](areas/resolucion.md) |
<!-- /generado -->

## Dependencias entre áreas

Sale del código: módulos de Rust (`crate::x`, `x::`), singletons de QML (`Player.`, `Library.`…) y
componentes QML que monta cada archivo. No cuenta las piezas que usa todo (`Theme`, las de
[interfaz-comun](areas/interfaz-comun.md)).

<!-- generado:dependencias -->
> Esta tabla se genera con `python3 scripts/docs.py index`. No la edites a mano: se pierde al regenerarla.

| Área | Usa | La usan |
|---|---|---|
| [Catálogo de YouTube Music](areas/catalogo.md) | [Opciones, skins y aspecto](areas/personalizacion.md), [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md), [Reproducción y cola](areas/reproduccion.md), [Sesión de YouTube Music](areas/sesion.md) | [Detalle e inspeccionar](areas/detalle.md), [Registro de escuchas](areas/historial.md), [Letra sincronizada](areas/letra.md), [Mascotas](areas/mascotas.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md), [Reproducción y cola](areas/reproduccion.md), [Resolución del audio y arranque instantáneo](areas/resolucion.md), [Sesión de YouTube Music](areas/sesion.md), [Ventana y navegación](areas/ventana.md), [Vistas de las secciones](areas/vistas.md) |
| [Detalle e inspeccionar](areas/detalle.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Reproducción y cola](areas/reproduccion.md) | [Ventana y navegación](areas/ventana.md) |
| [Registro de escuchas](areas/historial.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Sesión de YouTube Music](areas/sesion.md) | [Opciones, skins y aspecto](areas/personalizacion.md), [Reproducción y cola](areas/reproduccion.md) |
| [Piezas comunes de la interfaz](areas/interfaz-comun.md) | — | — |
| [Letra sincronizada](areas/letra.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Reproducción y cola](areas/reproduccion.md) | [Reproducción y cola](areas/reproduccion.md), [Ventana y navegación](areas/ventana.md) |
| [Mascotas](areas/mascotas.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Reproducción y cola](areas/reproduccion.md) | [Ventana y navegación](areas/ventana.md) |
| [Opciones, skins y aspecto](areas/personalizacion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Registro de escuchas](areas/historial.md), [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md), [Reproducción y cola](areas/reproduccion.md), [Resolución del audio y arranque instantáneo](areas/resolucion.md), [Sesión de YouTube Music](areas/sesion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Letra sincronizada](areas/letra.md), [Ventana y navegación](areas/ventana.md), [Vistas de las secciones](areas/vistas.md) |
| [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md) | [Catálogo de YouTube Music](areas/catalogo.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Reproducción y cola](areas/reproduccion.md), [Ventana y navegación](areas/ventana.md) |
| [Reproducción y cola](areas/reproduccion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Registro de escuchas](areas/historial.md), [Letra sincronizada](areas/letra.md), [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md), [Resolución del audio y arranque instantáneo](areas/resolucion.md), [Sesión de YouTube Music](areas/sesion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Detalle e inspeccionar](areas/detalle.md), [Letra sincronizada](areas/letra.md), [Mascotas](areas/mascotas.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Resolución del audio y arranque instantáneo](areas/resolucion.md), [Sesión de YouTube Music](areas/sesion.md), [Ventana y navegación](areas/ventana.md), [Vistas de las secciones](areas/vistas.md) |
| [Resolución del audio y arranque instantáneo](areas/resolucion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Reproducción y cola](areas/reproduccion.md), [Sesión de YouTube Music](areas/sesion.md) | [Opciones, skins y aspecto](areas/personalizacion.md), [Reproducción y cola](areas/reproduccion.md), [Ventana y navegación](areas/ventana.md) |
| [Sesión de YouTube Music](areas/sesion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Reproducción y cola](areas/reproduccion.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Registro de escuchas](areas/historial.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Reproducción y cola](areas/reproduccion.md), [Resolución del audio y arranque instantáneo](areas/resolucion.md), [Ventana y navegación](areas/ventana.md) |
| [Ventana y navegación](areas/ventana.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Detalle e inspeccionar](areas/detalle.md), [Letra sincronizada](areas/letra.md), [Mascotas](areas/mascotas.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Plugins (Discord, Last.fm y ListenBrainz)](areas/plugins.md), [Reproducción y cola](areas/reproduccion.md), [Resolución del audio y arranque instantáneo](areas/resolucion.md), [Sesión de YouTube Music](areas/sesion.md), [Vistas de las secciones](areas/vistas.md) | — |
| [Vistas de las secciones](areas/vistas.md) | [Catálogo de YouTube Music](areas/catalogo.md), [Opciones, skins y aspecto](areas/personalizacion.md), [Reproducción y cola](areas/reproduccion.md) | [Ventana y navegación](areas/ventana.md) |
<!-- /generado -->
