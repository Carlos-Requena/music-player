# Trabajo en curso

Nota de la tarea larga que está a medias, para quien la retome sin memoria de la conversación
(otra persona, otro agente o el mismo tras compactar el contexto). Cómo se usa:
[runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md).

- **Se actualiza al terminar cada paso**, no al final.
- **Se vacía al unir la rama** (deja solo «Ninguna tarea en curso»): lo que valga la pena guardar
  pasa antes a su ficha, a una ADR o al historial.

---

## Explorar con ListenBrainz (Troi) · rama `feature/explorar-listenbrainz`

- **Objetivo:** el propietario pidió «incorporar Troi» (troi-recommendation-playground) para que
  Explorar muestre sus recomendaciones en vez del Explorar de YouTube Music.
- **Áreas:** [catalogo](areas/catalogo.md), [plugins](areas/plugins.md).
- **Decisiones tomadas en la conversación (2026-11-17):** opción A, la API de ListenBrainz desde
  Rust (ListenBrainz ya ejecuta Troi en su servidor), sin Troi local en Python; Explorar de
  YouTube **se sustituye**; el propietario no tiene cuenta de ListenBrainz, así que se añade un
  plugin que envía las escuchas (token). Escrito en
  [ADR-19](decisions/ADR-19-explorar-con-listenbrainz.md) y en AGENTES §11.
- **Hecho (sin commit):** `src/listenbrainz.rs`, `src/plugins/listenbrainz.rs`, Explorar en su
  hilo en `src/library.rs`, detalle `lb:<mbid>`, fila en Opciones › Plugins; fichas, historiales,
  README, ARCHITECTURE, runbook; build, tests y capturas.
- **Después pidió (hecho, sin commit):** elegir en Opciones la fuente de Explorar (ListenBrainz o
  YouTube Music, [ADR-20](decisions/ADR-20-fuente-de-explorar-a-elegir.md)) y una sección
  Historial con su historial de escucha (YouTube Music, con sesión).
- **Falta:** visto bueno del propietario para el commit y unir a `master`; que el propietario
  conecte su token, compruebe el envío de escuchas y mire Historial con su sesión.
- **Cómo retomarla:** `git switch feature/explorar-listenbrainz`, `git status`.
- **Cuidado:** ListenBrainz pide como mucho una petición por segundo y un User-Agent propio.

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
