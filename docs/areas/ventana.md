---
area: ventana
titulo: Ventana y navegación
resumen: Arranque, ventana principal con escenario, navegación superior, panel de letra y cola, pantalla «Sonando», mini reproductor, búsqueda y menú de clic derecho.
archivos: [src/main.rs, src/window.cpp, qml/Main.qml, qml/TopNav.qml, qml/SearchField.qml, qml/NowPlayingPanel.qml, qml/NowPlayingView.qml, qml/MiniPlayer.qml, qml/ContextMenu.qml]
opciones: [panel, sonando, sonandoTitulo, caratulaCalidad]
adr: [ADR-10]
---

# Ventana y navegación

El armazón: lo que aloja las secciones, el panel lateral y las pantallas que se abren encima.
También el arranque del proceso y los argumentos de depuración (`--probe`, `--shot`…).

## Qué hace

- **Navegación superior** en píldoras (`TopNav`) y **búsqueda** (`SearchField`).
- **Panel de letra y cola** a la derecha (por defecto) o a la izquierda (opción `panel`), o
  cerrado; con el panel a la izquierda todo el escenario se desplaza con `stageX`. **Arranca
  oculto**, por petición del propietario (`lyricsOn`), y se abre con su botón de la barra
  (`--panel` lo abre al arrancar, para capturas). En ventanas estrechas se oculta para que quepa
  la navegación.
- **«Sonando»** (`NowPlayingView`): sube desde la barra al pulsar en ella (fuera de los
  controles); carátula grande sobre el fondo ambiente de sus colores, letra y cola. Dos
  disposiciones a elegir en Opciones › Vistas (opción `sonando`), por petición del propietario:
  - **Grande** (por defecto): la carátula sola, sin título (ya está en la barra), todo lo grande
    que deje el alto; a su derecha, letra y cola estrechas (380–460 px) y a la misma altura. El
    conjunto va centrado, con el mismo margen a los dos lados.
  - **Clásica**: la carátula con su título y artista debajo, con el borde derecho algo pasado el
    centro, y letra y cola anchas, del borde de arriba a la barra.

  **Título bajo la carátula** (opción `sonandoTitulo`, Opciones › Vistas), por petición del
  propietario: Automático (por defecto: solo en la Clásica), Siempre o Nunca. En la Grande con
  título, la carátula se encoge lo que ocupa el título (`titleSpace`) para que todo quepa sobre la
  barra.

  Con el fondo «Fluido» ([personalizacion](personalizacion.md)), la letra y la cola van sin
  recuadro, directamente sobre él.

  Sin letra ni cola (botón del panel), la carátula va al centro. Se redondea con `Cover.radius`,
  sin capas.

  **Calidad de la carátula** (opción `caratulaCalidad`, Opciones › Apariencia): **Máxima** (por
  defecto, elegido por el propietario) la pide al tamaño que ocupa en pantalla en píxeles
  físicos, entre 1200 y 2400 px y en escalones de 400 (`bigPixels`); **Alta**, a 1200 px. El
  servidor de carátulas no agranda: si el original es menor (suelen ser de 1400 a 4000 px), llega
  el original. Mientras llega la grande se ve la de la barra (120 px, ya en memoria) ampliada, y
  se suelta en cuanto la grande está a la vista (`Cover.ready`). Las canciones que son vídeos
  (`i.ytimg.com`) piden su fotograma `hq720` (1280×720) en vez de la miniatura pequeña con bandas
  negras; si no lo tienen, queda la miniatura.
- **Mini reproductor**: ventana pequeña siempre encima; la grande se oculta mientras tanto
  ([ADR-10](../decisions/ADR-10-mini-reproductor-oculta-la-ventana.md)).
- **Menú de clic derecho** (`Main.openMenu` → `ContextMenu`) y aviso breve: cola, «Ir al álbum» y
  «Ver artista» (de una canción; «Ver artista» también de un álbum), lista temporal, guardar en
  playlist, categorías (subpáginas `page:<id>`) y portada. «Ir al álbum» y «Ver artista» bajan
  «Sonando» y abren el detalle (`Main.openRelated` → `Library.openRelated`,
  [catalogo](catalogo.md)). El aviso también da el
  resultado del «Me gusta» de la mascota (`Library.gustado`).
- **Panel lateral** (`NowPlayingPanel`): carátula con esquinas redondeadas, pestañas Letra, Cola y
  Temporal; bajo la letra, el mismo pie discreto de retraso que en «Sonando» (`LyricsTiming`, que
  pone la propia `LyricsView`; ver [letra](letra.md)).
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
- **Carátula grande en «Sonando»**: medido el 2026-11-16, pedirla a 2000–2400 px tarda 0,6–1,5 s
  la primera vez (el servidor la redimensiona) frente a ~0,2 s a 1200 px, y pesa de 2 a 4 veces
  más; por eso la vista previa de 120 px y la opción Alta.
- **El menú se recoloca cada vez que cambia su alto** (`anchorPoint`): las entradas se crean
  después de abrirlo y, colocado con el alto anterior, se salía por abajo de la ventana.
- **Una lista larga en el menú** (playlists donde guardar) va en una subpágina, no en el menú
  principal.
- **Precarga al detenerse** (`hint`, `unhint`, `prefetchTimer`): el foco del teclado o el puntero
  (`SectionView.hinted`) sobre un elemento lo precargan a los 250 ms; si el puntero sale antes, no
  se pide nada ([resolucion](resolucion.md)).
- **El fondo de imagen de una skin** se decodifica al tamaño de la ventana en escalones de 256 px:
  redimensionarla no lo vuelve a decodificar a cada píxel.
- **Lo que tapa «Sonando» no se pinta:** con la pantalla arriba del todo
  (`NowPlayingView.covering`), el escenario, el panel lateral (con su letra) y el detalle se ocultan;
  al bajar, la sección recupera el foco del teclado. Los vidrios que desenfocan el escenario
  (Opciones, el menú) lo siguen capturando oculto.
- **El vidrio de la barra, en «Sonando», desenfoca solo su fondo** (`NowPlayingView.backdrop`,
  el ambiente), no la letra ni la carátula: si no, cada paso del barrido de la letra obligaba a
  rehacer el desenfoque de la barra. Por eso el ambiente de «Sonando» va fuera de `sheet`, subiendo
  con ella.

## Cómo funciona

- `main.rs` arranca Qt, o atiende `--probe …` (sin ventana) y `--login …` (la ventana de inicio
  de sesión de macOS, sin Qt).
- `Main.qml` lee sus argumentos de depuración (`args`) para capturas y pruebas: la lista completa
  está en [verificar-interfaz](../runbooks/verificar-interfaz.md#argumentos-de-mainqml).
- `MUSICPLAYER_DEBUG_CLICK` envía clics de ratón de verdad a la ventana.
- `MUSICPLAYER_DEBUG_AUDIO=archivo` hace sonar un archivo local en lugar de cada pista (`Player`):
  con `--play ID`, la misma canción, su cola y su letra aunque YouTube no deje reproducir
  ([medir-rendimiento](../runbooks/medir-rendimiento.md#siempre-la-misma-canción-aunque-youtube-no-deje-reproducir)).

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Ventana lista | ~0,75 s | 2026-11-13, M4 Pro, release |
| Ocultar para el mini reproductor | 213 → 148 MB | 2026-11-13, M4 Pro, release |
| «Sonando» abierta, Grande con cola (1440×900, Retina) | 252–264 MB, igual que la Clásica con dos capas (254–273 MB; ruido ±10 MB) | 2026-11-16, M4 Pro, release |
| «Sonando» sin cola (1440×900, Retina), carátula Máxima (1600 px) frente a Alta (1200 px) | 248–249 MB frente a 243–247 MB (~+4 MB; canciones distintas en cada pasada) | 2026-11-16, M4 Pro, release |

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
| Título bajo la carátula | [`showTitle`](../../qml/NowPlayingView.qml), [`titleSpace`](../../qml/NowPlayingView.qml) |
| Calidad de la carátula de «Sonando» | [`bigPixels`](../../qml/NowPlayingView.qml), [`bigThumb`](../../qml/NowPlayingView.qml) |
| Mini y vuelta | [`showMini`](../../qml/Main.qml), [`restoreFromMini`](../../qml/Main.qml) |
| Entradas del menú | [`entries`](../../qml/ContextMenu.qml), [`run`](../../qml/ContextMenu.qml) |
| Ir al álbum o al artista | [`openRelated`](../../qml/Main.qml) |

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

- **Última verificación:** 2026-11-18, «Ir al álbum» y «Ver artista» en el menú ([historial](../history/verificacion/ventana.md)).
- **Pruebas:** capturas con `--shot` ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** Wayland en CachyOS (panel, desenfoque, mini siempre encima); la carátula
  `hq720` de una canción que es vídeo dentro de la app (solo con `curl`); la vista previa de 120 px
  mientras carga (en las capturas la grande ya estaba); que el teclado vuelva a la sección al
  cerrar «Sonando».
- **Historial:** [docs/history/verificacion/ventana.md](../history/verificacion/ventana.md).

## Pendiente

- Liberar memoria al **minimizar** en macOS: destruir y recrear la ventana, o pasar al mini
  automáticamente ([ROADMAP](../ROADMAP.md)).
