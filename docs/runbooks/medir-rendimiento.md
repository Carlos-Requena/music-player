# Medir memoria y CPU

La primera prioridad del propietario es el consumo; la segunda, la respuesta. Si un cambio puede
afectar a cualquiera de las dos, se mide **en release** y se apunta en la sección «Medidas» de la
ficha del área (o en [ARCHITECTURE](../ARCHITECTURE.md#memoria-y-arranque) si es global), con
fecha y máquina. La medida anterior se mueve a `docs/history/verificacion/<area>.md`.

## Antes

- `cargo build --release`; `HOME` de pruebas y `MUSICPLAYER_SILENT=1`
  ([verificar-interfaz](verificar-interfaz.md#aislar-las-pruebas)).
- Cierra la app del propietario si está abierta **solo con su permiso**; si no, mide igual y dilo.
- Misma ventana (1440×900), misma pantalla (Retina o no) y la misma canción en las comparaciones.

## Memoria

```bash
HOME="$PRUEBA" MUSICPLAYER_SILENT=1 ./target/release/musicplayer --section albumes --autoplay &
APP=$!
sleep 30
footprint $APP | grep -i "phys_footprint"      # macOS: la del Monitor de Actividad
kill $APP
```

En Linux, `grep VmRSS /proc/$APP/status` (no es la misma cifra: compara solo con Linux). mpv va
aparte: `footprint $(pgrep -f "mpv --idle")`.

## CPU

Con tiempo acumulado, nunca `ps %cpu` (es una foto de un instante):

```bash
HOME="$PRUEBA" MUSICPLAYER_SILENT=1 ./target/release/musicplayer \
  --section albumes --index 5 --autoplay --tab letra --shot "$PRUEBA/c.png" --delay 40000 &
APP=$!
sleep 12; A=$(ps -o time= -p $APP)
sleep 25; B=$(ps -o time= -p $APP)
echo "$A → $B"
wait $APP
```

- La diferencia entre `A` y `B` es la CPU de 25 s (×4 = % de un núcleo).
- **Comprueba en la línea `estado:`** que sonaba la canción esperada.
- Repite al menos dos veces: el ruido es de ±1 s.

## Tiempos

- Arranque de pista: stderr escribe `arranque de pista: N ms`; `--probe play ID` mide el arranque
  aislado.
- Arranque de la app: hasta que la ventana está lista y hasta ver contenido.

## Qué apuntar

En «Medidas» de la ficha: situación, cifra, fecha y máquina (`2026-11-14, M4 Pro, release`). Si
algo se probó y se descartó por lo que costaba, va en «Reglas y decisiones» (una línea) o en una
ADR, con la cifra.
