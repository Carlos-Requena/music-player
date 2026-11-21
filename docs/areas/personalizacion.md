---
area: personalizacion
titulo: Opciones, skins y aspecto
resumen: Preferencias guardadas (vista por sección, skin, opciones genéricas), la hoja de Opciones, los tokens visuales de Theme, el vidrio y el modo ambiente.
archivos: [src/settings.rs, qml/Theme.qml, qml/SettingsSheet.qml, qml/Ambient.qml, qml/TintProbe.qml, skins/vidrio.json, skins/medianoche.json, skins/grafito.json, skins/neon.json]
opciones: [ambiente, ambienteMovimiento, desenfoque, esquinas, compacto]
adr: [ADR-11, ADR-17, ADR-23]
---

# Opciones, skins y aspecto

Opciones (el engranaje), por categorías en una barra lateral: Cuenta, Reproducción, Apariencia,
Vistas y Plugins. Cómo crear una skin o una mascota, para quien usa la app: [README](../../README.md#crear-una-skin).

## Qué hace

- **Skins**: Vidrio, Medianoche, Grafito y Neón incluidas, más las del usuario en
  `<config>/musicplayer/skins/` (archivo JSON o carpeta con imagen de fondo). Cambiar de skin no
  necesita reiniciar.
- **Opciones de disposición** genéricas (`AppSettings.opcion`/`setOpcion`), guardadas en
  `<config>/musicplayer/settings.json`. Se aplican al momento, sin reiniciar: `setOpcion` y
  `setVista` suben `AppSettings.revision`, y `opcion(clave, revision)` y `vista(seccion, revision)`
  piden esa revisión como argumento para que cada enlace de QML dependa de ella (un `void`
  suelto lo descarta el compilador de QML, ver [TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)). Las de cada área están en el `opciones:` de su ficha; la
  tabla completa, en [INDEX](../INDEX.md#opciones).
- **Modo ambiente** (`ambiente`): focos de color suaves, uno teñido por lo enfocado y otro por lo
  que suena. Vivo (por defecto), Suave y Tenue (un solo foco), **Plano** y No. **Plano**, por
  petición del propietario para pantallas antiguas que muestran los degradados con escalones:
  todo el fondo de un solo color sólido (el de fondo de la skin mezclado con el de lo enfocado,
  `Theme.ambientFlat`), sin focos, sin el suelo oscuro y sin el halo de la carátula de «Sonando».
  **Fluido**, por petición del propietario (estilo Better Lyrics Shaders): la carátula, muy
  desenfocada y deformada, es el fondo (la enfocada en la ventana, la que suena en «Sonando»),
  con un fundido de un segundo al cambiar; en «Sonando» la letra y la cola van sobre él sin
  recuadro. Con movimiento, sus colores fluyen; sin él, queda quieto
  ([ADR-17](../decisions/ADR-17-fondo-fluido-con-sombreador-propio.md)).
  **Movimiento del ambiente** (`ambienteMovimiento`), elegido por el propietario entre cuatro
  propuestas (respiración, deriva, oleada, carátula fluida): «deriva lenta», los focos pasean
  despacio, cada uno por su camino (una vuelta cada ~40 s), solo mientras suena música. No (por
  defecto), En Sonando o Siempre. Quien usa el fondo lo enciende con `Ambient.moving`.
  **Desenfoque** (`desenfoque`): desactivarlo ahorra memoria y batería.
- **Esquinas de las carátulas** (`esquinas`), a elegir por el propietario: «Redondeadas» (por
  defecto) o «Cuadradas» (`Theme.roundCovers`, `Theme.coverRadius`). Ver la regla de medidas abajo.
- **Hoja compacta** (`compacto`), un segmento «Normal / Compacta» junto a la × de Opciones, por
  petición del propietario cuando crecieron las opciones: sin descripciones en las filas (la de
  la fila bajo el ratón sale en un pie de la hoja, sin mover nada), filas y huecos más bajos y
  miniaturas de skin (seis por fila) y mascota más pequeñas.

## Reglas y decisiones

- **Skins en JSON y opciones como mapa clave → valor**
  ([ADR-11](../decisions/ADR-11-skins-en-json-y-opciones-genericas.md)): una skin con el mismo id
  que una incluida la sustituye; las mal formadas se ignoran con un aviso en stderr.
- **Colores solo por `Theme`**; lo que falte en una skin toma el valor de Vidrio (`pick`). Un color
  nuevo: [runbooks/nuevo-color-de-skin.md](../runbooks/nuevo-color-de-skin.md). `error` (errores de
  reproducción y de la cuenta) va aparte del acento, que queda para «activado» y «suena».
- **Medidas solo por `Theme`** ([ADR-23](../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)):
  tipografía en ocho niveles (`fontDisplay` 40 … `fontMini` 11), `margin` 32 (borde del contenido y
  de los botones sueltos en todas las pantallas), `gap` 12 (paneles de vidrio pegados a la
  ventana) y radios `radiusS`/`radiusM`/`radiusL` = 0,4 / 0,7 / 1 × el `radio` de la skin. Las
  carátulas toman `coverRadius(lado)`: S hasta 120 px, M por encima, 0 con «Cuadradas». También
  `scrim` (velo de lo que tapa el escenario), `well` (pozo de pestañas y campos), `placeholder`,
  `rowHeight`. `docs.py check` rechaza tamaños de letra, radios y colores escritos a mano en
  `qml/`; una línea que lo necesite lleva `// fijo: <motivo>`.
- **Opción nueva**: [runbooks/nueva-opcion.md](../runbooks/nueva-opcion.md). Vacío = valor por
  defecto (`fallback` de su fila).
- **`TintProbe` (Canvas)** necesita su propio `loadImage` y su `Timer`, y estar dentro de la zona
  visible ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)). Al cambiar de carátula suelta la anterior
  (`unloadImage`): si no, cada sonda guardaba todas las que había visto.
- **`settings.json` se escribe en un hilo y de una vez** (`write_settings`, `write_atomic`): un
  solo hilo escribe siempre la última versión, en un archivo aparte que luego se renombra. Si la
  app se cierra a mitad, queda el anterior entero.
- **«Fluido» es un sombreador propio** (`shaders/fluido.frag`), precompilado con
  `scripts/shaders.sh` y guardado con su `.qsb`
  ([ADR-17](../decisions/ADR-17-fondo-fluido-con-sombreador-propio.md)). Avanza a 15 Hz con el
  mismo `drifting` que la deriva, se dibuja a la mitad de la resolución lógica y limita el brillo
  de las carátulas claras, porque encima va texto blanco.
- **La deriva avanza a 10 Hz con un `Timer`, no con una animación a 60 fps**: medido el
  2026-11-16, a 60 fps costaba un 25–30 % de un núcleo (cada vidrio vuelve a desenfocar el fondo en
  cada fotograma) y a 10 Hz ~5 %, sin que el paseo, tan lento, se vea a saltos. En los dos casos la
  memoria sube unos 100 MB mientras se redibuja sin parar, por eso va desactivada por defecto. Se
  para en pausa, con la ventana oculta o minimizada (mini reproductor), en «Plano» y sin ambiente
  (`Ambient.drifting`); en «Siempre», el fondo de la ventana se para mientras «Sonando» está
  abierta (se mueve el suyo).
- **Con Opciones abierta, el ratón no llega a lo de debajo**: un `HoverHandler` con `blocking` en
  la capa de la hoja corta el «hover» (brillo del Muro, nombre de abajo, pestañas de la
  navegación); lo de la hoja va encima y sigue reaccionando. Lo pidió el propietario.
- **Opciones que tocan Rust** (`calidad`, `historial`, `ytdlp`) se aplican al cargar y al cambiar,
  en `set_opcion`.

## Interfaz

`SettingsSheet.qml`: barra lateral de categorías (pestañas en columna: la elegida, en blanco,
porque dice dónde estás); las filas sueltas se declaran en `optionRows` (`cat`, `key`, `label`,
`hint`, `fallback`, `options`); las de Cuenta y Plugins son bloques propios. Los valores se eligen
con `Segmented` (`Tabs` en vidrio claro: regla de dos, [interfaz-comun](interfaz-comun.md)).
`--settings-cat id` abre una categoría para capturarla.

En Apariencia, diseño elegido por el propietario con sus muestras:

- **Skin**: cuatro tarjetas por fila con una miniatura pintada con los colores de cada skin
  (`SkinPreview`: barra de arriba, cuatro carátulas, barra de reproducción con su acento; las de
  carpeta con fondo lo muestran detrás), el nombre debajo y un aro en la elegida (`ChosenRing`).
  Debajo, la descripción de la elegida.
- **Mascota**: recuadros con su pose de reposo, «Ninguna» vacío y «Añadir…» (borde discontinuo),
  que abre la carpeta de mascotas.
- **Encabezados con dos botones** (`FolderHeading`): abrir la carpeta del usuario (se crea si
  falta) y recargar.

Los datos de las miniaturas salen de `skins_list` (Rust): `colores`, `radio` e `imagen` (fondo de la
skin o pose `reposo` de la mascota, con la ruta de su carpeta).

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Inicio quieto, sin música (1440×900, Retina) | 0,07 s de CPU en 25 s; 195 MB | 2026-11-16, M4 Pro, release |
| Deriva «Siempre» en Inicio | 1,3 s de CPU en 25 s (~5 %); 320 MB | 2026-11-16, M4 Pro, release |
| Deriva «En Sonando», con «Sonando» abierta / en Inicio | 1,3 s (~5 %), 305 MB / 0,07 s, 196 MB | 2026-11-16, M4 Pro, release |
| Deriva «Siempre» con la ventana minimizada o en el mini | 0,06 s de CPU en 20 s | 2026-11-16, M4 Pro, release |
| «Fluido» quieto, en Inicio | 0,08 s de CPU en 25 s; 196 MB | 2026-11-16, M4 Pro, release |
| «Fluido» moviéndose (15 Hz): Inicio / «Sonando» | 2,2 s (~9 %), 317 MB / 2,2 s, 301 MB | 2026-11-16, M4 Pro, release |

Estas medidas se tomaron quitando a mano la condición de que suene música (YouTube pedía sesión).

## Archivos

| Archivo | Contenido |
|---|---|
| `src/settings.rs` | Singleton `AppSettings`: vistas, skin, mascota, opciones; skins incluidas y del usuario |
| `qml/Theme.qml` | Tokens visuales: colores de la skin, medidas comunes (letra, margen, radios), opciones de aspecto, iconos, `renderEpoch` |
| `qml/SettingsSheet.qml` | Hoja de Opciones |
| `qml/Ambient.qml` | Modo ambiente |
| `qml/TintProbe.qml` | Color dominante de una carátula |
| `shaders/fluido.frag` (+ `.qsb`) | Sombreador del fondo «Fluido»; se compila con `scripts/shaders.sh` |
| `skins/*.json` | Las cuatro skins incluidas |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Leer y guardar una opción | [`opcion`](../../src/settings.rs), [`set_opcion`](../../src/settings.rs) |
| Vistas por defecto | [`DEFAULT_VIEWS`](../../src/settings.rs) |
| Skins incluidas | [`BUILTIN_SKINS`](../../src/settings.rs) |
| Juntar skins incluidas y del usuario | [`all_skins`](../../src/settings.rs) |
| Color con valor por defecto | [`pick`](../../qml/Theme.qml) |
| Radio de una carátula (opción `esquinas`) | [`coverRadius`](../../qml/Theme.qml) |
| Pie de descripciones de la hoja compacta | [`showHint`](../../qml/SettingsSheet.qml) |
| Imagen de una skin de carpeta | [`skinImage`](../../qml/Theme.qml) |
| Filas de Opciones | [`optionRows`](../../qml/SettingsSheet.qml) |
| Fondo «Fluido» y su fundido | [`fluid`](../../qml/Ambient.qml), [`fluido.frag`](../../shaders/fluido.frag) |
| Datos de las miniaturas | [`skins_list`](../../src/settings.rs), [`preview_image`](../../src/settings.rs) |
| Miniatura de una skin | [`SkinPreview`](../../qml/SettingsSheet.qml) |

## Dependencias

- **[resolucion](resolucion.md)** (`resolver::set_premium`, `daemon::set_enabled`): aplicar
  `calidad` e `ytdlp`.
- **[historial](historial.md)** (`history::set_enabled`): aplicar `historial`.
- **[sesion](sesion.md)** (`Account`): la pestaña Cuenta.
- **[reproduccion](reproduccion.md)** (`Player.playing`): la deriva del ambiente solo avanza
  mientras suena.
- **[plugins](plugins.md)** (`Plugins`): la pestaña Plugins.
- **[catalogo](catalogo.md)** (`Catalog`): secciones en «Vista de cada sección».
- **[interfaz-comun](interfaz-comun.md)** (`WheelScroll`, `Tabs`, botones): la rueda y los controles de la hoja de Opciones.
- **La usan:** todas (por `Theme` y `AppSettings`); [mascotas](mascotas.md) lee la elegida con
  `Theme.mascotImage`.

## Estado actual

- **Última verificación:** 2026-11-21, las opciones se aplican sin reiniciar ([historial](../history/verificacion/personalizacion.md)).
- **Pruebas:** `preview_image` y `skins_list` en `cargo test`; capturas con `--settings-cat`;
  `--set clave valor` cambia una opción en marcha y la línea `opciones:` dice si se aplicó.
- **Sin verificar:** que «Fluido» fluya bien a la vista (la CPU confirma que se redibuja, pero cada
  prueba sacaba otra canción y no se compararon dos fotogramas de la misma carátula); el fundido
  entre carátulas; «Fluido» en Linux (OpenGL/Vulkan) y en Windows; la deriva con música sonando de verdad (YouTube pedía sesión); en Linux;
  «Plano» en una pantalla antigua de verdad (solo en Retina); skins claras (los velos asumen fondo oscuro); la miniatura de una skin de
  carpeta con fondo; abrir la carpeta en Linux (`xdg-open`); la hoja compacta con el teclado (el
  pie solo sigue al ratón).
- **Historial:** [docs/history/verificacion/personalizacion.md](../history/verificacion/personalizacion.md).

## Pendiente

- Editor de disposición, skins claras y skins con QML propio ([ROADMAP](../ROADMAP.md)).
- «Fluido» sin probar: reaccionar al ritmo (lo hace Better Lyrics Shaders) y las carátulas
  animadas.
