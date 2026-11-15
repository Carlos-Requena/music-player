# Historial de verificación · Mascotas

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/mascotas.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-15 · Expresiones de Ralsei, reacciones y «Me gusta» al pincharla

Rama `feature/mascotas`. Ralsei gana ocho poses (recortadas de una hoja de expresiones con el
quitado de fondo de Vision, conservando los trazos sueltos como «?» o el resoplido) y las
reacciones `clic`, `megusta`, `fallo`, `enfado`, `saltada` y `playlist`; en Opciones se pasa a la
esquina inferior izquierda del panel. Antes la pose `clic` era un estado más (`poked`) por debajo de
`error` y `cargando`, y la mascota dejaba pasar los clics a lo de debajo.

Verificado con `HOME` de pruebas, `MUSICPLAYER_SILENT=1`, offscreen y `MUSICPLAYER_DEBUG_CLICK`:

- Pincharla sin música → vergüenza; cinco pinchazos en 1,2 s → enojo.
- `--autoplay` y clic en «Siguiente» → desilusión, sin abrir «Sonando».
- `--settings --settings-cat apariencia` → en la esquina inferior izquierda del panel, y fuera de
  la barra.
- `cargo build --release` sin avisos, `cargo test` en verde.

**No verificado:** YouTube pedía «Sign in to confirm you're not a bot» sin sesión (también con
`yt-dlp` directo), así que nada llegó a sonar: ni el «Me gusta» real ni la secuencia vergüenza →
alegría con música; tampoco la reacción a guardar en una playlist (necesita sesión), ni Linux.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
