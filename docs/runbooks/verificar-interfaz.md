# Verificar la interfaz con capturas

Toda pantalla tocada se captura y se revisa a ojo antes de dar la tarea por terminada
([AGENTES §8](../AGENTES.md#8-norma-verificar-antes-de-dar-algo-por-terminado)). `Main.qml` acepta
argumentos de depuración; con `--shot` guarda una captura, escribe una línea `estado: …` con el
estado del reproductor y sale.

## Aislar las pruebas

Siempre, antes de lanzar nada:

```bash
cargo build --release
export PRUEBA="$(mktemp -d)"          # HOME de pruebas: preferencias, caché y sesión propias
HOME="$PRUEBA" MUSICPLAYER_SILENT=1 ./target/release/musicplayer --shot "$PRUEBA/captura.png" --delay 3000
```

- `HOME=$PRUEBA` aísla `settings.json`, la sesión y la caché del propietario.
- `MUSICPLAYER_SILENT=1` hace que mpv reproduzca sin sonido (`--ao=null`).
- Sin ventana visible: `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software` (el desenfoque y el
  vidrio cambian: compruébalos con ventana).
- Para probar con una opción puesta, escribe un `settings.json` en el `HOME` de pruebas
  (`$PRUEBA/Library/Application Support/musicplayer/` en macOS, `$PRUEBA/.config/musicplayer/` en
  Linux) con `{"opciones": {"clave": "valor"}}`.

## Argumentos de Main.qml

```bash
HOME="$PRUEBA" MUSICPLAYER_SILENT=1 ./target/release/musicplayer \
  --shot "$PRUEBA/captura.png" --delay 20000 \
  --section albumes --index 5 \
  --autoplay --autoplay-delay 6000 --then-next 15000
```

| Argumento | Efecto |
|---|---|
| `--shot ruta.png` | Captura la ventana y sale |
| `--delay ms` | Espera antes de capturar (por defecto 1500) |
| `--section id` | `inicio`, `explorar`, `playlists`, `albumes` o `buscar` |
| `--index n` | Lleva Lomos o Cubeta al elemento `n` |
| `--step n` | Mueve la vista `n` elementos (negativo = izquierda) a los `--step-delay` ms (1500 por defecto); con `--delay` se captura en mitad del movimiento |
| `--search texto` | Busca al arrancar |
| `--settings` | Abre las opciones |
| `--settings-end` | Abre las opciones desplazadas hasta el final |
| `--settings-cat id` | Abre las opciones en esa categoría (`cuenta`, `reproduccion`, `apariencia`, `vistas`, `plugins`) |
| `--settings-at y` | Abre las opciones desplazadas `y` píxeles |
| `--minimize ms` | Minimiza la ventana tras ese tiempo; con `--hide` la oculta y con `--mini` abre el mini reproductor (la captura toma entonces el mini) |
| `--restore ms` | (con `--minimize`) vuelve a la ventana grande tras ese tiempo; con `--mini`, como el botón del mini |
| `--now` | Arranca con la pantalla «Sonando» abierta |
| `--tab id` | Abre esa pestaña del panel (`letra`, `cola`, `temporal`) |
| `--temporal` | (con `--autoplay`) añade el elemento enfocado a la lista temporal y abre el menú sobre él |
| `--panel` | Arranca con el panel de letra y cola abierto (sin él, arranca oculto) |
| `--autoplay` | Reproduce el elemento enfocado |
| `--autoplay-delay ms` | Espera antes de reproducir (deja tiempo a la precarga) |
| `--then-next ms` | Pasa a la pista siguiente tras ese tiempo |
| `--open` | (con `--autoplay`) abre el detalle del elemento enfocado en vez de reproducirlo |
| `--shuffle` | (con `--open`) pulsa «Aleatorio» a los 5 s |
| `--inspect [flip\|open\|disc]` | (con `--autoplay`) inspecciona el elemento y deja la caja girada, abierta o con el disco fuera |

Un argumento nuevo se añade a `Main.qml` (`arg`) y a esta tabla en la misma tarea.

## Clics de verdad

`MUSICPLAYER_DEBUG_CLICK="x,y,boton,ms;…"` envía clics de ratón a la ventana (`boton`: `left` o
`right`; coordenadas lógicas; `ms` desde el arranque). Por ejemplo,
`"120,250,right,5000;245,348,left,5500"` abre el menú de la primera tarjeta de Inicio y pulsa
«Reproducir a continuación». `"x,y,drag,ms,x2,y2"` arrastra con el botón izquierdo hasta
`(x2, y2)` y `draghold` lo hace sin soltar (para capturar a mitad del gesto, p. ej. reordenando
la cola). `"x,y,wheel,ms,pasos"` gira la rueda `pasos` muescas (positivo, hacia abajo).

## Qué mirar

1. **La pantalla que tocaste**, en su estado normal y en el raro (vacía, sin sesión, con un título
   largo, con el panel a la izquierda).
2. **Con otra skin** si tocaste colores (al menos Vidrio y Neón).
3. **La terminal:** QML escribe ahí sus errores (`qrc:/…qml:123: …`); ninguno nuevo.
4. **La línea `estado:`** si había reproducción.

## Trampas del entorno (no son fallos de la app)

- **Inicio cambia de una ejecución a otra**: compara capturas de Álbumes o de una búsqueda fija.
- **La red tarda**: si la captura sale vacía, sube `--delay` antes de concluir nada.
- **YouTube rechaza la IP** tras muchas pruebas seguidas ([TRAMPAS](../TRAMPAS.md#youtube-yt-dlp-y-mpv)).
- **Offscreen y software** no pintan igual el desenfoque: lo visual se comprueba con ventana.
