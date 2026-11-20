# Reproductor de música

Cliente de escritorio ligero para YouTube Music en macOS y Linux (CachyOS), hecho con
**Qt 6 / QML** para la interfaz y **Rust** para el núcleo. El audio lo reproduce **mpv** y las
URLs de audio las obtiene **yt-dlp**. No usa Electron ni un navegador embebido.

Aspecto por defecto: ventana de vidrio con modo ambiente (el fondo toma el color de la
carátula), letra sincronizada palabra a palabra, y tres formas de recorrer la biblioteca:

| Vista | Qué es | Por defecto en |
|---|---|---|
| **Lomos** | Estantería de cajas en 3D: la elegida de frente y más grande, sus vecinas giradas hacia ella y el resto como lomos, con reflejo en el suelo y halo de color | Playlists, Álbumes |
| **Cubeta** | Pasar discos de uno en uno, como en una tienda | — |
| **Muro** | Cuadrícula de carátulas por zonas | Inicio, Explorar, Me gusta, Historial |

Cada sección puede usar cualquier vista (Opciones → «Vista de cada sección», el selector de
arriba a la derecha o la tecla `V`). La letra y la cola van en un panel lateral que se puede
poner a la izquierda o a la derecha, o cerrar con el botón de la barra.

> Cliente **no oficial**: depende de cómo YouTube sirva su contenido. Cuando YouTube cambia
> algo, suele bastar con actualizar yt-dlp.

## Calidad y velocidad

- **Arranque de las canciones**: ~0,5 s desde el clic sin precarga y ~0,1 s con ella (lo
  enfocado, lo que está bajo el ratón y la siguiente de la cola se preparan solos).
- **Calidad**: «Alta» (por defecto) da Opus a ~160 kbps, lo máximo que ofrece YouTube Music sin
  Premium. Con **YouTube Premium** y la sesión iniciada, elige «Premium · 256 kbps» en
  Opciones › Reproducción › Calidad del audio. El panel muestra el formato real que suena.

## Personalización

En **Opciones**:

- **Aspecto**: skins Vidrio, Medianoche, Grafito y Neón, más las tuyas.
- **Disposición**: panel de letra y cola a la izquierda o a la derecha, modo ambiente,
  desenfoque (desactivarlo ahorra memoria y batería) y tamaño de las carátulas del Muro.
- **Vista de cada sección**: Lomos, Cubeta o Muro.
- **Barra de reproducción** (Apariencia): Islas, Clásica o Compacta.

### Crear una skin

Copia uno de los archivos de [`skins/`](skins) a la carpeta de skins
(`~/Library/Application Support/musicplayer/skins/` en macOS,
`~/.config/musicplayer/skins/` en Linux), cámbiale el nombre y edítalo. Después pulsa el botón
de recargar (la flecha circular) junto a «Skin» en Opciones › Apariencia; el de la carpeta la
abre.

```json
{
  "nombre": "Mi skin",
  "descripcion": "Una línea que se ve en Opciones.",
  "colores": {
    "fondo": "#0A0C11", "texto": "#FFFFFF",
    "textoSecundario": "#BDFFFFFF", "textoTenue": "#80FFFFFF",
    "vidrio": "#12FFFFFF", "vidrioDenso": "#94121419", "bordeVidrio": "#1FFFFFFF",
    "control": "#1AFFFFFF", "controlActivo": "#2EFFFFFF", "acento": "#FFB070"
  },
  "radio": 20,
  "ambiente": 1.0
}
```

Los colores admiten `#RRGGBB` y `#AARRGGBB` (los dos primeros dígitos son la opacidad). Lo
que falte toma el valor de Vidrio. `radio` es el redondeo de los paneles en píxeles y
`ambiente`, la intensidad del color de fondo (0 lo apaga). Una skin con el mismo nombre de
archivo que una incluida la sustituye. Por ahora las skins son oscuras: los velos sobre el
contenido asumen un fondo oscuro.

### Skins con imagen de fondo

Una skin también puede ser una **carpeta** (`skins/mi-skin/`) con un `skin.json` y sus
imágenes (rutas relativas a la carpeta):

```json
{ "fondo": "fondo.jpg", "fondoOpacidad": 0.8, "fondoVelo": 0.4 }
```

`fondo` va detrás de todo, recortada para llenar la ventana; `fondoVelo` (0–1) pone encima un
velo del color `fondo` para que el texto se lea sobre imágenes claras.

## Mascotas

Un personaje asomado sobre la barra de reproducción que cambia de pose según lo que pasa y
reacciona unos segundos a lo que haces. Va aparte de las skins (cualquier mascota con cualquier
skin) y se elige en **Opciones › Mascota**; con las opciones abiertas se pasa a la esquina
inferior izquierda de su panel. Cada mascota es una carpeta en `mascotas/` junto a la de skins
(`~/Library/Application Support/musicplayer/mascotas/` en macOS,
`~/.config/musicplayer/mascotas/` en Linux) con sus PNG y un `mascota.json`:

```json
{
  "nombre": "Ralsei",
  "descripcion": "Pínchalo mientras suena una canción para darle «Me gusta».",
  "pincharDaMeGusta": true,
  "poses": {
    "reposo":  { "imagen": "reojo.png",      "alto": 180 },
    "sonando": { "imagen": "bufanda.png",    "alto": 140 },
    "clic":    { "imagen": "verguenza.png",  "alto": 129, "segundos": 1.5 },
    "megusta": { "imagen": "alegria.png",    "alto": 147 },
    "saltada": { "imagen": "desilusion.png", "alto": 145 }
  }
}
```

Cada pose es el nombre del PNG (`"reposo": "quieta.png"`) o `{ "imagen", "alto", "segundos" }`:
`alto` es su alto en píxeles (si unas son solo la cabeza y otras el busto) y `segundos`, cuánto
dura si es una reacción. `alto` en la raíz es el de las poses que no lo digan (160 si falta),
`"espejo": true` las voltea y `"pincharDaMeGusta": true` hace que pincharla mientras suena una
canción le dé «Me gusta» (hace falta sesión).

**Reacciones**: duran unos segundos y mandan sobre todo lo demás.

| Pose | Cuándo | Dura | Si falta, usa |
|---|---|---|---|
| `clic` | Al pincharla | 1,5 s | `nueva` |
| `megusta` | Tras `clic`, si el pinchazo dio «Me gusta» | 2,5 s | `clic` |
| `fallo` | Si el «Me gusta» no se pudo dar (sin sesión, sin red) | 2,5 s | `error` |
| `enfado` | Al pincharla 5 veces en 4 segundos | 3 s | `clic` |
| `saltada` | Al pasar a la siguiente canción (no cuando termina sola) | 2,5 s | `sonando` |
| `playlist` | Al guardar algo en una playlist | 3 s | `megusta` |

**El resto del tiempo** manda la primera que se cumpla:

| Pose | Cuándo | Si falta, usa |
|---|---|---|
| `error` | Algo falla | `cargando` |
| `cargando` | Una pista tarda más de 0,7 s en arrancar | `reposo` |
| `nueva` | Unos segundos al empezar una pista | `sonando` |
| `sonando` | Mientras suena música | `reposo` |
| `navegando` | Sin música, mientras recorres una sección o abres un álbum (4 s tras el último movimiento) | `pausa` |
| `pausa` | Con una pista en pausa | `reposo` |
| `reposo` | Nada de lo anterior (la única obligatoria) | — |

Con solo `reposo` y `sonando`, la mascota está siempre en `reposo` salvo mientras suena música.
Recorta las poses con un corte recto abajo: así parece apoyada en la barra. En macOS, Vista
Previa quita el fondo blanco (Herramientas › Quitar fondo). «Añadir…», en Opciones › Apariencia,
abre la carpeta de mascotas; pulsa el botón de recargar junto a «Mascota» tras añadir o editar
una (en su recuadro sale la pose `reposo`). Solo se carga la pose visible, a su tamaño en pantalla: unos cientos de KB.

## Plugins

En **Opciones › Plugins**:

- **Controles del sistema** (activado por defecto): teclas multimedia, Centro de control en
  macOS y MPRIS en Linux (el panel de música del escritorio).
- **Discord** (activado por defecto): muestra «Escuchando *título de la canción*» en tu perfil y
  en la lista de miembros, con el artista, la carátula y el tiempo. Se conecta solo en
  cuanto Discord está abierto, también si lo abres con la música ya sonando. No hay que
  configurar nada.
- **Last.fm** (scrobbling): crea una clave de API gratis en
  [last.fm/api/account/create](https://www.last.fm/api/account/create), pega la clave y el
  secreto, pulsa **Conectar con Last.fm**, acepta en la web que se abre y pulsa **Ya lo he
  autorizado**. Envía «escuchando ahora» y hace el scrobble al escuchar la mitad o 4 minutos.
- **ListenBrainz**: crea una cuenta gratis en [listenbrainz.org](https://listenbrainz.org),
  copia tu token de [listenbrainz.org/settings](https://listenbrainz.org/settings/), pégalo y
  pulsa **Conectar**. Envía tus escuchas como Last.fm y, con ellas, **Explorar** te muestra las
  listas que ListenBrainz genera para ti cada semana (Exploración semanal, Jams), tus
  recomendaciones y las novedades de tus artistas. Tarda unos días en tener datos; puedes
  importar tu historial de Last.fm desde su web. Sin cuenta, Explorar muestra lo más escuchado
  de la semana en ListenBrainz. En Opciones › Vistas › **Fuente de Explorar** puedes volver al
  Explorar de YouTube Music (novedades, listas de éxitos y ánimos).

La sección **Historial** (con sesión) muestra lo que has escuchado en tu cuenta de YouTube Music,
por días.

La configuración de los plugins (con el secreto y la sesión de Last.fm y el token de
ListenBrainz) se guarda en
`plugins.json`, legible solo por tu usuario.

## Cuenta

Funciona sin cuenta (inicio, explorar, novedades, búsqueda). Con sesión aparecen tu inicio
personalizado, **Playlists** (solo las de tu biblioteca de YouTube Music), tus álbumes y
**Me gusta**, y YouTube rechaza menos peticiones.

Opciones › Cuenta › **Iniciar sesión**. Se abre una ventana con la página de Google; entra con
tu cuenta y, al volver a YouTube Music, la ventana se cierra sola. La ventana es un programa
aparte con una sesión privada: al cerrarse no queda nada salvo las cookies de youtube.com.

- **macOS**: usa el WebKit del sistema; no hace falta nada más ni ningún permiso.
- **Linux**: usa Qt WebEngine (`sudo pacman -S qt6-webengine`, incluido en
  `scripts/instalar-linux.sh --dependencias`). Sin él, la app ofrece importar la sesión del
  navegador.

**Importar desde el navegador** (alternativa): la app usa la sesión que ya tienes abierta en tu
navegador.

1. Abre music.youtube.com en Chrome, Firefox, Brave… e inicia sesión allí.
2. En la app: Opciones › Cuenta → elige el navegador → **Iniciar sesión** (o **Importar de…**).
3. En macOS, importar exige **Acceso total al disco** para la app desde la que abres el
   reproductor, porque el sistema protege los datos de los navegadores.

Si la importación falla, `musicplayer --probe cookies chrome` (o el navegador que uses) explica el motivo sin
mostrar ni guardar ninguna cookie.

Solo se copian las cookies de youtube.com, a `cookies.txt` en la carpeta de configuración,
legible únicamente por tu usuario. **Cerrar sesión** lo borra. Si la sesión caduca, la app lo
detecta al arrancar y te avisa.

## Requisitos

- Rust 1.80 o superior (`cargo`)
- Qt 6.8 o superior: módulos base, declarative (QML/Quick) y shadertools
- mpv
- yt-dlp y un runtime de JavaScript para él: deno (recomendado) o Node.js

### macOS (Homebrew)

```bash
brew install rust qtbase qtdeclarative qtmultimedia qtshadertools mpv yt-dlp deno ffmpeg
```

### CachyOS / Arch Linux

```bash
sudo pacman -S rust qt6-base qt6-declarative qt6-multimedia qt6-shadertools mpv yt-dlp deno ffmpeg
```

> La compilación y las pruebas se han hecho en macOS. Linux no se ha probado todavía.

## Compilar e instalar

Guía completa para macOS y CachyOS, con scripts que crean la app o la entrada del menú:
**[COMPILAR.md](COMPILAR.md)**. Para probar rápido:

```bash
cargo run --release
```

La primera compilación tarda un par de minutos (genera el puente C++ de cxx-qt); las
siguientes, unos 10 s.

## Uso

| Acción | Cómo |
|---|---|
| Moverse por la vista | Flechas, rueda del ratón o clic |
| Abrir lo enfocado | `Intro`, doble clic en el Muro o clic en la carátula central. Una canción suena; un álbum, playlist o artista abre su detalle |
| En el detalle | `↑ ↓` elegir canción, `Intro` reproducir, `S` aleatorio, `I` inspeccionar, `Esc` volver |
| Inspeccionar una caja | `I` sobre un álbum o playlist: `← →` girar (contraportada con las canciones), `Espacio` abrir, `D` sacar el disco, `Intro` reproducir, `Esc` salir |
| Pausa / reanudar | `Espacio` |
| Cambiar de vista | `V` o el selector de arriba a la derecha |
| Buscar | `⌘F` / `Ctrl+F` o el campo «Buscar» |
| Opciones | `⌘,` / `Ctrl+,` o el botón de ajustes |
| Mini reproductor | `M` o el botón junto al volumen; `Esc` o la flecha vuelven a la ventana completa |
| Pantalla «Sonando» | Se abre sola al elegir una canción, o con un clic en la canción de la barra de reproducción: la carátula en grande sobre sus colores, y a la derecha la letra (si la hay) y la cola. Se cierra con un clic en la carátula, la flecha o `Esc` |
| Letra | Al estilo de Better Lyrics: la línea que suena, grande y brillante a un tercio de la altura, con sus palabras rellenándose al cantarse; las demás, atenuadas, y en las pausas instrumentales tres puntos. Clic en una línea salta a ese momento. Si en «Sonando» no quieres letra ni cola, el botón del panel de la barra las quita y centra la carátula. Opciones › Apariencia › «Calidad de la letra»: Calidad (todo a 60 Hz, ~32 % de CPU), Equilibrado (~20 %, por defecto) o Bajo (~14 %, lo mismo que con la cola a la vista) |
| Letra desincronizada | Bajo la letra: `−` la adelanta y `+` la atrasa medio segundo; se guarda para esa canción. Clic en el texto la deja en hora. Si no encaja, prueba otra fuente: pulsa su nombre («· NetEase ↻») y pasa a la siguiente (también se recuerda). Origen preferido, tamaño, tipo de letra y grosor en Opciones › Apariencia |
| Lista temporal | Clic derecho en una canción, álbum o playlist › «Añadir a la lista temporal». Se ve en la pestaña «Temporal» del panel: «Reproducir en bucle», quitar canciones o vaciarla. No se guarda al cerrar la app |
| Repetir | Botón de repetir junto a «Siguiente»: cada pulsación pasa de desactivado a repetir la cola y a repetir solo la canción (el icono lleva un «1»), y vuelta a desactivado. «Siguiente» sigue saltando de canción |
| Categorías de playlists | En Playlists, pestañas bajo la navegación (Todas, las tuyas y «+»). ↑/↓ o RePág/AvPág cambian de pestaña. Clic derecho en una playlist › «Categorías» › marca las suyas o «Nueva categoría…»; clic derecho en una pestaña para renombrarla o borrarla. Se guardan en este ordenador (YouTube Music no tiene carpetas) |
| Cola | Clic derecho en una canción, álbum o playlist › «Reproducir a continuación» (justo detrás de la que suena) o «Añadir a la cola» (al final). En la pestaña «Cola» (panel o «Sonando») arrastra una canción para cambiarla de sitio; su clic derecho la sube a la siguiente o la quita |
| Guardar en una playlist | Con sesión: clic derecho › «Guardar en una playlist» › elige una de tus playlists. Se guarda en tu cuenta (sin duplicar si ya estaba); un álbum o playlist añade todas sus canciones |
| Registrar escuchas | Con sesión, lo que escuchas cuenta en YouTube Music: historial, recomendaciones y reproducciones para el artista. Opciones › Reproducción › «Registrar en YouTube Music» lo desactiva. YouTube puede pausar otro dispositivo que suene a la vez con tu cuenta |
| Portada de una playlist | Clic derecho en una playlist tuya › «Cambiar portada…» (JPG o PNG de 360 × 360 o más). Se sube a tu cuenta y se ve también en la app del móvil |

Las opciones se guardan en `~/Library/Application Support/musicplayer/settings.json`
(macOS) o `~/.config/musicplayer/settings.json` (Linux).

## Problemas frecuentes

- **«No se pudo reproducir esta pista».** YouTube a veces rechaza las peticiones sin sesión,
  sobre todo tras muchas seguidas. Actualiza yt-dlp (`brew upgrade yt-dlp` o
  `sudo pacman -Syu yt-dlp`) y vuelve a intentarlo pasados unos minutos.
- **«No se pudo iniciar el motor de audio (mpv)».** mpv no está instalado o no está en
  `/opt/homebrew/bin`, `/usr/local/bin` ni en el `PATH`.
- **Sin letra.** La letra sincronizada viene de [LRCLIB](https://lrclib.net), NetEase Cloud
  Music y Kugou; no todas las canciones la tienen. Si la que sale no es la buena, pulsa el nombre
  de la fuente bajo la letra para probar la siguiente.

## Documentación

- [docs/GUIA.md](docs/GUIA.md): **guía para aprender el proyecto desde cero** (Rust y QML
  explicados con su propio código, recorrido de un clic, recetas y ejercicios).
- [COMPILAR.md](COMPILAR.md): compilar e instalar en macOS y CachyOS.
- [docs/AGENTES.md](docs/AGENTES.md): **normas para colaboradores y agentes** (comandos,
  convenciones, cómo verificar, cómo documentar).
- [docs/INDEX.md](docs/INDEX.md): qué leer para cada tarea; una ficha por área del programa en
  [docs/areas/](docs/areas/), decisiones en [docs/decisions/](docs/decisions/README.md) y
  procedimientos en [docs/runbooks/](docs/runbooks/).
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): cómo encajan las piezas, hilos y memoria.
- [docs/TRAMPAS.md](docs/TRAMPAS.md): errores conocidos de Qt, cxx-qt, mpv y YouTube.
- [docs/ROADMAP.md](docs/ROADMAP.md): qué falta y en qué orden.
