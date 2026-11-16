---
area: reproduccion
titulo: Reproducción y cola
resumen: Cola, lista temporal, siguiente y anterior, repetición, volumen y estado de lo que suena, con mpv como motor en un proceso aparte.
archivos: [src/player.rs, src/audio.rs, src/signals.cpp, qml/PlayerBar.qml, qml/QueueList.qml]
opciones: [barra]
adr: [ADR-02]
---

# Reproducción y cola

Del clic a que suene, y lo que pasa mientras suena. Obtener la URL es de
[resolucion](resolucion.md); la letra, de [letra](letra.md).

## Qué hace

- **Elegir una canción** la reproduce con su radio (o dentro de «Me gusta» si viene de ahí);
  **un álbum o playlist** usa su cola en caché o la pide y carga la primera pista.
- **Cola:** reproducir a continuación o al final (`Player.enqueue`; un álbum llega por la red y
  se inserta al recibirlo), reordenar arrastrando (`moveInQueue`, la que suena conserva su índice)
  y quitar (`removeFromQueue`).
- **Lista temporal:** canciones sueltas reunidas con el clic derecho, para oírlas en bucle.
- **Aleatorio:** baraja la lista en Rust (`shuffle_tracks`) y la reproduce entera.
- **Controles del sistema** (souvlaki: MPNowPlayingInfoCenter en macOS, MPRIS en Linux): sus
  órdenes llegan a `on_media_command`. Viven aquí y no en [plugins](plugins.md) porque en macOS van
  en el hilo principal.
- **Calidad real:** mpv informa del códec y la tasa (`Player.calidad`).

## Reglas y decisiones

- **mpv en un proceso aparte, por su socket IPC JSON**
  ([ADR-02](../decisions/ADR-02-mpv-en-proceso-aparte.md)), sin vídeo, sin sus scripts de interfaz
  y con caché de 16 MB.
- **Plan B:** si la URL directa falla (rechazada o caducada), se olvida y mpv carga la página de
  YouTube con su propio gancho de yt-dlp (~12 s, más tolerante). Si también falla, un reintento y
  después el error.
- **mpv solo avisa de la pausa cuando cambia**: al empezar una pista se aplica la última conocida
  (`mpv_paused`) ([TRAMPAS](../TRAMPAS.md#youtube-yt-dlp-y-mpv)).
- **Apps gráficas en macOS no heredan el `PATH`**: `search_path` añade `/opt/homebrew/bin` y
  `/usr/local/bin`.
- **Al empezar una pista nada espera** al historial ni a los plugins: se avisan después.
- **mpv muere con la app**, también ante SIGTERM, SIGINT o SIGHUP (`kill <pid>`, Ctrl+C):
  `signals.cpp` convierte la señal en `QCoreApplication::quit()`, la salida normal destruye el
  `Player` y el `Drop` de `Mpv` cierra el proceso. Una segunda señal mata la app sin esperar. El
  yt-dlp residente se cierra solo al ver su stdin cerrado. Con SIGKILL no hay remedio.

## Cómo funciona

1. La vista emite `activated(item)` y `Main.qml` llama a `Player.playItem(json)`.
2. `Player::load` pide la URL a [resolucion](resolucion.md): si ya está, `load_stream(url)`; si no,
   la resuelve en un hilo y luego la carga.
3. mpv avisa de `time-pos`, `duration`, `pause`, `playback-restart` y `end-file`; `audio.rs` lo
   traduce a `Event` y `Player::on_event` actualiza las propiedades. Al terminar una pista pasa a
   la siguiente y precarga las tres de después.
4. Al empezar: `plugins::emit(Track)`, `history::start` y la letra ([letra](letra.md)).

Al arrancar la app, `Player.warmUp` lanza mpv para que la primera pista no pague su arranque.
Stderr escribe `arranque de pista: N ms` en cada una.

## Interfaz

- `PlayerBar.qml`: barra flotante en uno de **tres estilos** (opción `barra`, leída en
  `Theme.barStyle`; diseños del propietario):
  - **Islas** (por defecto): tres islas de vidrio sueltas: lo que suena (carátula redonda, título,
    artista y «Me gusta»), los controles con la posición, y mini reproductor, panel y volumen.
  - **Clásica**: una barra de 84 px; en el centro, aleatorio, anterior, reproducir, siguiente y
    repetir, con la posición debajo.
  - **Compacta**: una barra de 64 px; la posición es una línea fina de color de acento en el borde
    de arriba (se pulsa o arrastra; con el foco, las flechas mueven 5 s) y el tiempo va en texto
    junto a los extras.

  Las piezas (`NowPlaying`, `Transport`, `Seek`, `Extras`…) son componentes del mismo archivo que
  comparten los tres; el alto que reserva la ventana es `Theme.barHeight`. Pulsar en una isla fuera de los controles abre «Sonando»
  ([ventana](ventana.md)), preferencia del propietario; los controles se quedan su clic porque
  usan `ReleaseWithinBounds`. El botón de reproducir late mientras la pista se resuelve.
  - **Un solo desenfoque** para las tres islas: se captura la franja de la barra y se recorta con la
    forma de las islas (`shapes`); un desenfoque por isla costaba más memoria.
  - **«Me gusta»**: lleno si la canción está en la sección «Me gusta» o se acaba de dar
    (`Library.like`); el aviso del resultado lo da el menú contextual. No se puede quitar (no hay
    petición para ello).
  - **Aleatorio** baraja lo que queda de la cola detrás de la que suena (`Player.shuffleQueue`);
    es una acción, no un modo que se active y desactive.
- `QueueList.qml`: la cola del panel y de «Sonando». Clic salta, clic derecho abre su menú (lleva
  `queueIndex`) y arrastrar reordena; un `MouseArea` con `preventStealing: true` impide que la
  lista se quede el gesto.

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Proceso mpv en reposo / reproduciendo | 20 MB / ~75 MB | 2026-11-13, M4 Pro |

## Archivos

| Archivo | Contenido |
|---|---|
| `src/player.rs` | Singleton `Player`: cola, lista temporal, estado, controles del sistema, avisos |
| `src/audio.rs` | Proceso mpv y su IPC; búsqueda de ejecutables en el `PATH` ampliado |
| `src/signals.cpp` | SIGTERM, SIGINT y SIGHUP cierran la app de forma ordenada (y con ella, mpv) |
| `qml/PlayerBar.qml` | Barra de reproducción en tres estilos (Islas, Clásica, Compacta) |
| `qml/QueueList.qml` | Lista de la cola, con arrastrar para reordenar |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Estilo de la barra y su alto | [`barStyle`](../../qml/Theme.qml), [`barHeight`](../../qml/Theme.qml) |
| Elegir algo para reproducir | [`play_item`](../../src/player.rs) |
| Barajar | [`shuffle_tracks`](../../src/player.rs) |
| Colas en caché | [`QUEUES`](../../src/player.rs) |
| Precarga de las siguientes | [`prefetch_next`](../../src/player.rs) |
| Órdenes del sistema | [`on_media_command`](../../src/player.rs) |
| Siguiente pedida por el usuario (`saltada`) o al acabar la pista | [`next`](../../src/player.rs), [`advance`](../../src/player.rs) |
| Lanzar mpv | [`spawn`](../../src/audio.rs) |
| Eventos de mpv | [`read_events`](../../src/audio.rs) |
| `PATH` ampliado | [`search_path`](../../src/audio.rs) |
| Cerrar mpv al salir | [`Drop for Mpv`](../../src/audio.rs) |
| Señales de terminar → salir de Qt | [`musicplayer_handle_signals`](../../src/signals.cpp) |
| Arrastrar en la cola | [`startDrag`](../../qml/QueueList.qml) |

## Dependencias

- **[resolucion](resolucion.md)** (`resolver::*`): URL de cada pista, precarga. Léela si tocas cómo
  se carga una pista.
- **[catalogo](catalogo.md)** (`ytm::queue`, `ytm::playlist_tracks`): colas y canciones.
- **[letra](letra.md)** (`lyrics::fetch`): pedir la letra al empezar.
- **[historial](historial.md)** (`history::start`, `history::watched`): avisos de escucha.
- **[plugins](plugins.md)** (`plugins::emit`, `plugins::media_enabled`): repartir lo que pasa.
- **[sesion](sesion.md)** (`account::cookies_copy`): cookies para el gancho de yt-dlp de mpv.
- El menú de clic derecho de las filas de la cola lo abre `Main.openMenu` ([ventana](ventana.md)).
- **La usan:** [ventana](ventana.md), [vistas](vistas.md), [detalle](detalle.md),
  [letra](letra.md), [catalogo](catalogo.md).

## Estado actual

- **Última verificación:** 2026-11-16 (estilos de la barra con una canción cargada, y cierre de
  mpv ante `kill`; sin audio: YouTube pidió sesión. Ver historial).
- **Pruebas:** ninguna en `player.rs` ni `audio.rs`; se prueban con `--autoplay` y
  `--probe play` ([verificar-reproduccion](../runbooks/verificar-reproduccion.md)).
- **Sin verificar:** MPRIS en GNOME y KDE con Wayland; el «Me gusta» y «Aleatorio» de la barra
  con sesión y música sonando.
- **Historial:** [docs/history/verificacion/reproduccion.md](../history/verificacion/reproduccion.md).

## Pendiente

- Probar si libmpv embebido ahorra memoria frente al proceso ([ROADMAP](../ROADMAP.md)).
