---
area: ventana
titulo: Ventana y navegación
resumen: Arranque, ventana principal con escenario, navegación superior, panel de letra y cola, pantalla «Sonando», mini reproductor, búsqueda y menú de clic derecho.
archivos: [src/main.rs, src/window.cpp, qml/Main.qml, qml/TopNav.qml, qml/SearchField.qml, qml/NowPlayingPanel.qml, qml/NowPlayingView.qml, qml/MiniPlayer.qml, qml/ContextMenu.qml]
opciones: [panel]
adr: [ADR-10]
---

# Ventana y navegación

El armazón: lo que aloja las secciones, el panel lateral y las pantallas que se abren encima.
También el arranque del proceso y los argumentos de depuración (`--probe`, `--shot`…).

## Qué hace

- **Navegación superior** en píldoras (`TopNav`) y **búsqueda** (`SearchField`).
- **Panel de letra y cola** a la derecha (por defecto) o a la izquierda (opción `panel`), o
  cerrado; con el panel a la izquierda todo el escenario se desplaza con `stageX`. En ventanas
  estrechas se oculta para que quepa la navegación.
- **«Sonando»** (`NowPlayingView`): sube desde la barra al pulsar en ella (fuera de los controles); carátula grande sobre
  el fondo ambiente de sus colores, letra y cola.
- **Mini reproductor**: ventana pequeña siempre encima; la grande se oculta mientras tanto
  ([ADR-10](../decisions/ADR-10-mini-reproductor-oculta-la-ventana.md)).
- **Menú de clic derecho** (`Main.openMenu` → `ContextMenu`) y aviso breve: cola, lista temporal,
  guardar en playlist, categorías (subpáginas `page:<id>`) y portada. El aviso también da el
  resultado del «Me gusta» de la mascota (`Library.gustado`).
- **Panel lateral** (`NowPlayingPanel`): carátula con esquinas redondeadas, pestañas Letra, Cola y
  Temporal y, bajo la letra, un pie fijo con su separador para el retraso de la canción («Letra en
  hora», `− 0,0 s +`; pulsar la cifra la pone a cero).
- **Barra de reproducción**: su alto (`barHeight`) sale de `Theme.barHeight`: 84 px en el estilo
  Clásica y 64 en los demás ([reproduccion](reproduccion.md)).
- **Mascota** (`mascotLoader`): sobre el borde izquierdo de la barra; con las opciones abiertas, en
  la esquina inferior izquierda de su panel (`SettingsSheet.panel`) ([mascotas](mascotas.md)).

## Reglas y decisiones

- **Ventana de vidrio con la navegación superior**, preferencia del propietario
  ([AGENTES §11](../AGENTES.md#11-cómo-trabajar-con-el-propietario)).
- **Ocultar libera la memoria gráfica; minimizar no** (en macOS Qt conserva los búferes):
  `window.cpp` libera el grafo de escena de las ventanas ocultas.
- **Al volver de oculta**, `Theme.renderEpoch` sube para recrear los iconos
  ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- **Proxy:** Qt ignora el proxy de macOS; `window.cpp` respeta `HTTPS_PROXY`/`HTTP_PROXY`.
- **Una lista larga en el menú** (playlists donde guardar) va en una subpágina, no en el menú
  principal.

## Cómo funciona

- `main.rs` arranca Qt, o atiende `--probe …` (sin ventana) y `--login …` (la ventana de inicio
  de sesión de macOS, sin Qt).
- `Main.qml` lee sus argumentos de depuración (`args`) para capturas y pruebas: la lista completa
  está en [verificar-interfaz](../runbooks/verificar-interfaz.md#argumentos-de-mainqml).
- `MUSICPLAYER_DEBUG_CLICK` envía clics de ratón de verdad a la ventana.

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Ventana lista | ~0,75 s | 2026-11-13, M4 Pro, release |
| Ocultar para el mini reproductor | 213 → 148 MB | 2026-11-13, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `src/main.rs` | Arranque de Qt, `--probe` y `--login` |
| `src/window.cpp` | C++: liberar gráficos de ventanas ocultas, red y proxy |
| `qml/Main.qml` | Ventana: escenario, navegación, panel, barra, opciones, argumentos de depuración |
| `qml/TopNav.qml` | Pestañas de la navegación |
| `qml/SearchField.qml` | Campo de búsqueda |
| `qml/NowPlayingPanel.qml` | Panel lateral: carátula, letra, cola, lista temporal |
| `qml/NowPlayingView.qml` | Pantalla «Sonando» |
| `qml/MiniPlayer.qml` | Mini reproductor |
| `qml/ContextMenu.qml` | Menú de clic derecho y aviso |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Sondas sin ventana | [`probe`](../../src/main.rs) |
| Liberar gráficos al ocultar | [`musicplayer_tune_windows`](../../src/window.cpp) |
| Proxy y red | [`musicplayer_configure_network`](../../src/window.cpp) |
| Abrir el menú | [`openMenu`](../../qml/Main.qml) |
| Argumentos de depuración | [`arg`](../../qml/Main.qml) |
| Mini y vuelta | [`showMini`](../../qml/Main.qml), [`restoreFromMini`](../../qml/Main.qml) |
| Entradas del menú | [`entries`](../../qml/ContextMenu.qml), [`run`](../../qml/ContextMenu.qml) |

## Dependencias

- **[vistas](vistas.md)** (`SectionView`): las secciones.
- **[detalle](detalle.md)** (`DetailView`, `InspectView`): lo que se abre encima.
- **[reproduccion](reproduccion.md)** (`Player`, `PlayerBar`, `QueueList`): la barra, la cola y lo
  que suena.
- **[letra](letra.md)** (`LyricsView`, `LyricsTiming`): la pestaña Letra.
- **[catalogo](catalogo.md)** (`Catalog`, `Library`, `CategoryBar`): secciones, búsqueda y
  categorías.
- **[personalizacion](personalizacion.md)** (`AppSettings`, `SettingsSheet`, `Ambient`,
  `TintProbe`): opciones, modo ambiente y color de lo que suena (`playingProbe`).
- **[mascotas](mascotas.md)** (`Mascot`): la mascota, su aviso al navegar (`browsed`) y su sitio
  en la barra o en Opciones.
- **[resolucion](resolucion.md)** (`resolver`, `stream`, `daemon` en `--probe`): las sondas sin
  ventana.
- **[sesion](sesion.md)** (`Account`, `login_window`): la cuenta y la ventana de macOS.
- **[plugins](plugins.md)** (`Plugins`): arranque de los plugins.
- **La usan:** ninguna (es la raíz).

## Estado actual

- **Última verificación:** 2026-11-16, panel con letra cargada y barra nueva, captura
  ([historial](../history/verificacion/ventana.md)).
- **Pruebas:** capturas con `--shot` ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** Wayland en CachyOS (panel, desenfoque, mini siempre encima).
- **Historial:** [docs/history/verificacion/ventana.md](../history/verificacion/ventana.md).

## Pendiente

- Liberar memoria al **minimizar** en macOS: destruir y recrear la ventana, o pasar al mini
  automáticamente ([ROADMAP](../ROADMAP.md)).
