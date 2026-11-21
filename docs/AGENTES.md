# Guía para agentes y colaboradores

Normas obligatorias para cualquier agente (o persona) que trabaje en este repositorio. Las
secciones marcadas como **norma** no son sugerencias. La guía es corta a propósito: el detalle
está en el documento que toca, y la sección 2 dice cuál.

---

## 1. Qué es

Cliente de YouTube Music para macOS y Linux (CachyOS): interfaz **Qt 6 / QML**, núcleo **Rust**
unido a QML con **cxx-qt 0.10**, audio con **mpv** (proceso aparte, por IPC) y URLs de audio con
la vía rápida de `/player` o **yt-dlp**. Sin Electron ni navegador embebido.

**Prioridades del propietario, en este orden:** consumo bajo de memoria · respuesta instantánea ·
personalización total (vistas, disposición, skins) · estética cuidada. Ante un conflicto entre
ellas, gana la primera, y se le explica.

**Idioma (norma):** todo en **español**: textos de la interfaz, comentarios, documentación y
mensajes de commit. Los identificadores siguen el idioma del archivo (`vista_inicio`, `play_item`).

---

## 2. Norma: leer solo lo necesario

No cargues toda la documentación. Para tocar un área basta con **su ficha** de
[docs/areas/](areas/): qué hace, sus reglas, sus archivos («Dónde está cada cosa» lleva a los
símbolos) y si depende de otra. ¿No sabes de qué área es un archivo? La tabla
[archivo → área](INDEX.md#archivo--área) de INDEX. Para lo demás (un procedimiento, una
trampa, el porqué de una decisión), el mapa [por tarea](INDEX.md#por-tarea).

Antes de tocar Qt, cxx-qt, mpv o YouTube, lee **la sección de [TRAMPAS.md](TRAMPAS.md)** que
toque: cada línea es un error que ya costó horas.

---

## 3. Comandos

```bash
cargo build                     # depuración
cargo build --release           # para medir memoria y tiempos: mide siempre en release
cargo run --release
cargo test                      # pruebas de Rust (cookies, firmas, Discord, Last.fm, letra…)
python3 scripts/docs.py check   # comprueba la documentación (norma: antes de terminar)
python3 scripts/docs.py index   # regenera las tablas de docs/INDEX.md y docs/decisions/README.md
scripts/shaders.sh              # recompila shaders/*.frag a .qsb (necesita qsb) tras cambiarlos
```

- **Probar sin ventana** (`--probe`), **capturas** (`--shot`) y **clics simulados**: los
  argumentos completos están en [runbooks/verificar-interfaz.md](runbooks/verificar-interfaz.md)
  y [runbooks/verificar-reproduccion.md](runbooks/verificar-reproduccion.md).
- **Compilar e instalar** para usarla (app de macOS, CachyOS): [COMPILAR.md](../COMPILAR.md).

---

## 4. Mapa del código

```
src/            Núcleo Rust. Un archivo por pieza; los singletons QML son puentes de cxx-qt
                (Player, Library, Account, AppSettings, Plugins).
  plugins/      Discord y Last.fm (los reparte plugins.rs).
qml/            Interfaz. Main.qml es la ventana; Theme.qml y Catalog.qml, singletons.
skins/          Skins incluidas (JSON dentro del binario).
shaders/        Sombreadores (.frag) y su versión compilada (.qsb), dentro del binario.
login/          Crate aparte: ventana de inicio de sesión de Linux (Qt WebEngine, opcional).
build.rs        Registra los QML y los puentes en el módulo app.musicplayer.
scripts/        Empaquetado (crear-app-macos.sh, instalar-linux.sh) y docs.py.
docs/           Esta guía, INDEX, ARCHITECTURE, TRAMPAS, ROADMAP, GUIA (aprender desde cero),
                areas/, decisions/, runbooks/, history/, templates/.
```

Cada archivo de `src/`, `qml/`, `skins/` y `login/src/` pertenece a **una sola** ficha de área
(lo comprueba `docs.py`). Cómo encajan las piezas (procesos, hilos, el puente):
[ARCHITECTURE.md](ARCHITECTURE.md).

---

## 5. Normas de arquitectura

- **Nunca bloquees el hilo de Qt.** Lo lento (red, yt-dlp, mpv, disco) va en un hilo y devuelve el
  resultado con `qt_thread().queue(...)`.
- **Rust → QML: JSON en una propiedad `QString`**, que `Catalog.qml` convierte con `JSON.parse`
  ([ADR-04](decisions/ADR-04-json-hacia-qml.md)). Un dato nuevo sigue el mismo camino.
- **Respuestas obsoletas:** cada petición lleva un contador (`request`, `load_token`,
  `search_request`) y se descarta si ya no es la última. Una petición nueva desde la interfaz
  también.
- **Lo pesado, en un proceso aparte** que se pueda cerrar: mpv, yt-dlp, las ventanas de inicio de
  sesión ([ADR-02](decisions/ADR-02-mpv-en-proceso-aparte.md),
  [ADR-07](decisions/ADR-07-inicio-de-sesion-en-proceso-aparte.md)). Nada de enlazar un motor web
  al reproductor.
- **Errores:** en la interfaz, mensajes cortos en español (`Player.error`, `Library.error`); el
  detalle técnico, a stderr con un prefijo reconocible (`historial:`, `guardar en …`).
- **Archivo QML nuevo** → `build.rs`; **puente Rust nuevo** → `.files([...])` de `build.rs` y `mod`
  en `main.rs`. Lo comprueba `docs.py`; el procedimiento:
  [runbooks/nuevo-componente.md](runbooks/nuevo-componente.md).
- **Una decisión que cruza áreas o que fija el propietario es una ADR**
  ([decisions/](decisions/README.md)). No se reabre una ADR sin un motivo nuevo.

---

## 6. Normas de interfaz

- **Colores solo a través de `Theme`.** Un color que deba cambiar con la skin es una clave nueva
  en `colores`, con su valor por defecto en `Theme.pick` y en las cuatro skins de `skins/`
  ([runbooks/nuevo-color-de-skin.md](runbooks/nuevo-color-de-skin.md)).
- **Medidas solo a través de `Theme` y piezas comunes**
  ([ADR-23](decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)): tamaños de letra
  (`Theme.fontDisplay` … `fontMini`), radios (`radiusS/M/L`, `coverRadius`), margen (`margin`);
  pestañas con `Tabs`, filas de canción con `TrackRow`, etiquetas con `SectionLabel`, vacíos con
  `EmptyState`, foco con `FocusRing` ([interfaz-comun](areas/interfaz-comun.md)). `docs.py check`
  rechaza un tamaño de letra, un radio o un color escritos a mano en `qml/`.
- **Opciones nuevas:** `AppSettings.opcion("clave")` (vacío = valor por defecto) y `setOpcion`,
  leídas con `AppSettings.revision` como segundo argumento; su fila en `optionRows` de `SettingsSheet.qml`
  y la clave en el `opciones:` de la ficha de su área
  ([runbooks/nueva-opcion.md](runbooks/nueva-opcion.md)).
- **Accesibilidad:** botones con 44 px de área como mínimo, `Accessible.name` en los de solo
  icono y foco por teclado visible. Botones y opciones con
  `gesturePolicy: TapHandler.ReleaseWithinBounds` (los de `IconButton`, `PillButton` y `TopNav`
  ya lo llevan).
- **Coste de cada fotograma:** nada de «hover», cursor ni gestores por elemento sobre contenido
  animado ([TRAMPAS](TRAMPAS.md#qt-quick-y-qml)); una animación nueva que suene mientras
  reproduce se mide con CPU acumulada ([runbooks/medir-rendimiento.md](runbooks/medir-rendimiento.md)).
- **Diseño visual:** se proponen **2–4 alternativas** con nombre (A/B/C) y su contrapartida, y el
  propietario elige antes de detallar (§11).

---

## 7. Norma: los datos del propietario no se tocan

- **Nunca borres ni sobrescribas** `<config>/musicplayer/` (`settings.json`, `cookies.txt`,
  `account.json`, `plugins.json`, sus skins y mascotas) ni `<caché>/musicplayer/`. Las pruebas
  van con `HOME=/ruta/temporal` ([runbooks/verificar-interfaz.md](runbooks/verificar-interfaz.md#aislar-las-pruebas)).
- **Nunca importes las cookies del navegador del propietario** en una prueba. El camino con
  sesión se prueba con un `cookies.txt` falso ([runbooks/probar-sesion.md](runbooks/probar-sesion.md)).
- **`MUSICPLAYER_SILENT=1` siempre** en pruebas automáticas (mpv sin sonido).
- **No castigues a YouTube:** agrupa las pruebas que hacen peticiones reales; si aparecen 403,
  «Requested format is not available» o «Sign in to confirm you're not a bot», espera unos
  minutos y compruébalo con `yt-dlp` directamente antes de culpar al código.

---

## 8. Norma: verificar antes de dar algo por terminado

1. `cargo build --release` **sin errores ni avisos**; `cargo test` en verde;
   `python3 scripts/docs.py check` sin problemas.
2. **Captura (`--shot`) de cada pantalla que hayas tocado**, revisada a ojo
   ([verificar-interfaz](runbooks/verificar-interfaz.md)).
3. Si tocaste reproducción: una prueba con `--autoplay` y `MUSICPLAYER_SILENT=1` que termine con
   `sonando true` y sin `error` ([verificar-reproduccion](runbooks/verificar-reproduccion.md)).
4. Si tocaste algo que afecte a memoria o tiempos: **mídelo en release**
   ([medir-rendimiento](runbooks/medir-rendimiento.md)) y apúntalo en la sección «Medidas» de su
   ficha; la medida anterior pasa al historial.
5. **Informa con honestidad:** qué verificaste y cómo, y qué **no** (Linux, Wayland, el sonido
   real, con sesión, la app empaquetada). Nunca presentes como probado algo que no lo está.

---

## 9. Norma: documentación, una fuente por tema

| Tema | Fuente única | En los demás sitios, solo un enlace |
|---|---|---|
| Normas de trabajo y comandos | Esta guía | `AGENTS.md` y `CLAUDE.md` solo la señalan |
| Un área: reglas, mecanismo, archivos, opciones, medidas, estado | Su ficha en [areas/](areas/) | — |
| Cómo encajan las piezas (procesos, hilos, puente, memoria global) | [ARCHITECTURE.md](ARCHITECTURE.md) | — |
| Trampas conocidas de Qt, cxx-qt, mpv, YouTube y macOS | [TRAMPAS.md](TRAMPAS.md) | — |
| Decisiones (ADR) | [decisions/](decisions/README.md), una por archivo | — |
| Procedimientos | [runbooks/](runbooks/) | La [GUIA](GUIA.md) los explica con ejemplos y enlaza el runbook |
| Hoja de ruta y deuda conocida | [ROADMAP.md](ROADMAP.md) | — |
| Historia: qué cambió, medidas antiguas, fallos resueltos, verificaciones | [history/](history/README.md) | Nunca en los documentos vigentes |
| Qué leer para cada tarea; archivos, opciones y dependencias de cada área | [INDEX.md](INDEX.md), en parte generado | — |
| Uso de la app, skins, mascotas, atajos | [README.md](../README.md) | — |
| Compilar e instalar | [COMPILAR.md](../COMPILAR.md) | — |

- **Solo lo vigente.** Los documentos dicen cómo es la app hoy. Nada de «antes…», «hubo…»,
  «hasta que exista…» ni cifras que caducan (número de tests, de líneas): lo que pasó va a
  `docs/history/`. `docs.py check` lo rechaza fuera del historial.
- **Al cambiar un área**, actualiza su ficha (y su «Estado actual») y añade arriba una entrada en
  `docs/history/verificacion/<area>.md`. Un archivo nuevo va en el `archivos:` de su ficha; una
  opción nueva, en su `opciones:`. Un área nueva: [runbooks/nueva-area.md](runbooks/nueva-area.md).
  Después, `python3 scripts/docs.py index`.
- **Una trampa nueva** (un error que costó encontrar y que se repetiría): una línea en
  [TRAMPAS.md](TRAMPAS.md), en su sección, con el síntoma y el arreglo.

### 9.1 Norma: escribir para quien llega sin memoria

Quien siga el trabajo (otra persona, otro agente o el mismo después de compactar su contexto) no
recuerda la conversación. Lo que no esté en el repositorio **se pierde**.

- **Lo que decide el propietario en la conversación se escribe en la misma tarea**: una
  preferencia, en §11 de esta guía (una línea, con el detalle en la ficha); una decisión de
  arquitectura, en una ADR; un detalle de un área, en su ficha. Nunca solo en el chat ni en la
  memoria privada del agente.
- **Una tarea larga** (más de una sesión, o que se pueda cortar) lleva su nota en
  [EN-CURSO.md](EN-CURSO.md): objetivo, decisiones tomadas, hecho, falta y cómo retomarla. Se
  actualiza al terminar cada paso y se vacía al unir la rama ([runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md)).
- **Nombres exactos**: rutas desde la raíz, símbolos entre comillas invertidas y comandos
  completos que se puedan copiar. Nada de «el archivo de antes» ni «la función de la letra».
- **Al retomar** después de compactar o en una sesión nueva: lee [EN-CURSO.md](EN-CURSO.md), `git
  status` y `git log` de la rama, y la ficha del área. No te fíes del resumen de la conversación
  para lo que dice el repositorio.

---

## 10. Deuda conocida: no la empeores

La lista vigente está en el [ROADMAP](ROADMAP.md#deuda-conocida) y en el «Pendiente» y «Sin
verificar» de cada ficha. Si tu tarea toca alguno de esos puntos, resuélvelo o, al menos, no
añadas más casos, y actualiza la lista.

---

## 11. Cómo trabajar con el propietario

- Escribe en español, claro y directo. Explica las decisiones que tomes por tu cuenta y ofrece
  cambiarlas.
- Si una petición choca con estas normas, **explica el motivo y propone la alternativa** antes de
  actuar.
- Las preferencias que surjan en el trabajo se añaden aquí, en una línea, con el detalle en la
  ficha de su área.

**Preferencias vigentes** (no se cambian sin preguntar):

- **Sustituir a Pear Desktop y a la pestaña de Chrome**: lo que no consuma menos que ellos no vale
  ([ARCHITECTURE, memoria](ARCHITECTURE.md#memoria-y-arranque)).
- **Clic y que suene**: el arranque de una pista no espera a nada que no sea el audio (historial,
  plugins y precarga van aparte) ([resolucion](areas/resolucion.md)).
- **Ventana de vidrio con la navegación superior**; el panel de letra y cola, oculto al arrancar,
  a la derecha por defecto y movible ([ventana](areas/ventana.md)).
- **Vistas por sección**: Inicio, Explorar, Me gusta, Historial y Búsqueda en Muro; Playlists y Álbumes en
  Lomos; cualquier sección puede usar cualquier vista ([vistas](areas/vistas.md)).
- **Diseño con alternativas**: mockups y decisiones visuales con 2–4 opciones a elegir, no una sola
  propuesta (§6).
- **Mascota que participa**: pincharla con música da «Me gusta» (si su `mascota.json` lo pide),
  reacciona a pasar canción y a guardar en playlists, y en Opciones se pasa a la esquina inferior
  izquierda ([mascotas](areas/mascotas.md)).
- **Pulsar la barra de reproducción** en cualquier sitio que no sea un control abre «Sonando»
  ([reproduccion](areas/reproduccion.md)).
- **«Sonando» en dos disposiciones a elegir**: Grande (por defecto: carátula sola, sin título,
  y letra y cola estrechas, con el mismo margen a los dos lados) y Clásica (con el título y letra
  ancha); la letra cabe siempre. El título bajo la carátula también se elige aparte (Automático,
  Siempre, Nunca), y la carátula va a máxima calidad por defecto, con «Alta» en Opciones
  ([ventana](areas/ventana.md)).
- **Fondo «Plano»** en el modo ambiente para pantallas antiguas: un color sólido de la carátula,
  sin degradados ([personalizacion](areas/personalizacion.md)).
- **Movimiento del ambiente** en «deriva lenta» (los focos pasean despacio mientras suena),
  activable en Opciones (No, En Sonando, Siempre), y fondo «Fluido» (la carátula desenfocada y
  deformada, al estilo Better Lyrics Shaders) como valor del modo ambiente, con la letra de
  «Sonando» sobre él sin recuadro ([personalizacion](areas/personalizacion.md)).
- **«Me gusta» en la cuenta**: el corazón de la barra lo da en YouTube Music y, pulsado otra vez,
  lo quita ([reproduccion](areas/reproduccion.md)).
- **Diseño de las muestras del propietario**: barra con «Me gusta» y Aleatorio en tres estilos a
  elegir (Islas por defecto, Clásica y Compacta),
  Lomos con barra para recorrer la estantería y Opciones con miniaturas de skin y mascota
  ([reproduccion](areas/reproduccion.md), [vistas](areas/vistas.md),
  [personalizacion](areas/personalizacion.md)).
- **Registrar las escuchas en YouTube Music**, activado por defecto y desactivable
  ([historial](areas/historial.md)).
- **Letra de varias fuentes** (LRCLIB, NetEase y Kugou; mucho anime): la fuente se cambia en
  cada canción pulsando su nombre en el pie de la letra, y las líneas sin tiempo por palabra se
  iluminan enteras (el estimado, como opción) ([letra](areas/letra.md)).
- **Letra centrada** en horizontal y en vertical, y el ajuste de retraso como un pie discreto de
  texto tenue bajo ella ([letra](areas/letra.md)).
- **Explorar con ListenBrainz (Troi)**: Explorar muestra las listas y recomendaciones de
  ListenBrainz pedidas a su API desde Rust, sin Troi local en Python; en Opciones se puede volver
  al Explorar de YouTube Music. Las escuchas se envían con el plugin de ListenBrainz
  ([catalogo](areas/catalogo.md), [ADR-19](decisions/ADR-19-explorar-con-listenbrainz.md),
  [ADR-20](decisions/ADR-20-fuente-de-explorar-a-elegir.md)).
- **Sección Historial** en la navegación: el historial de escucha de la cuenta de YouTube Music
  ([catalogo](areas/catalogo.md)).
- **Ir al álbum y al artista desde el clic derecho** de cualquier canción o carátula, y
  **«Relacionado»** (la pestaña de YouTube Music) desde el mismo menú ([ventana](areas/ventana.md),
  [catalogo](areas/catalogo.md)).
- **Radio sin fin**: la cola de una canción elegida suelta pide más canciones al acercarse al
  final ([reproduccion](areas/reproduccion.md)).
- **Pulsar la carátula de «Sonando» la hace «latir»** (rebote y pulso de luz del fondo); ya no
  cierra la pantalla. Con el clic derecho, además, abre el menú de la canción («Relacionado»,
  álbum, artista) ([ventana](areas/ventana.md)).
- **Vista de artista «Órbita»**: la foto en el centro con un anillo del color de la foto y sus tres
  canciones más escuchadas flotando alrededor; al bajar, canciones y discografía
  ([detalle](areas/detalle.md)).
- **Explorar por categorías**: en Muro, una tarjeta por categoría («Portada con rótulo»), más
  separadas y que brillan con el color de su carátula al pasar el ratón; al pulsarla se abre como
  detalle. La primera es **Recomendados**, la fila de canciones del Inicio de YouTube Music (lo que
  en japonés es 「おすすめ」) ([vistas](areas/vistas.md), [catalogo](areas/catalogo.md),
  [ADR-22](decisions/ADR-22-explorar-por-categorias-con-recomendados.md)). El mismo brillo al pasar
  el ratón en el Muro de todas las secciones, desactivable en Opciones (`brillo`) ([vistas](areas/vistas.md)).
- **Ecualizador y amplificador de volumen como plugin** (Opciones › Plugins), con filtros de mpv
  ([reproduccion](areas/reproduccion.md)).
- **Carátula animada de Apple Music en «Sonando»** (opción, desactivada por defecto): el vídeo se
  descarga una vez a la caché y se reproduce con Qt Multimedia ([ventana](areas/ventana.md),
  [ADR-21](decisions/ADR-21-caratula-animada-de-apple-music.md)).
- **Interfaz unificada** ([ADR-23](decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)):
  **regla de dos** (lo que dice dónde estás, en blanco; un valor elegido, en vidrio claro), sin
  cabecera de sección salvo en la búsqueda, y volver o cerrar siempre arriba a la izquierda
  ([interfaz-comun](areas/interfaz-comun.md), [vistas](areas/vistas.md)).
- **Esquinas de las carátulas y clic, a elegir en Opciones**: redondeadas (por defecto) o
  cuadradas; doble clic para abrir o que suene (por defecto) o un clic, que además muestra abajo el
  nombre de lo que está bajo el ratón en el Muro ([personalizacion](areas/personalizacion.md),
  [reproduccion](areas/reproduccion.md), [vistas](areas/vistas.md)).
- **Categoría de Explorar con álbumes**: se recorre igual que Inicio, con el Muro
  ([detalle](areas/detalle.md)).
- **Canciones del detalle en cuadrícula**: fichas pequeñas con el título debajo, como el Muro; en
  un artista bajo su cabecera «Órbita», y en álbumes y playlists con la carátula y su información a
  la izquierda. En álbumes y playlists, número sobre color o carátula con número, a elegir en
  Opciones (`fichas`) ([detalle](areas/detalle.md)).
- **Rueda del ratón de PC**: baja lo mismo que en el Mac (120 px por muesca)
  ([interfaz-comun](areas/interfaz-comun.md)).
- **Opciones compactas**: un segmento «Normal / Compacta» junto a la × quita las descripciones de
  las filas (salen en el pie al pasar el ratón) ([personalizacion](areas/personalizacion.md)).
- **Iniciar sesión con una ventana propia** (WebKit del sistema en macOS, Qt WebEngine opcional en
  Linux) y, como alternativa, importar del navegador; sin disfrazar el agente de usuario
  ([sesion](areas/sesion.md)).

---

## 12. Checklist final de cada tarea

- [ ] Nada lento en el hilo de Qt; las respuestas obsoletas se descartan.
- [ ] Colores y medidas por `Theme`, piezas de [interfaz-comun](areas/interfaz-comun.md); opciones
      por `AppSettings.opcion`, con su fila y en su ficha.
- [ ] QML y puentes nuevos registrados en `build.rs` y `main.rs`.
- [ ] `cargo build --release` sin avisos, `cargo test` en verde y `python3 scripts/docs.py check`
      sin problemas.
- [ ] Captura de cada pantalla tocada; `--autoplay` si se tocó reproducción; medida en release si
      cambia memoria o tiempos.
- [ ] Ficha del área al día (con «Estado actual»), entrada nueva en su historial, ADR si hubo una
      decisión, trampa nueva si la hubo, y `docs.py index`.
- [ ] Decisiones del propietario de esta conversación escritas en el repositorio (§9.1);
      [EN-CURSO.md](EN-CURSO.md) vacío si la tarea terminó.
- [ ] Datos del propietario como estaban; sin procesos de prueba (mpv, yt-dlp) vivos.
- [ ] Dicho qué no se verificó.

---

## 13. Norma: una rama por tarea

**No se trabaja directamente en `master`.** Cada funcionalidad o arreglo va en su rama.

1. **Antes de empezar**, parte de `master`: `git switch master && git pull` (si hay remoto) y
   `git switch -c feature/<nombre>` (`fix/<nombre>` para arreglos, `docs/<nombre>` para
   documentación), con `<nombre>` igual al área cuando sea de una sola.
2. **Durante el trabajo**, commits pequeños en español que digan qué cambia y por qué.
3. **Para unir**, completa el checklist (§12) y `git switch master && git merge --no-ff <rama>`
   (o un pull request si hay remoto). Luego borra la rama.
4. **Commits, push y merge solo con el visto bueno del propietario**: pídelo al terminar e indica
   qué se verificó.

Si al empezar hay cambios sin commit en `master`, avisa al propietario y propón moverlos a su rama
antes de seguir.
