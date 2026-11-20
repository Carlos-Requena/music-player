# Historial de verificación · Ventana y navegación

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/ventana.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-20 · Carátula animada de Apple Music en «Sonando» (rama `feature/caratula-animada`)

- **Cambio:** `src/animada.rs`, `Player.animada` y `Player.buscarAnimada`, `qml/MotionCover.qml`,
  `shaders/redondeo.frag`, opción `caratulaAnimada` y `--probe animada`. Dependencia nueva: Qt
  Multimedia (`qtmultimedia` / `qt6-multimedia`) y `ffmpeg`.
- **Verificado:** `--probe animada` encuentra y descarga el vídeo de *DELTARUNE Piano Collections,
  Vol. 1* (20 s, 960×960, 6,4 MB, 1,5–2,7 s la primera vez, al instante después), tanto con el
  artista de Apple como con el de YouTube Music («Toby Fox», por el álbum); dos capturas de
  «Sonando» separadas 1,5 s muestran fotogramas distintos con las esquinas redondeadas; la fila
  en Opciones › Apariencia. Medida en release (ficha, «Medidas»). Tests de `animada.rs`.
- **No verificado:** Linux; la app empaquetada (`crear-app-macos.sh`); qué pasa sin Qt
  Multimedia instalado (debería fallar solo el `Loader`); la disposición Clásica; un álbum sin
  carátula animada dentro de la app (solo con `--probe`).

## 2026-11-18 · «Ir al álbum» y «Ver artista» en el menú (rama `feature/artista-y-ecualizador`)

- **Cambio:** dos entradas nuevas en `ContextMenu` (iconos `Theme.iconAlbum` e `iconArtist`),
  `Main.openRelated`, y el menú se recoloca al cambiar su alto (`anchorPoint`).
- **Verificado:** capturas con clics de verdad (`MUSICPLAYER_DEBUG_CLICK`): el menú de una canción
  de la búsqueda cabe entero en la ventana y sus dos entradas abren el álbum y el artista.
- **No verificado:** el menú desde la cola de «Sonando»; Linux.

## 2026-11-17 · Precarga al detenerse el puntero y fondo de skin en escalones (rama `perf/letra`)

- **Cambio:** `hint` y `unhint`: el foco o el puntero precargan a los 250 ms, nada si el puntero
  sale antes. El fondo de imagen de una skin se decodifica en escalones de 256 px. Las pestañas de
  «Sonando» y del panel son `TabStrip`.
- **Verificado:** capturas del panel (pestaña Cola) y de «Sonando» sin errores de QML.
- **No verificado:** la precarga al pasar el ratón (sin audio real); una skin con fondo.

## 2026-11-16 · Lo que tapa «Sonando» no se pinta (rama `perf/letra`)

- **Cambio:** con «Sonando» arriba del todo (`NowPlayingView.covering`) se ocultan el escenario,
  el panel lateral y el detalle; al bajar, la sección recupera el foco. El vidrio de la barra
  desenfoca solo el ambiente de «Sonando» (`NowPlayingView.backdrop`, fuera de `sheet`). La letra
  de «Sonando» y la del panel van en un `Loader`. Arnés: `--play ID [--play-title texto]` y
  `MUSICPLAYER_DEBUG_AUDIO`.
- **Verificado:** «Sonando» con el panel, Equilibrado: 6,0 s → 3,1–3,5 s de CPU en 25 s
  ([letra](letra.md)); capturas de «Sonando» con la letra y de Opciones encima (el escenario
  oculto se sigue viendo desenfocado detrás, como antes).
- **No verificado:** que el teclado vuelva a la sección al cerrar «Sonando» (no hay forma de
  simular teclas en las capturas); la subida y la bajada a la vista; Linux.

## 2026-11-16 · El menú contextual no deja pasar clics ni rueda; rueda simulada

- **Cambio:** fuera del menú, un `TapHandler` con agarre exclusivo que lo cierra y un `MouseArea`
  que se queda la rueda; en el menú, lo mismo sin cerrar. `MUSICPLAYER_DEBUG_CLICK` acepta
  `x,y,wheel,ms,pasos` (`window.cpp`). Rama `fix/clics-y-barra` (el menú ya iba en «Cambios
  extras»).
- **Verificado:** con la versión de `8dd106b`, la rueda sobre el menú y fuera de él desplazaba la
  sección de debajo; ahora no. Clic izquierdo y derecho fuera del menú: lo cierran sin enfocar ni
  abrir otro menú en la tarjeta de debajo (esto ya pasaba antes en estas pruebas).
- **No verificado:** el clic que atraviesa «a veces» que vio el propietario no se reprodujo con
  clics simulados; trackpad; Linux.

## 2026-11-16 · Carátula de «Sonando» a máxima calidad y título opcional

- **Cambio:** opción `caratulaCalidad` (Máxima por defecto, Alta = 1200 px como antes), vista
  previa de 120 px mientras llega la grande, `hq720` para las canciones que son vídeos, y opción
  `sonandoTitulo` (Automático, Siempre, Nunca). Rama `feature/personalizacion-fondo-plano`.
- **Medido con `curl`:** cinco carátulas reales: originales de 1400 a 4000 px; a 1200 px ~0,2 s y
  190–370 KB; a 2400 px 0,6–1,5 s la primera vez y 300–860 KB; `hq720` de un vídeo, 1280×720 y
  ~0,2 s frente a `hqdefault` de 480×360 con bandas.
- **Verificado:** capturas de «Sonando» en Máxima y Alta (la grande se ve nítida), Grande con
  título y Clásica sin él, y Opciones › Vistas. Memoria en release (1440×900, Retina): Máxima
  248–249 MB, Alta 243–247 MB, con canciones distintas en cada pasada (YouTube cambiaba Álbumes).
- **No verificado:** que suene (YouTube pedía iniciar sesión, «LOGIN_REQUIRED», en todas las
  pruebas sin sesión; no se tocó la reproducción); `hq720` dentro de la app; la vista previa a
  mitad de carga; Linux.

## 2026-11-16 · «Sonando» en dos disposiciones (Grande y Clásica)

- **Cambio:** opción `sonando` (Opciones › Vistas). Grande, por defecto: carátula sola y más
  grande, letra y cola estrechas (380–460 px) a su altura, conjunto centrado con el mismo margen a
  los dos lados. Clásica: la de antes, con título y letra ancha. La carátula se redondea con
  `Cover.radius` en vez de una capa con máscara.
- **Verificado:** capturas en Retina (1440×900) de Grande con cola, con letra
  («Supercalifragilisticexpialidocious») y sin panel; de Clásica con letra; y de Opciones › Vistas.
  Memoria con «Sonando» abierta: 252–264 MB en la rama frente a 254–273 MB en `master` (ruido
  ±10 MB), con la app del propietario abierta a la vez.
- **No verificado:** Linux, ventanas estrechas (la letra tiene 380 px como mínimo), la transición
  al cambiar la opción con «Sonando» abierta.

## 2026-11-16 · El panel de letra y cola arranca oculto

- **Cambio:** `lyricsOn` empieza en `false` (lo pidió el propietario); el argumento de depuración
  `--no-panel` pasa a ser `--panel`, que lo abre al arrancar.
- **Verificado:** nada todavía (falta compilar y capturar con y sin `--panel`).
- **No verificado:** Linux.

## 2026-11-16 · Panel lateral y barra más baja

- **Cambio:** `barHeight` de 84 a 64; en el panel, carátula redondeada y pie fijo del retraso de la
  letra con separador.
- **Verificado:** captura con «Creep» cargada y su letra: pie «Letra en hora · − 0,0 s +» bajo la
  letra, carátula con esquinas redondas.
- **No verificado:** el panel a la izquierda; ventanas estrechas (la isla central ocupa el hueco).

## 2026-11-15 · Mascota en Opciones y aviso del «Me gusta»

`mascotLoader` sigue a `SettingsSheet.panel` con las opciones abiertas; `ContextMenu` avisa del
resultado de `Library.gustado`. Captura con `--settings --settings-cat apariencia`: la mascota en la
esquina inferior izquierda del panel y fuera de la barra. El aviso del «Me gusta» no se vio (no
llegó a sonar nada).

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
