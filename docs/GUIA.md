# Guía del proyecto: de cero a desarrollar por tu cuenta

Esta guía es para alguien que sabe programar (estructuras de datos, hilos, HTTP, algo de
orientación a objetos) pero **no sabe Rust** y no ha tocado QML. Al terminarla deberías poder
leer cualquier archivo del proyecto, entender por qué está así y añadir cosas sin romper nada.

Léela en orden. Cada parte enlaza al código real: ábrelo al lado.

| Parte | Qué aprendes | Tiempo |
|---|---|---|
| [1. La idea general](#1-la-idea-general) | Qué piezas hay y quién habla con quién | 15 min |
| [2. Ponerlo en marcha](#2-ponerlo-en-marcha) | Compilar, ejecutar, probar sin ventana | 15 min |
| [3. Rust, lo justo](#3-rust-lo-justo-para-este-proyecto) | El Rust que usa el proyecto, nada más | 1–2 h |
| [4. QML, lo justo](#4-qml-lo-justo-para-este-proyecto) | Cómo se hace la interfaz | 45 min |
| [5. El puente Rust ↔ QML](#5-el-puente-rust--qml-cxx-qt) | Cómo se llaman uno al otro | 30 min |
| [6. Un clic, de principio a fin](#6-un-clic-de-principio-a-fin) | Recorrido completo por el código | 30 min |
| [7. Recetas](#7-recetas-paso-a-paso) | Cambios típicos, paso a paso | — |
| [8. Depurar](#8-depurar) | Qué hacer cuando algo no funciona | 15 min |
| [9. Ejercicios](#9-ejercicios-para-coger-soltura) | Para practicar con el proyecto | — |

Documentos hermanos: [AGENTS.md](../AGENTS.md) (mapa de archivos, comandos, trampas
conocidas: tenlo siempre a mano) y [ARCHITECTURE.md](ARCHITECTURE.md) (decisiones técnicas
y medidas).

---

## 1. La idea general

Es un reproductor de YouTube Music de escritorio. Tiene **tres capas** y **dos programas
externos**:

```
┌───────────────────────────── proceso «musicplayer» ─────────────────────────────┐
│                                                                                 │
│   INTERFAZ (QML, carpeta qml/)          lo que ves: vistas, botones, animaciones│
│        ▲   lee propiedades                                                      │
│        │   llama funciones                                                      │
│        ▼                                                                        │
│   PUENTE (cxx-qt)                       convierte llamadas entre los dos mundos │
│        ▲                                                                        │
│        ▼                                                                        │
│   NÚCLEO (Rust, carpeta src/)           red, estado, decisiones                 │
│     player.rs  library.rs  account.rs  settings.rs  plugins.rs                  │
│     ytm.rs (YouTube Music)  stream.rs + resolver.rs (URL del audio)  lyrics.rs  │
└─────────────┬───────────────────────────────┬───────────────────────────────────┘
              │ socket (JSON)                 │ procesos / stdin-stdout
              ▼                               ▼
        ┌──────────┐                   ┌───────────────┐
        │   mpv    │ reproduce audio   │    yt-dlp     │ saca la URL del audio
        └──────────┘                   └───────────────┘   cuando la vía rápida no puede
```

- **QML** es el lenguaje de interfaz de Qt. Es declarativo: describes *qué* hay en pantalla y
  de qué depende cada cosa; Qt se encarga de redibujar cuando algo cambia.
- **Rust** hace todo lo que no es pintar: pedir datos a YouTube, decidir qué suena, guardar
  preferencias, hablar con mpv y con Discord…
- **cxx-qt** es una biblioteca que deja que objetos escritos en Rust aparezcan en QML como si
  fueran objetos de Qt (con propiedades y funciones).
- **mpv** es un reproductor de vídeo/audio de línea de comandos. No reproducimos el audio
  nosotros: arrancamos mpv en segundo plano y le mandamos órdenes por un socket.
- **yt-dlp** es un programa en Python que sabe sacar la URL real del audio de un vídeo de
  YouTube. Lo usamos solo cuando nuestra vía rápida (`stream.rs`) no basta.

¿Por qué este diseño? Las prioridades del proyecto son, en orden: poca memoria, respuesta
instantánea, personalización total y estética. Qt/QML pinta con la GPU y gasta poco; Rust es
tan rápido como C++ pero sin sus fallos de memoria; mpv y yt-dlp ya resuelven muy bien lo
difícil (decodificar audio, entender YouTube) y no tiene sentido reescribirlos.

**Los cinco objetos que la interfaz usa** (todos «singletons»: hay uno solo y se llama por su
nombre desde cualquier archivo QML):

| En QML | Archivo Rust | Para qué |
|---|---|---|
| `Player` | `src/player.rs` | Cola, canción actual, posición, play/pausa, lista temporal |
| `Library` | `src/library.rs` | Secciones (Inicio, Álbumes…), búsqueda, detalle abierto |
| `Account` | `src/account.rs` | Iniciar/cerrar sesión |
| `AppSettings` | `src/settings.rs` | Preferencias y skins |
| `Plugins` | `src/plugins.rs` | Discord, Last.fm, controles del sistema |

Y dos singletons escritos en QML: `Theme` (colores y tamaños) y `Catalog` (convierte los datos
de Rust en objetos que QML entiende).

---

## 2. Ponerlo en marcha

Necesitas lo de [COMPILAR.md](../COMPILAR.md) (Rust, Qt 6, mpv, yt-dlp). Después:

```bash
cargo build --release
```

```bash
./target/release/musicplayer
```

`cargo` es la herramienta de Rust: compila, descarga dependencias (las «crates», que están en
`Cargo.toml`) y ejecuta pruebas. La primera compilación tarda unos minutos; luego ~15 s.
Compila siempre en `--release` si vas a medir velocidad o memoria.

### Probar sin abrir la ventana

El programa tiene un modo «sonda» que habla con YouTube y escribe el resultado en la
terminal. Es la forma más rápida de saber si un problema es de la red o de la interfaz:

```bash
./target/release/musicplayer --probe home
```

```bash
./target/release/musicplayer --probe search "rosalía"
```

```bash
./target/release/musicplayer --probe album OLAK5uy_m5cMcwGb9BHQr6rBbNqTcuEmrX0afsbC0
```

La lista completa está en AGENTS.md («Probar sin abrir la ventana»).

### Capturas automáticas

`--shot` abre la ventana, espera, guarda una captura y sale. Con otros argumentos se coloca
en la sección o estado que quieras:

```bash
MUSICPLAYER_SILENT=1 ./target/release/musicplayer --shot /tmp/prueba.png --delay 8000 --section albumes --index 3
```

`MUSICPLAYER_SILENT=1` hace que mpv no suene. Incluso puedes simular clics de ratón con
`MUSICPLAYER_DEBUG_CLICK` (ver AGENTS.md). Así se prueba la interfaz sin tocarla.

### Pruebas

```bash
cargo test --release
```

Las pruebas están al final de cada archivo Rust, en un bloque `#[cfg(test)] mod tests`.

---

## 3. Rust, lo justo para este proyecto

Rust tiene fama de difícil por su sistema de «propiedad». Aquí verás solo lo que el proyecto
usa, con ejemplos sacados de él. Para profundizar, al final hay recursos.

### 3.1 Variables y tipos

```rust
let nombre = "Quevedo";          // inmutable por defecto
let mut contador = 0;            // `mut` para poder cambiarla
contador += 1;
let duracion: f64 = 203.5;       // tipo explícito (f64 = double)
let texto: String = format!("{nombre} · {duracion} s");   // como sprintf
```

Tipos que verás mucho: `i32`/`u64` (enteros), `f64` (decimales), `bool`, `String` (texto que
es tuyo y puedes modificar), `&str` (texto prestado, solo lectura), `Vec<T>` (lista
dinámica, como `ArrayList<T>`), `HashMap<K, V>`.

### 3.2 Structs y métodos

Un `struct` es como una clase sin herencia. Este es el de una pista ([src/ytm.rs](../src/ytm.rs)):

```rust
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Track {
    pub title: String,
    pub artist: String,
    pub thumb: String,
    pub video_id: String,
    pub duration: f64,
}
```

- `pub` = público (visible desde otros archivos).
- `#[derive(...)]` le pide al compilador que genere código: `Clone` (poder copiarlo con
  `.clone()`), `Default` (valor vacío), `Serialize`/`Deserialize` (convertir a/desde JSON con
  la crate `serde`). `rename_all = "camelCase"` hace que `video_id` se llame `videoId` en el
  JSON, que es lo que QML espera.

Los métodos van en un bloque `impl`:

```rust
impl Session {
    pub fn headers(&self) -> (String, String) {   // &self = «este objeto, solo lectura»
        ...
    }
}
```

### 3.3 Enums y `match`

Un `enum` en Rust es más potente que en Java: cada variante puede llevar datos. Los eventos
que mpv nos manda ([src/audio.rs](../src/audio.rs)):

```rust
pub enum Event {
    Position(f64),      // lleva la posición en segundos
    Duration(f64),
    Paused(bool),
    Started,
    Ended,
    Failed,
    ...
}
```

Y se tratan con `match`, que obliga a cubrir todos los casos ([src/player.rs](../src/player.rs)):

```rust
match event {
    Event::Position(position) => self.set_position(position),
    Event::Started => { /* … */ }
    Event::Ended => { /* pasar a la siguiente */ }
    _ => {}             // «cualquier otro caso: nada»
}
```

### 3.4 Errores: `Option`, `Result` y `?`

Rust no tiene `null` ni excepciones. En su lugar:

- `Option<T>`: un valor que puede no estar. Es `Some(valor)` o `None`.
- `Result<T, E>`: una operación que puede fallar. Es `Ok(valor)` o `Err(error)`.

```rust
fn cookies_file() -> Option<PathBuf> { ... }        // puede que no haya sesión

pub fn resolve(video_id: &str) -> Result<String, String> { ... }   // URL o mensaje de error
```

El operador `?` es la forma corta de «si es un error, devuélvelo ya; si no, dame el valor»:

```rust
let page = post("browse", json!({ "browseId": id }))?;   // si falla la red, sale de la función con el error
```

Otras formas que verás:

```rust
if let Some(url) = resolver::cached(&id) { /* había URL en caché */ }

let Some(track) = self.tracks.get(index) else { return };   // si no existe, salir

match result {
    Ok(tracks) => ...,
    Err(error) => eprintln!("{error}"),      // eprintln! escribe en stderr
}

valor.unwrap_or_default()   // el valor, o el «vacío» de su tipo si no hay
```

En este proyecto **nunca** se usa `unwrap()` sin más en código normal (haría que el programa
se cerrase de golpe si falla); solo en pruebas.

### 3.5 Propiedad y préstamos (lo importante de Rust)

La regla: **cada valor tiene un único dueño**. Cuando lo pasas a una función, o se lo das
(«se mueve») o se lo prestas (`&`).

```rust
fn imprime(texto: &str) { println!("{texto}"); }   // pide prestado: no se queda con él
fn guarda(texto: String) { ... }                     // se lo queda

let nombre = String::from("Columbia");
imprime(&nombre);        // prestado: `nombre` sigue siendo tuyo
guarda(nombre.clone());  // le das una copia
guarda(nombre);          // le das el original: a partir de aquí ya no puedes usar `nombre`
```

- `&x` = préstamo de solo lectura (puede haber muchos a la vez).
- `&mut x` = préstamo para modificar (solo uno a la vez, y sin lectores).

Si el compilador se queja con «borrow of moved value» o «cannot borrow as mutable», casi
siempre la solución es una de estas: prestar (`&`) en vez de mover, hacer `.clone()` (en este
proyecto los datos son pequeños: clonar es barato y aceptable), o usar el valor antes de
moverlo. **El compilador explica el problema y suele sugerir el arreglo: lee el mensaje
entero.**

### 3.6 Clausuras (lambdas)

```rust
let dobles: Vec<i32> = numeros.iter().map(|n| n * 2).collect();

tracks.iter().filter(|track| !track.video_id.is_empty())
```

`|args| cuerpo` es una función anónima. `move |…| …` hace que la clausura se quede con
(«mueva dentro») las variables que usa: imprescindible al mandarla a otro hilo.

### 3.7 Hilos y estado compartido

La regla de oro del proyecto: **lo lento (red, yt-dlp, mpv) va en otro hilo; el hilo de Qt
nunca se bloquea**. El patrón, que verás en casi todos los archivos:

```rust
let qt = self.qt_thread();                 // «buzón» para volver al hilo de la interfaz
thread::spawn(move || {                    // nuevo hilo
    let result = ytm::search(&query);      // lento: va por red
    let _ = qt.queue(move |mut library| {  // de vuelta en el hilo de Qt…
        library.as_mut().set_busqueda(QString::from(&json));   // …se actualiza la propiedad
    });
});
```

Para datos que comparten varios hilos se usa `Mutex` (un candado) dentro de `LazyLock` (se
crea la primera vez que se usa). Ejemplo, la caché de URLs de [src/resolver.rs](../src/resolver.rs):

```rust
static NEEDS_ACCOUNT: LazyLock<Mutex<HashSet<String>>> = LazyLock::new(Default::default);

if let Ok(mut set) = NEEDS_ACCOUNT.lock() {   // coger el candado (puede fallar: por eso `if let Ok`)
    set.insert(video_id.to_owned());
}                                             // aquí se suelta solo
```

### 3.8 Módulos y macros

- Cada archivo `src/x.rs` es un módulo; `main.rs` los declara con `mod x;`. Se usan con
  `x::funcion()` o importándolos con `use crate::x;`.
- Lo que acaba en `!` es una **macro** (código que genera código): `println!`, `format!`,
  `vec![…]`, `json!({…})` (crea JSON literal, de `serde_json`).
- `#[…]` son **atributos**: instrucciones para el compilador o para una biblioteca
  (`#[derive]`, `#[test]`, `#[cfg(target_os = "macos")]` = «solo en macOS»).

### 3.9 Cómo leer un error del compilador

```
error[E0382]: borrow of moved value: `nombre`
  --> src/player.rs:120:13
   |
118 |     guarda(nombre);
   |            ------ value moved here
120 |     imprime(&nombre);
   |             ^^^^^^^ value borrowed here after move
   = help: consider cloning the value: `nombre.clone()`
```

Arriba el problema, luego dónde, luego (a menudo) la solución. `rustc --explain E0382` da la
explicación larga.

---

## 4. QML, lo justo para este proyecto

### 4.1 Objetos, propiedades y bindings

Un archivo QML describe un árbol de objetos. Este es un botón simplificado:

```qml
Rectangle {
    id: boton                      // nombre para referirse a él
    width: 120
    height: 44
    radius: height / 2             // ← binding: se recalcula solo si cambia height
    color: raton.hovered ? Theme.controlActive : Theme.control

    Text {
        anchors.centerIn: parent   // colocación relativa al padre
        text: Player.playing ? "Pausa" : "Reproducir"   // cambia sola cuando cambia Player.playing
        color: Theme.text
    }

    HoverHandler { id: raton }
    TapHandler { onTapped: Player.toggle() }   // al pulsar, llama a Rust
}
```

La idea clave son los **bindings**: `text: Player.playing ? … : …` no se evalúa una vez, sino
cada vez que `Player.playing` cambia. Por eso Rust solo tiene que cambiar la propiedad y toda
la interfaz se actualiza sola.

### 4.2 Propiedades propias, señales y funciones

```qml
Item {
    id: root
    property string titulo: ""            // propiedad nueva
    readonly property bool vacio: titulo === ""
    signal elegido(var item)              // evento que otros pueden escuchar

    function abrir(item) { root.elegido(item) }   // JavaScript normal
}
```

Quien usa el componente escucha la señal con `on` + nombre en mayúscula:
`MiComponente { onElegido: item => console.log(item.title) }`.

### 4.3 Listas: Repeater y ListView

```qml
ListView {
    model: Catalog.queue                  // un array de objetos JS
    delegate: Text {
        required property var modelData   // cada elemento del array
        required property int index
        text: (index + 1) + ". " + modelData.title
    }
}
```

`ListView` crea solo las filas visibles (bueno para listas largas); `Repeater` las crea
todas.

### 4.4 Animaciones

```qml
x: abierto ? 0 : -300
Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
```

`Behavior` anima cualquier cambio de esa propiedad. Las duraciones comunes están en
`Theme.animFast` y `Theme.animMove`.

### 4.5 Los singletons QML del proyecto

- **`Theme`** ([qml/Theme.qml](../qml/Theme.qml)): todos los colores y medidas. Los colores
  salen de la skin activa (`skins/*.json`). **Nunca escribas un color a mano en un
  componente**: usa `Theme.text`, `Theme.accent`… o la skin dejaría de aplicarse.
- **`Catalog`** ([qml/Catalog.qml](../qml/Catalog.qml)): Rust publica los datos como texto JSON
  (por ejemplo `Library.inicio`); `Catalog` los convierte con `JSON.parse` en arrays que las
  vistas usan como `model`.

### 4.6 Cómo encajan los archivos de la interfaz

```
Main.qml (la ventana)
├── Ambient            fondo de color
├── SectionView        elige la vista de la sección: MuroView / LomosView / CubetaView
├── TopNav, SearchField, ViewSwitcher, botones de arriba
├── NowPlayingPanel    panel derecho: carátula, Letra / Cola / Temporal
├── NowPlayingView     pantalla «Sonando» (sube desde abajo)
├── PlayerBar          barra de reproducción
├── DetailView         detalle de álbum/playlist/artista
├── InspectView        modo inspeccionar (caja 3D)
├── ContextMenu        menú de clic derecho
├── SettingsSheet      opciones
└── MiniPlayer         (otra ventana)
```

---

## 5. El puente Rust ↔ QML (cxx-qt)

Así se declara un objeto Rust que QML puede usar. Versión reducida de `Account`
([src/account.rs](../src/account.rs)):

```rust
#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;       // el texto de Qt
    }

    #[auto_cxx_name]                               // snake_case de Rust → camelCase en QML
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]                           // en QML se usa como `Account`
        #[qproperty(bool, signed_in)]              // propiedad → `Account.signedIn` en QML
        #[qproperty(QString, name)]                // → `Account.name`
        type Account = super::AccountRust;         // los datos viven en este struct

        #[qinvokable]                              // función llamable desde QML
        fn sign_in_web(self: Pin<&mut Account>);   // → `Account.signInWeb()`
    }

    impl cxx_qt::Threading for Account {}          // permite el patrón qt_thread().queue
}

pub struct AccountRust {          // un campo por cada qproperty, con el mismo nombre
    signed_in: bool,
    name: QString,
    ...
}

impl qobject::Account {
    fn sign_in_web(mut self: Pin<&mut Self>) {
        self.as_mut().set_busy(true);           // set_<propiedad>: cambia y avisa a QML
        ...
    }
}
```

Lo que tienes que saber:

- Por cada `#[qproperty(tipo, nombre)]` cxx-qt genera `nombre()` (leer) y `set_nombre(v)`
  (escribir **y avisar a QML**, que redibuja lo que dependa de ella).
- `Pin<&mut Self>` es el tipo del «yo» modificable de un objeto Qt. No le des vueltas: copia
  la forma de las funciones vecinas. `self.as_mut()` lo «reutiliza» para llamar a varios
  métodos seguidos.
- Para los datos estructurados (listas de canciones, secciones), Rust no expone objetos sino
  **un JSON en una propiedad `QString`**. Es simple y rápido para el volumen de este proyecto.
- **Trampas** (también en AGENTS.md): un archivo Rust con puente nuevo hay que añadirlo a
  `build.rs` (`.files([...])`) y como `mod` en `main.rs`; un QML nuevo, a `QML_FILES` de
  `build.rs`. Si no, «el tipo no existe».

---

## 6. Un clic, de principio a fin

Qué pasa cuando haces doble clic en una canción del Muro. Sigue los enlaces con el código
abierto.

1. **La vista** ([qml/MuroView.qml](../qml/MuroView.qml)): el `TapHandler` de la tarjeta, en
   `onDoubleTapped`, emite `root.activated(cell.modelData)`. `modelData` es el objeto JS de la
   tarjeta (título, `videoId`, carátula…).
2. **La ventana** ([qml/Main.qml](../qml/Main.qml)): `SectionView { onActivated: item =>
   win.choose(item) }`. `choose` ve que es una canción: llama a
   `Player.playItem(JSON.stringify(item))` y abre la pantalla «Sonando» (`nowOpen = true`).
3. **Rust, `Player::play_item`** ([src/player.rs](../src/player.rs)): convierte el JSON en un
   `Item`, crea una cola de una pista y llama a `load(0)`. En otro hilo pide la «radio» de la
   canción (`ytm::queue`) para tener lo que suena después.
4. **`load`**: actualiza `title`, `artist`, `thumb`… (la barra y «Sonando» cambian al
   instante, porque dependen de esas propiedades) y pide la URL del audio:
   - si ya estaba en caché (la precarga la resolvió al pasar el ratón), al momento;
   - si no, en otro hilo `resolver::resolve(video_id)`.
5. **El resolvedor** ([src/resolver.rs](../src/resolver.rs)):
   1. la **vía rápida** ([src/stream.rs](../src/stream.rs)): una petición a la API del
      reproductor de YouTube que devuelve la URL directa en ~0,3 s;
   2. si YouTube no la da sin sesión y hay sesión, **yt-dlp** con tus cookies (el cliente de
      YouTube Music), ~2 s;
   3. guarda la URL en caché hasta que caduca.
6. **mpv** ([src/audio.rs](../src/audio.rs)): `load_stream(url)` manda por el socket la orden
   `loadfile`. mpv empieza a sonar y avisa con eventos (`Started`, `Position`…).
7. **De vuelta en `Player::on_event`**: `Started` → `set_playing(true)`, avisa a los plugins
   (Discord muestra la canción) y precarga las tres siguientes. `Position` → `set_position`
   cada pocos milisegundos: la barra de progreso y la letra se mueven solas.
8. **La letra** ([src/lyrics.rs](../src/lyrics.rs)): en paralelo se pide a LRCLIB; llega como
   JSON a `Player.lyrics`; `Catalog.lyrics` la convierte y `LyricsView` ilumina la línea de
   `Catalog.lineAt(Catalog.lyricsTime)`.

Si entiendes este recorrido, entiendes el proyecto: todo lo demás son variaciones.

---

## 7. Recetas paso a paso

### 7.1 Añadir una opción en Ajustes

Ejemplo: una opción «Mostrar segundos en la barra» (sí/no).

1. En [qml/SettingsSheet.qml](../qml/SettingsSheet.qml), sección «Disposición», añade al
   `model` del `Repeater` una entrada como las que hay:
   ```qml
   { key: "segundos", label: "Mostrar segundos", fallback: "si",
     options: [{ id: "si", label: "Sí" }, { id: "no", label: "No" }] },
   ```
   Con eso ya aparece la fila y se guarda sola (en `settings.json`, vía
   `AppSettings.setOpcion`). No hace falta tocar Rust.
2. Léela donde la uses. El `void AppSettings.revision` hace que el binding se recalcule
   cuando cambie cualquier opción:
   ```qml
   readonly property bool segundos: { void AppSettings.revision; return AppSettings.opcion("segundos") !== "no" }
   ```
   Si la van a usar varios archivos, ponla en `Theme.qml`.

### 7.2 Añadir un color a las skins

1. En `Theme.qml`: `readonly property color miColor: pick("miColor", "#FF8800")` (el segundo
   valor es el de por defecto).
2. Añade `"miColor": "#…"` a la sección `colores` de las cuatro skins de `skins/`.
3. Usa `Theme.miColor` en los componentes.

### 7.3 Añadir un componente QML nuevo

1. Crea `qml/MiCosa.qml`.
2. Regístralo en `build.rs`, en `QML_FILES`.
3. Úsalo como `MiCosa { … }` desde cualquier QML.

### 7.4 Añadir una propiedad o función a `Player`

Ejemplo: saber cuántas canciones quedan en la cola.

1. En [src/player.rs](../src/player.rs), dentro de `extern "RustQt"`, junto a las otras
   propiedades: `#[qproperty(i32, restantes)]`.
2. En `pub struct PlayerRust`, el campo `restantes: i32,` y en `impl Default for PlayerRust`
   su valor inicial `restantes: 0,`.
3. Actualízala donde cambie la cola o la pista, por ejemplo al final de `load`:
   ```rust
   let restantes = (self.tracks.len() - index - 1) as i32;
   self.as_mut().set_restantes(restantes);
   ```
4. En QML: `Text { text: Player.restantes + " canciones más" }`.

Para una **función**: declárala con `#[qinvokable]` en el bloque del puente (solo la firma,
como las demás) y escribe el cuerpo en `impl qobject::Player`. Ojo con la trampa de AGENTS.md:
el cuerpo nunca va dentro del bloque `extern "RustQt"`.

### 7.5 Añadir datos nuevos de YouTube Music

Ejemplo: una sección con tus «Subidas».

1. Descubre qué pide la web: abre music.youtube.com con las herramientas de desarrollador
   (pestaña Red), filtra por `browse` y mira el `browseId` de la petición.
2. En [src/ytm.rs](../src/ytm.rs) ya tienes `browse(browse_id)`, que devuelve `Vec<Zone>`
   (filas con título y tarjetas). Pruébalo antes desde una sonda en `main.rs`.
3. En [src/library.rs](../src/library.rs), añade la propiedad (`#[qproperty(QString, subidas)]`
   + campo en el struct) y una entrada en la lista `sections` de `load()`, como `megusta`.
   Esa lista es un array de tamaño fijo: sube también el número de su tipo (`[…; 5]` → `[…; 6]`);
   si no, el compilador te lo recordará.
4. En [qml/Catalog.qml](../qml/Catalog.qml): una propiedad `subidas: parse(Library.subidas)`,
   el `case "subidas"` en `zonas()` y la entrada en `sections` (con `cuenta: true` si exige
   sesión). La pestaña aparece en la navegación y en «Vista de cada sección».

### 7.6 Escribir una prueba

Al final del archivo Rust, dentro de `mod tests`:

```rust
#[test]
fn quita_el_numero_de_reproducciones() {
    assert_eq!(artist_from_subtitle("Quevedo • 75 M reproducciones"), "Quevedo");
}
```

`cargo test --release` la ejecuta.

---

## 8. Depurar

| Síntoma | Qué mirar |
|---|---|
| No compila (Rust) | Lee el error completo de `cargo build`; suele traer la solución |
| La ventana sale vacía o falta algo | La terminal: QML escribe ahí sus errores (`qrc:/…qml:123: …`) |
| Algo de la red no llega | Una sonda `--probe …` para aislar si es YouTube o la interfaz |
| Una canción no suena | `--probe fast ID` (¿qué dice YouTube?), `--probe playable ID`, y las líneas de stderr del resolvedor |
| Un clic «atraviesa» a lo de debajo | `gesturePolicy: TapHandler.ReleaseWithinBounds` (ver AGENTS.md) |

- En QML: `console.log("valor", algo)` escribe en la terminal.
- En Rust: `eprintln!("valor: {algo:?}")` (`{:?}` imprime casi cualquier cosa).
- Prueba siempre con `MUSICPLAYER_SILENT=1` y un `HOME` temporal para no tocar tus
  preferencias ni tu sesión.
- **No castigues a YouTube**: muchas pruebas seguidas hacen que bloquee tu IP un rato. Si de
  repente todo falla con 403 o «confirm you're not a bot», espera unos minutos.
- La sección «Trampas conocidas» de AGENTS.md recoge cada error raro que ya nos ha pasado y su
  arreglo. Léela entera una vez.

---

## 9. Ejercicios para coger soltura

Ordenados de menos a más. Cada uno toca una parte distinta.

1. **Solo QML.** En la barra de reproducción (`PlayerBar.qml`), muestra el tiempo que falta
   (`-1:23`) en vez de la duración total. *Pista:* `Theme.mmss(Player.duration - Player.position)`.
2. **Opción nueva.** Haz que lo anterior sea una opción de Ajustes (receta 7.1).
3. **Rust sin puente.** Añade una sonda `--probe artist NOMBRE` que busque y muestre el primer
   artista. *Pista:* copia el caso `"search"` de `main.rs` y filtra por `item.kind == "artist"`.
4. **Puente.** Añade a `Player` la propiedad `restantes` (receta 7.4) y muéstrala en la
   pestaña Cola.
5. **Hilos.** Añade a `Library` una función que pida la letra de una canción cualquiera
   (`lyrics::fetch`) en otro hilo y la publique en una propiedad. Sigue el patrón de
   `search` en `library.rs`.
6. **Prueba.** Escribe una prueba para `seconds("3:27")` en `ytm.rs` (debe dar 207).

Si te atascas, busca en el proyecto algo que ya haga algo parecido: casi todo tiene un vecino
que puedes imitar.

---

## 10. Para aprender más

- **Rust:** «The Rust Programming Language» (el «libro», gratis: doc.rust-lang.org/book),
  capítulos 1–10 y 16 (hilos). «Rust by Example» para ver código corto de cada tema.
  Rustlings (ejercicios pequeños) si te gusta aprender practicando.
- **QML:** documentación de Qt Quick (doc.qt.io), sobre todo «QML Syntax Basics», «Property
  Binding» y «Qt Quick Controls» para ver ejemplos.
- **cxx-qt:** el libro de KDAB (kdab.github.io/cxx-qt/book).
- **La API de YouTube Music:** no es pública; el proyecto `ytmusicapi` (Python) es la mejor
  referencia de qué pide la web y cómo leer sus respuestas.
