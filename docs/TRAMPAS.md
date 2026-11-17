# Trampas conocidas

Cada línea es un error que ya costó encontrar: el síntoma, la causa y el arreglo. Lee la sección
que toque **antes** de cambiar algo ahí. Una trampa nueva se añade en su sección, en una línea
(con el detalle en la ficha del área si hace falta); cuándo pasó, al
[changelog](history/CHANGELOG-TECNICO.md).

## Compilación y cxx-qt

- **Archivo QML nuevo** → regístralo en `build.rs` (`QML_FILES` o `QML_SINGLETONS`) o QML dirá que
  el tipo no existe. Lo comprueba `scripts/docs.py`.
- **Puente Rust nuevo** → añádelo a `.files([...])` en `build.rs` y como `mod` en `main.rs`.
- **Nombres en QML:** `#[auto_cxx_name]` convierte `snake_case` a `camelCase` (`play_item` →
  `Player.playItem`, `vista_inicio` → `AppSettings.vistaInicio`).
- **Invocables con `&self`** y métodos de la implementación no deben colarse dentro del bloque
  `extern "RustQt"`: el generador falla con «Unsupported verbatim input in ForeignItem».

## Qt Quick y QML

- **`font.pixelSize` es entero:** `12.5` hace fallar la carga del componente entero.
- **No llames `palette`** a una propiedad propia: choca con la de `Item` y QML la ignora.
- **Un `id` tapa una propiedad con el mismo nombre:** en `NowPlayingView`, `art` era a la vez una
  propiedad de la raíz y el `id` de la carátula; en los enlaces de la raíz `art` daba el elemento
  y la cuenta salía `NaN`. Usa `root.art`.
- **Cambiar un índice dentro del aviso de cambio** de la misma propiedad (`onCurrentItemChanged`)
  deja enlaces sin actualizar: aplázalo con `Qt.callLater`.
- **Clics que atraviesan:** un `TapHandler` normal solo toma un agarre pasivo y el clic sigue hacia
  lo de debajo (cerrar «Sonando» abría las opciones). En botones y opciones,
  `gesturePolicy: TapHandler.ReleaseWithinBounds`. Un `MouseArea` debajo no basta.
- **La rueda atraviesa las capas de encima** (Opciones, menú contextual) y desplaza la sección de
  debajo: un `Flickable` que llega al tope, o que no se desplaza, la deja pasar. Debajo de la capa,
  un `MouseArea` con `acceptedButtons: Qt.NoButton` y `onWheel: wheel => wheel.accepted = true`.
- **`Window.window` dentro de un `TapHandler` es `null`** (los gestores no son `Item`): usa el del
  elemento, `delegado.Window.window.openMenu(…)`.
- **Arrastrar dentro de una lista la desplaza** en vez de mover la fila: un `MouseArea` con
  `preventStealing: true` (como `QueueList`).
- **«Hover» sobre algo que se mueve:** un `HoverHandler`, un `MouseArea` con `cursorShape` o un
  `TapHandler` encima de contenido animado obligan a repasar esa parte de la escena en cada
  fotograma. En la letra llevaba la CPU de ~5 % a ~25 %. Un solo gestor para toda la vista, con
  `childAt`, y sin «hover».
- **Rotaciones 3D:** un ángulo positivo en el eje Y aleja el lado **derecho** del eje.
- **Rotaciones 3D grandes** (más de ~70°) acercan la pieza a la cámara y la agrandan: para abrir la
  caja se usa un pliegue plano (`Scale` en X).
- **Máscaras de `MultiEffect`:** sin `maskThresholdMin: 0.5` y `maskSpreadAtMin: 1` la máscara
  recorta en seco en vez de seguir el degradado.
- **`TintProbe` (Canvas):** cada lienzo debe llamar a `loadImage` aunque otro ya tenga la imagen, y
  repintar con su propio `Timer`; si no, la segunda sonda con la misma carátula no pinta. Una sonda
  fuera de la zona visible (recortada) tampoco: usa la de `Main.qml` (`playingProbe`).
- **`Shape` con CurveRenderer no se redibuja** tras liberar los gráficos de la ventana (al ocultarla
  o minimizarla): `Icon.qml` se recrea con un `Loader` cada vez que sube `Theme.renderEpoch`. Una
  `Shape` nueva con ese renderizador necesita lo mismo.
- **`ShapePath.fillItem` no usa el tamaño del elemento:** coloca la textura en la esquina de la
  forma con su tamaño en píxeles físicos (una imagen de 544 px en Retina ocupa 272 px). En una forma
  mayor, el último píxel se repite por la derecha y por abajo (la carátula del panel salía
  «corrida»). Escálala con `fillTransform`, como `Cover.qml`. La captura sin ventana
  (`offscreen`) no pinta el relleno: compruébalo con ventana.
- **Una `ListView` vertical pone cada delegado en x = 0** aunque el delegado diga otra `x`: el
  margen va en `leftMargin` de la lista (el Muro salía pegado al borde).
- **Letra en japonés o chino:** partir la línea por espacios deja una sola «palabra» enorme que se
  encoge en vez de pasar al renglón siguiente, y unir las sílabas con espacios separa los
  caracteres. Cada sílaba lleva `join` y los renglones se parten entre caracteres CJK (`rows` de
  `LyricsView`).

## YouTube, yt-dlp y mpv

- **No castigues a YouTube:** muchas peticiones seguidas y rechaza la IP un rato («Requested format
  is not available», 403, «Sign in to confirm you're not a bot»). Espera y compruébalo con `yt-dlp`
  directamente antes de culparte.
- **mpv y las URLs de googlevideo:** las de yt-dlp dan 403 con el cliente HTTP de mpv y se cargan
  como `lavf://URL` (ffmpeg); las de la vía rápida se atascan con ffmpeg y se cargan tal cual.
  `resolver::run_ytdlp` deja el prefijo puesto según el origen.
- **La vía rápida necesita «visitor data»** (`stream.rs`); sin él YouTube responde `LOGIN_REQUIRED`.
- **yt-dlp sin sesión:** con los clientes por defecto YouTube pide verificación anti-bot en pistas
  de YouTube Music. Se usan `web_embedded,mweb` (`resolver::ytdlp_clients`).
- **yt-dlp con sesión:** solo `web_music` da las pistas reservadas a cuentas y los formatos
  Premium; con `player_skip=webpage,configs` tarda ~1,7 s en vez de ~3 s. Diagnóstico:
  `--probe playable ID` y `--probe account`.
- **yt-dlp reescribe el archivo de `--cookies`** al terminar: nunca le pases el `cookies.txt`
  original, usa `account::cookies_copy`.
- **mpv solo avisa de la pausa cuando cambia:** al empezar una pista se aplica la última conocida
  (`mpv_paused`); si no, «sonando» se queda desfasado.
- **Historial de YouTube Music:** los avisos de escucha necesitan `c=WEB_REMIX`; sin él la canción
  aparece en el historial de YouTube y no en el de YouTube Music.
- **Cola `next` para un álbum:** trae versiones en vídeo, se corta en ~50 y mezcla canciones
  ajenas; se usa la página `VL<id>` ([ADR-06](decisions/ADR-06-canciones-por-la-pagina-de-la-lista.md)).

## macOS y Linux

- **Minimizar no libera memoria gráfica en macOS;** ocultar la ventana sí (`window.cpp`).
- **Apps gráficas en macOS no heredan el `PATH`** de la terminal: `audio::search_path` añade
  `/opt/homebrew/bin` y `/usr/local/bin`.
- **Proxy del sistema:** Qt ignora el proxy de macOS (`window.cpp`); con WPAD roto cada descarga
  fallaba con «NSURLErrorDomain -1003». Se respeta `HTTPS_PROXY`/`HTTP_PROXY`.
- **Inicio de sesión en WebKit:** la prevención de rastreo pierde las cookies en las redirecciones
  de Google y YouTube acaba en `/oops`; se desactiva ([sesion](areas/sesion.md#macos)).
- **Disfrazar el agente de usuario** de Chrome en Qt WebEngine: Google lo bloquea («este navegador
  puede no ser seguro») porque contradice `Sec-CH-UA`.
- **Sockets Unix** admiten ~104 bytes de ruta: en pruebas de Discord usa una ruta relativa corta.

## Medir

- **Mide siempre en release.** Depuración cambia memoria y tiempos.
- **Mide la CPU con tiempo acumulado:** `ps -o time=` al principio y al final de 25 s, y comprueba
  en la línea `estado:` que sonaba la canción esperada (Inicio cambia de una ejecución a otra).
  `ps %cpu` es una foto de un instante y engaña.
- **Memoria con `footprint`**, la que muestra el Monitor de Actividad; cualquier ventana de Qt Quick
  que se redibuje reserva ~100 MB en el controlador gráfico de macOS
  ([ARCHITECTURE](ARCHITECTURE.md#memoria-y-arranque)).
