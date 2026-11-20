# Trabajo en curso

Nota de la tarea larga que está a medias, para quien la retome sin memoria de la conversación
(otra persona, otro agente o el mismo tras compactar el contexto). Cómo se usa:
[runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md).

- **Se actualiza al terminar cada paso**, no al final.
- **Se vacía al unir la rama** (deja solo «Ninguna tarea en curso»): lo que valga la pena guardar
  pasa antes a su ficha, a una ADR o al historial.

---

## Carátula animada de Apple Music en «Sonando» · rama `feature/caratula-animada`

- **Objetivo:** el propietario pidió (2026-11-20) que, si el álbum de lo que suena tiene en Apple
  Music una carátula animada (como *DELTARUNE Piano Collections*), «Sonando» la muestre en vez de
  la fija.
- **Áreas:** [ventana](areas/ventana.md).
- **Decisiones tomadas en la conversación:** se propusieron A (vídeo en directo), B (descargar una
  vez con ffmpeg y reproducir de la caché) y C (WebP animado); el propietario eligió la B y
  autorizó `brew install qtmultimedia`. Escrito en [ADR-21](decisions/ADR-21-caratula-animada-de-apple-music.md),
  la ficha de ventana y AGENTES §11.
- **Hecho (sin commit):** `src/animada.rs`, `Player.animada`/`buscarAnimada`,
  `qml/MotionCover.qml`, `shaders/redondeo.frag`, opción `caratulaAnimada`, `--probe animada`,
  dependencias en COMPILAR, README y los scripts; build sin avisos, tests, capturas, medida y
  documentación.
- **Falta:** commits y unir a `master` con el visto bueno del propietario.
- **Cómo retomarla:** `git switch feature/caratula-animada`, `git status`.
- **Cuidado:** `--play ID` sin `--play-title` deja el título vacío y no se pide la animación.

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
