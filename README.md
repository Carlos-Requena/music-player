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
| **Muro** | Cuadrícula de carátulas por zonas | Inicio, Explorar |

Cada sección puede usar cualquier vista (Opciones → «Vista de cada sección», el selector de
arriba a la derecha o la tecla `V`). El estilo de ventana puede ser **Vidrio** (panel de letra
y cola a la derecha) o **Escenario** (letra sobre el escenario y reproductor en píldora).

> Cliente **no oficial**: depende de cómo YouTube sirva su contenido. Cuando YouTube cambia
> algo, suele bastar con actualizar yt-dlp.

## Calidad y velocidad

- **Arranque de las canciones**: ~0,5 s desde el clic sin precarga y ~0,1 s con ella (lo
  enfocado, lo que está bajo el ratón y la siguiente de la cola se preparan solos).
- **Calidad**: «Alta» (por defecto) da Opus a ~160 kbps, lo máximo que ofrece YouTube Music sin
  Premium. Con **YouTube Premium** y la sesión iniciada, elige «Premium · 256 kbps» en
  Opciones › Disposición › Calidad del audio. El panel muestra el formato real que suena.

## Personalización

En **Opciones**:

- **Aspecto**: skins Vidrio, Medianoche, Grafito y Neón, más las tuyas.
- **Disposición**: panel de letra y cola a la izquierda o a la derecha, modo ambiente,
  desenfoque (desactivarlo ahorra memoria y batería) y tamaño de las carátulas del Muro.
- **Vista de cada sección** y estilo de ventana (Vidrio o Escenario).

### Crear una skin

Copia uno de los archivos de [`skins/`](skins) a la carpeta de skins
(`~/Library/Application Support/musicplayer/skins/` en macOS,
`~/.config/musicplayer/skins/` en Linux), cámbiale el nombre y edítalo. Después pulsa
**Recargar skins** en Opciones.

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

La configuración de los plugins (con el secreto y la sesión de Last.fm) se guarda en
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
brew install rust qtbase qtdeclarative qtshadertools mpv yt-dlp deno
```

### CachyOS / Arch Linux

```bash
sudo pacman -S rust qt6-base qt6-declarative qt6-shadertools mpv yt-dlp deno
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
| Pantalla «Sonando» | Clic en la canción de la barra de reproducción: la carátula en grande sobre sus colores. Se cierra con un clic en la carátula, la flecha o `Esc` |
| Lista temporal | Clic derecho en una canción, álbum o playlist › «Añadir a la lista temporal». Se ve en la pestaña «Temporal» del panel: «Reproducir en bucle», quitar canciones o vaciarla. No se guarda al cerrar la app |
| Repetir la cola | Botón de repetir junto a «Siguiente» |

Las opciones se guardan en `~/Library/Application Support/musicplayer/settings.json`
(macOS) o `~/.config/musicplayer/settings.json` (Linux).

## Problemas frecuentes

- **«No se pudo reproducir esta pista».** YouTube a veces rechaza las peticiones sin sesión,
  sobre todo tras muchas seguidas. Actualiza yt-dlp (`brew upgrade yt-dlp` o
  `sudo pacman -Syu yt-dlp`) y vuelve a intentarlo pasados unos minutos.
- **«No se pudo iniciar el motor de audio (mpv)».** mpv no está instalado o no está en
  `/opt/homebrew/bin`, `/usr/local/bin` ni en el `PATH`.
- **Sin letra.** La letra sincronizada viene de [LRCLIB](https://lrclib.net); no todas las
  canciones la tienen.

## Documentación

- [COMPILAR.md](COMPILAR.md): compilar e instalar en macOS y CachyOS.
- [AGENTS.md](AGENTS.md): guía para colaboradores y agentes (cómo está montado, convenciones,
  cómo probar, trampas conocidas).
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): flujo de datos, hilos, arranque instantáneo de
  pistas y medidas de memoria.
- [docs/ROADMAP.md](docs/ROADMAP.md): qué falta y en qué orden.
