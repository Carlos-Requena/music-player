---
area: letra
titulo: Letra sincronizada
resumen: Letra de LRCLIB, NetEase y Kugou, a elegir, palabra a palabra con los tiempos reales de cada sílaba, al estilo Better Lyrics, con tres calidades y retraso ajustable por canción.
archivos: [src/lyrics.rs, qml/LyricsView.qml, qml/LyricsTiming.qml]
opciones: [letraOrigen, letraSinTiempos, letraCalidad, letraTamano, letraFuente, letraPeso, letraAlineacion, letraAnimada, retraso:*, origen:*]
adr: [ADR-13, ADR-18]
---

# Letra sincronizada

Pestaña «Letra» del panel lateral y de «Sonando». El aspecto se elige en Opciones › Apariencia; el
retraso, bajo la propia letra.

## Qué hace

- **Tres fuentes** a la vez, sin cuenta: LRCLIB, NetEase y Kugou (estas dos, con mucho anime y
  J-pop y el tiempo de cada sílaba). **Origen** (Opciones › Apariencia, `letraOrigen`): Automática (por defecto: la que
  encaja con la duración de la pista y trae tiempos por palabra), LRCLIB, NetEase o Kugou. En cada
  canción, el nombre de la fuente va en el pie («· NetEase ↻», **diseño A** elegido por el
  propietario entre tres): pulsarlo pasa a la siguiente que tenga letra y lo recuerda para esa
  canción (`origen:<videoId>`).
- La línea que suena, entera y brillante; las palabras se iluminan con un barrido que sigue el
  tiempo real de cada palabra o sílaba (y su duración); las líneas vacías son pausas
  instrumentales (y la intro larga también, y un hueco de más de 4 s entre líneas de NetEase o
  Kugou).
- **Líneas sin tiempo por palabra** (`letraSinTiempos`): por defecto se iluminan **enteras de
  golpe** (lo eligió el propietario: el barrido inventado no encajaba con la voz); «Estimado»
  reparte el barrido por toda la línea, carácter a carácter en japonés y chino.
- Japonés y chino no llevan espacios inventados entre sílabas; el renglón se parte entre dos
  caracteres cualesquiera, pero nunca entre las sílabas de una palabra latina.
- **Calidad** (`letraCalidad`): «Calidad» (barrido y brillo a 60 Hz, también en pantallas de
  120 Hz), «Equilibrado» (a 30 Hz, por defecto) y «Bajo» (10 Hz, sin cascada ni brillo, y los
  puntos de las pausas quietos).
- **Tamaño, fuente y grosor** (`letraTamano`, `letraFuente`, `letraPeso`) y animación
  (`letraAnimada`).
- **Alineación** (`letraAlineacion`): centrada (por defecto, la pidió el propietario), con cada
  renglón centrado en su zona, o a la izquierda. Las palabras se reparten en renglones según su
  ancho medido (`rows`) y cada renglón es un `Row`: un `Flow` no sabe centrar renglón a renglón.
  Centrada, la línea que suena va también en el centro vertical (`anchorRatio` 0,5; a la
  izquierda, al 37 % como Better Lyrics), y la letra nunca deja hueco arriba: al empezar llena la
  zona desde arriba y la línea que suena baja hasta el centro.
- **Retraso por canción** (`retraso:<videoId>`): «−» la adelanta y «+» la atrasa medio segundo;
  pulsar el texto la vuelve a poner en hora. Positivo: la letra va más tarde. Es un **pie
  discreto** centrado bajo la letra (`LyricsTiming`, diseño B elegido por el propietario entre
  cuatro): solo texto tenue «−  letra en hora  +», sin cápsula ni bordes; con retraso se ilumina y
  dice cuánto («Letra −0,5 s»). Lo pone la propia `LyricsView` (`showTiming`) en «Sonando» y en el
  panel lateral, y la letra se recorta encima de él.

## Reglas y decisiones

- **Varias fuentes pedidas a la vez; elige la interfaz**
  ([ADR-18](../decisions/ADR-18-letra-de-varias-fuentes.md)): `Player.lyrics` lleva todas las
  letras encontradas, de mejor a peor (`rank`), y `Catalog.lyricsChosen` escoge. Cada fuente se
  publica en cuanto llega; las respuestas de una pista anterior se descartan (`lyrics_token`).
- **La versión importa:** de cada búsqueda gana el resultado con la duración más parecida (la
  versión de TV o un videoclip con intro no encajan). Sin título parecido solo vale con la
  duración casi exacta (el título de YouTube puede ir en romaji y la fuente, en japonés). El
  título se limpia antes (`clean_title`: 『』, 「」, paréntesis, «-TV ver.-», el artista delante).
- **Créditos fuera:** NetEase y Kugou ponen «作词: …» o «Composed by: …» como primeras líneas;
  `without_credits` las quita.
- **Un solo gestor de clics para toda la vista**, que calcula la línea con `childAt`, y **sin
  «hover»**: un gestor por línea sobre contenido animado subía la CPU a ~25 %
  ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- **El brillo es una copia desenfocada detrás**, no un `layer.effect` sobre la línea (el texto
  pasaría por una textura y se vería borroso). **Sin medios píxeles** en la elevación de las
  palabras: también emborronan.
- **Un solo reloj** (`clock`) mueve el barrido, el brillo (`glow`) y los puntos de las pausas: a
  60 Hz como tope en «Calidad» (`FrameAnimation` acumula los fotogramas de una pantalla de
  120 Hz), a 30 Hz en «Equilibrado» y a los 10 pasos de mpv en las pausas. Una animación propia
  (`NumberAnimation`, `SequentialAnimation`) va a la frecuencia de la pantalla y redibuja la
  ventana entera con su vidrio: solo la llevan la cascada y el cambio de tamaño y de opacidad al
  pasar de línea.
- **El brillo desenfoca una instantánea** de la línea (`glowSource`, `live: false`), rehecha al
  encenderse la línea y cada vez que empieza a iluminarse una palabra (`litWords`), no la línea
  viva: con ella viva, cada paso del barrido la volvía a copiar y desenfocar.
- **La letra solo existe mientras se ve:** las dos `LyricsView` (panel y «Sonando») van en un
  `Loader` asíncrono; una letra por sílabas son miles de objetos.
- **Se pide una sola vez por canción:** al pulsar una tarjeta, `Player` espera a la cola (que trae
  el artista limpio y la duración) para pedirla (`defer_lyrics`); si la cola falla, la pide con
  los datos de la tarjeta. `Catalog.lyricsChosen` solo cambia si cambia la fuente: cada fuente
  que llega o cada opción que se toca no reconstruyen la letra.
- **Texto sin `Text.CurveRendering`** en «Calidad»: costaba ~95 MB más.
- **Ninguna palabra se sale de su línea:** una más ancha que la línea (en un recuadro estrecho,
  como «supercalifragilisticexpialidocious») se encoge hasta caber; las demás conservan su tamaño.
  Su ancho a tamaño completo lo mide una sola `FontMetrics` común (`metrics`): deducirlo del ancho
  pintado creaba un bucle de enlaces. En «Sonando», el tamaño base baja con el ancho del recuadro
  (`width / 12`, de 24 a 34).
- El retraso lo guardan `Catalog.lyricsDelay` y `Catalog.setLyricsDelay`; `Catalog.lyricsTime` da
  la posición corregida.

## Medidas

CPU acumulada de la app en 25 s, de los 12 a los 37 s de «紅蓮華» (letra de NetEase con tiempo
por sílaba), dos pasadas por caso (×4 = % de un núcleo); memoria con `footprint`. 2026-11-16, M4
Pro con pantalla ProMotion, ventana 1440×900 en Retina, release, audio local
([método](../runbooks/medir-rendimiento.md#siempre-la-misma-canción-aunque-youtube-no-deje-reproducir)):

| | Panel lateral | «Sonando» (con el panel activado) | Memoria |
|---|---|---|---|
| Calidad (60 Hz) | 5,2–5,4 s | 6,5–6,7 s | 375–383 MB |
| Equilibrado (30 Hz) | 3,2–3,7 s | 3,1–3,5 s | 373–384 MB |
| Referencia: pestaña Cola del panel | 0,3 s | — | 318–335 MB |

- Lo que queda es redibujar la ventana entera 30 o 60 veces por segundo mientras se canta; el
  brillo, el vidrio de la barra y la otra letra ya no añaden trabajo a cada fotograma.
- La memoria de estas pasadas es más alta que la de [ARCHITECTURE](../ARCHITECTURE.md#memoria-y-arranque)
  porque el `HOME` de pruebas no tiene la copia de las secciones y Inicio llega de la red con sus
  carátulas; para comparar, mira la diferencia entre filas.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/lyrics.rs` | Fuentes (LRCLIB, NetEase, Kugou), elección del resultado y lectura de LRC, YRC y KRC |
| `qml/LyricsView.qml` | La vista de la letra |
| `qml/LyricsTiming.qml` | Ajuste del retraso y fuente de la letra |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Pedir la letra a una fuente | [`fetch`](../../src/lyrics.rs) |
| Pedirla a todas a la vez | [`fetch_lyrics`](../../src/player.rs) |
| Ordenar las fuentes | [`rank`](../../src/lyrics.rs) |
| Elegir el resultado de una búsqueda | [`best`](../../src/lyrics.rs) |
| Limpiar el título de YouTube | [`clean_title`](../../src/lyrics.rs) |
| Leer el LRC | [`parse`](../../src/lyrics.rs) |
| Leer KRC y YRC | [`parse_timed`](../../src/lyrics.rs) |
| Descifrar el KRC de Kugou | [`decrypt_krc`](../../src/lyrics.rs) |
| Fuente que se muestra | [`lyricsChosen`](../../qml/Catalog.qml) |
| Cambiar de fuente | [`nextLyricsSource`](../../qml/Catalog.qml) |
| Tiempos de cada palabra | [`timing`](../../qml/LyricsView.qml) |
| Pausa larga de la intro | [`INTRO_GAP`](../../src/lyrics.rs) |
| Línea bajo el clic | [`lineUnder`](../../qml/LyricsView.qml) |
| Reloj del barrido | [`advance`](../../qml/LyricsView.qml) |
| Brillo de la línea activa | [`glow`](../../qml/LyricsView.qml), [`glowSource`](../../qml/LyricsView.qml) |
| Elegir la fuente sin rehacer la letra | [`chooseLyrics`](../../qml/Catalog.qml) |
| Pedir la letra cuando llega la cola | [`defer_lyrics`](../../src/player.rs) |
| Retraso guardado | [`setLyricsDelay`](../../qml/Catalog.qml) |

## Dependencias

- **[reproduccion](reproduccion.md)** (`Player.position`, `Player.seek`): posición y saltar a una
  línea.
- **[catalogo](catalogo.md)** (`Catalog.lyrics`, `Catalog.lyricsTime`): la letra ya convertida y el
  retraso.
- **[personalizacion](personalizacion.md)** (`AppSettings`): las opciones de aspecto.
- **La usan:** [ventana](ventana.md) (el panel y «Sonando»).

## Estado actual

- **Última verificación:** 2026-11-16, menos CPU en la letra: medida antes y después en «Calidad»
  y «Equilibrado», en el panel y en «Sonando», y capturas del barrido con su brillo
  ([historial](../history/verificacion/letra.md)).
- **Pruebas:** `mod tests` de `src/lyrics.rs` (pausas e intro, LRC con palabras, KRC y YRC,
  créditos, limpieza del título, elección por duración, orden de las fuentes).
- **Sin verificar:** el barrido con el audio real de YouTube (pedía sesión: se midió con un audio
  local, con la misma posición y la misma letra); que la cascada y el brillo se vean igual de
  fluidos a la vista (las capturas son fotos fijas); «Bajo» después de los cambios; el coste de
  cada modo en Linux con el controlador de CachyOS.
- **Historial:** [docs/history/verificacion/letra.md](../history/verificacion/letra.md).

## Pendiente

- Traducción y romaji: NetEase y Kugou los traen y no se muestran.
- Lo que queda de CPU en «Calidad» es redibujar la ventana entera a 60 Hz: bajarlo pide no
  redibujar lo que no cambia (Qt Quick no lo hace por zonas).
