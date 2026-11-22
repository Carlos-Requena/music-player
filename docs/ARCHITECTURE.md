# Arquitectura

Cómo encajan las piezas. El detalle de cada una (reglas, mecanismo, medidas) está en su ficha de
[docs/areas/](areas/); aquí solo lo que es de todo el programa.

## Piezas y procesos

```
┌──────────────────── proceso musicplayer ─────────────────────┐
│  QML (Qt Quick, Metal/Vulkan)                                 │
│    Main.qml · vistas · panel · barra · opciones               │
│        │ propiedades y llamadas (cxx-qt)                      │
│  Rust                                                         │
│    Library ── ytm.rs ──────────── HTTPS → music.youtube.com   │
│      └─ listenbrainz.rs ─ hilo ── HTTPS → api.listenbrainz.org│
│    Player ─┬─ ytm.rs (colas)                                  │
│            ├─ resolver.rs ─┬─ stream.rs ─ HTTPS → /player     │
│            │               └─ yt-dlp (residente o proceso)    │
│            ├─ lyrics.rs ───────── HTTPS → lrclib.net          │
│            ├─ history.rs ──────── HTTPS → avisos de escucha   │
│            ├─ plugins.rs ─ hilo ─→ Discord · Last.fm · LB     │
│            └─ audio.rs ── socket IPC JSON ─┐                  │
│    Account ── cookies.txt · firma          │                  │
│    AppSettings ── settings.json            │                  │
└────────────────────────────────────────────┼─────────────────┘
                                             ▼
                              proceso mpv (--idle, sin vídeo)

Procesos de un momento: musicplayer --login (macOS) · musicplayer-login (Linux, Windows)
```

| Área | Qué parte del dibujo |
|---|---|
| [catalogo](areas/catalogo.md) | `Library`, `ytm.rs`, `Catalog.qml` |
| [resolucion](areas/resolucion.md) | `resolver.rs`, `stream.rs`, yt-dlp |
| [reproduccion](areas/reproduccion.md) | `Player`, `audio.rs`, mpv |
| [letra](areas/letra.md) · [historial](areas/historial.md) · [plugins](areas/plugins.md) | Lo que cuelga de `Player` |
| [sesion](areas/sesion.md) | `Account` y las ventanas de inicio de sesión |
| [personalizacion](areas/personalizacion.md) | `AppSettings`, `Theme`, skins |
| [ventana](areas/ventana.md) · [vistas](areas/vistas.md) · [detalle](areas/detalle.md) · [mascotas](areas/mascotas.md) · [interfaz-comun](areas/interfaz-comun.md) | La interfaz |

Las decisiones que dan forma al dibujo: [ADR-01](decisions/ADR-01-qt-qml-y-rust.md) (Qt/QML y
Rust), [ADR-02](decisions/ADR-02-mpv-en-proceso-aparte.md) (mpv aparte),
[ADR-07](decisions/ADR-07-inicio-de-sesion-en-proceso-aparte.md) (inicio de sesión aparte),
[ADR-24](decisions/ADR-24-version-de-windows.md) (Windows: tuberías con nombre en vez de sockets,
WebView2 e instalador).

## Hilos

El hilo de Qt solo pinta y responde. Red, yt-dlp, disco y la lectura del socket de mpv van en
hilos propios y devuelven resultados con `qt_thread().queue(...)`, que ejecuta el cierre en el hilo
de Qt con acceso al objeto. Los plugins tienen su hilo (`plugins::worker`). Cada petición lleva un
contador (`request`, `load_token`, `search_request`) y su respuesta se descarta si ya no es la
última.

## El puente Rust ↔ QML

- Cada singleton es un `#[cxx_qt::bridge]` con sus `#[qproperty]` y `#[qinvokable]`; los nombres
  pasan a `camelCase` en QML. Están en `.files([...])` de `build.rs` y los QML en `QML_FILES` y
  `QML_SINGLETONS` (módulo `app.musicplayer`).
- **Datos estructurados, como JSON** en una propiedad `QString`
  ([ADR-04](decisions/ADR-04-json-hacia-qml.md)): `Library` publica secciones, búsqueda y detalle;
  `Player`, la cola y la letra. `Catalog.qml` los convierte una vez por cambio.
- C++ propio solo donde Qt lo exige (`window.cpp`) y Objective-C++ para la ventana de macOS
  (`login_mac.mm`, compilado con `cc`).

Explicado desde cero, con el código: [GUIA §5](GUIA.md#5-el-puente-rust--qml-cxx-qt).

## De clic a sonido

1. La vista emite `activated(item)` y `Main.qml` llama a `Player.playItem(json)`
   ([reproduccion](areas/reproduccion.md)).
2. `Player` pide la URL a `resolver` ([resolucion](areas/resolucion.md)): si está precargada suena
   en 64–254 ms; si no, la vía rápida tarda ~0,4–0,6 s.
3. mpv avisa por IPC; `Player` publica el estado, pide la letra ([letra](areas/letra.md)) y avisa
   al historial y a los plugins, sin esperarles.

## Memoria y arranque

macOS, ventana 1440×900 en pantalla Retina, release, Apple M4 Pro, medido con `footprint` (la
memoria que muestra el Monitor de Actividad), 2026-11-13:

| Caso | Memoria |
|---|---|
| Ventana Qt vacía y quieta (control, sin nuestro código) | 93 MB |
| Ventana Qt vacía con **cualquier** redibujado, de 1 a 30 por segundo (control) | 178–247 MB |
| La app, Inicio cargado, sin reproducir | 187 MB |
| La app reproduciendo, con panel de letra | 300–330 MB, estable en el tiempo |
| Proceso mpv en reposo / reproduciendo | 20 MB / ~75 MB |

- **Lo que más pesa no es nuestro código.** En cuanto una ventana de Qt Quick se redibuja de forma
  continua (la barra de progreso y la letra lo hacen mientras suena), el controlador gráfico de
  macOS reserva ~100 MB para sus fotogramas. Lo hace una ventana vacía con un cuadrado de 2 px
  girando. Con OpenGL en vez de Metal es el doble.
- Lo que añade la app sobre ese mínimo (~130 MB reproduciendo): carátulas, la letra, el vidrio de
  la barra, el motor QML y el JSON del catálogo.
- Las medidas de cada área (arranque de pista, letra, Lomos, mini reproductor, yt-dlp residente)
  están en la sección «Medidas» de su ficha.
- **Arranque:** ventana lista en ~0,75 s y contenido con carátulas a los 300 ms gracias a la caché
  de secciones ([ADR-09](decisions/ADR-09-cache-de-secciones-en-disco.md)).
- Para comparar: Pear Desktop o una pestaña de YouTube Music en Chrome suelen pasar de 500 MB a
  1 GB sumando sus procesos (estimación, no medida en esta máquina).

## Dónde guarda cosas

| Ruta | Qué | Área |
|---|---|---|
| `<config>/musicplayer/settings.json` | Vistas, skin, mascota, opciones | [personalizacion](areas/personalizacion.md) |
| `<config>/musicplayer/cookies.txt`, `account.json` | Sesión (permisos 600) | [sesion](areas/sesion.md) |
| `<config>/musicplayer/plugins.json` | Discord, Last.fm y ListenBrainz (permisos 600) | [plugins](areas/plugins.md) |
| `<config>/musicplayer/skins/`, `mascotas/` | Skins y mascotas del usuario | [personalizacion](areas/personalizacion.md), [mascotas](areas/mascotas.md) |
| `<caché>/musicplayer/` | Copia de cada sección y búsquedas de ListenBrainz en YouTube (`listenbrainz-youtube.json`) | [catalogo](areas/catalogo.md) |

`<config>` es `~/Library/Application Support` en macOS, `~/.config` en Linux y `%APPDATA%` en
Windows; `<caché>`, `~/Library/Caches`, `~/.cache` y `%LOCALAPPDATA%`. **Son datos del propietario**: no se tocan en pruebas
([AGENTES §7](AGENTES.md#7-norma-los-datos-del-propietario-no-se-tocan)).
