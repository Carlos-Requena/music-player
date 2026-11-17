# Trabajo en curso

Nota de la tarea larga que está a medias, para quien la retome sin memoria de la conversación
(otra persona, otro agente o el mismo tras compactar el contexto). Cómo se usa:
[runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md).

- **Se actualiza al terminar cada paso**, no al final.
- **Se vacía al unir la rama** (deja solo «Ninguna tarea en curso»): lo que valga la pena guardar
  pasa antes a su ficha, a una ADR o al historial.

---

## Rendimiento: letra y resto de la auditoría · rama `perf/letra`

- **Objetivo:** bajar CPU y memoria según la auditoría de rendimiento del 2026-11-16. El
  propietario aprobó primero el bloque «Letra» (L1–L7 y B1) y después pidió seguir con «el resto»
  en la misma rama: precarga (R1–R5), vistas (V1–V7), puente (J1–J3) y estructura (S1).
- **Áreas:** [letra](areas/letra.md), [ventana](areas/ventana.md), [reproduccion](areas/reproduccion.md),
  [resolucion](areas/resolucion.md), [catalogo](areas/catalogo.md), [vistas](areas/vistas.md),
  [personalizacion](areas/personalizacion.md), [mascotas](areas/mascotas.md),
  [interfaz-comun](areas/interfaz-comun.md).
- **Decisiones tomadas en la conversación:** la cascada de la letra se deja como está (opción A)
  mientras el propietario no elija otra; todo en la rama `perf/letra`.
- **Hecho (sin commit, falta el visto bueno del propietario):** todo el código, medidas antes y
  después (en las fichas y sus historiales), `cargo build --release` sin avisos, `cargo test` en
  verde, capturas; fichas, historiales y una trampa nueva (`ListView` y `leftMargin`).
- **No hecho de S1, a propósito:** sacar el arnés de depuración de `Main.qml` a su propio archivo
  y partir `player.rs`. Son reorganizaciones sin efecto en memoria ni en tiempos y con riesgo de
  romper las pruebas con `--shot`; se proponen aparte.
- **Falta:** commits (dos: letra y resto) y unir a `master` con el visto bueno del propietario.
- **Cómo retomarla:** `git switch perf/letra`, `git status`.
- **Cuidado:** `docs.py check` sigue marcando los `docs/guia/guia.*` que están en git desde antes
  (no es de esta tarea). YouTube pedía sesión: las medidas con música usan
  `MUSICPLAYER_DEBUG_AUDIO` y `--play` ([medir-rendimiento](runbooks/medir-rendimiento.md)).

<!--
Esqueleto (cópialo encima de «Ninguna tarea en curso» y bórrala):

## <Tarea> · rama `<feature/nombre>`

- **Objetivo:** <qué pidió el propietario, con sus palabras si importan>.
- **Áreas:** [<area>](areas/<area>.md).
- **Decisiones tomadas en la conversación:** <cada una, con dónde se ha escrito ya (ficha, ADR,
  AGENTES §11) o «falta escribirla»>.
- **Hecho:** <pasos terminados, con el commit si lo hay>.
- **Falta:** <pasos, en orden>.
- **Cómo retomarla:** <el primer comando o archivo que hay que abrir>.
- **Cuidado:** <lo que se probó y no funcionó, para no repetirlo>.
-->
