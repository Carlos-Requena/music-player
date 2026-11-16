# Trabajo en curso

Nota de la tarea larga que está a medias, para quien la retome sin memoria de la conversación
(otra persona, otro agente o el mismo tras compactar el contexto). Cómo se usa:
[runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md).

- **Se actualiza al terminar cada paso**, no al final.
- **Se vacía al unir la rama** (deja solo «Ninguna tarea en curso»): lo que valga la pena guardar
  pasa antes a su ficha, a una ADR o al historial.

---

## Letra de varias fuentes y palabra a palabra · rama `feature/letra`

- **Objetivo:** «utilizar varias fuentes y que se pueda elegir» (mucho anime que no está en las
  fuentes normales) y que la letra se ilumine palabra a palabra **a tiempo** («muchas veces no
  encaja conforme se ilumina»).
- **Áreas:** [letra](areas/letra.md).
- **Decisiones tomadas en la conversación (2026-11-16)**, ya escritas en la ficha
  [letra](areas/letra.md), en [ADR-18](decisions/ADR-18-letra-de-varias-fuentes.md) y en
  AGENTES §11: fuentes LRCLIB, NetEase y Kugou con «Automática» por defecto (`letraOrigen`, fila
  «Origen de la letra»); cambio por canción con el **diseño A** (nombre de la fuente en el pie,
  `origen:<videoId>`); líneas sin tiempos por palabra **enteras** por defecto y «Estimado» como
  opción (`letraSinTiempos`).
- **Hecho (sin commit, falta el visto bueno del propietario):** todo el código y la
  documentación; `cargo build --release` sin avisos, `cargo test` en verde, `--probe lyrics`
  contra las tres fuentes, capturas del panel y de Opciones, clic simulado en la fuente.
- **Falta:** ver el barrido sílaba a sílaba con música y medir su CPU en release
  (`docs/runbooks/medir-rendimiento.md`) cuando YouTube deje reproducir sin sesión (el
  2026-11-16 pedía sesión también a `yt-dlp`); `--autoplay` de verificar-reproduccion; commit y
  unir a `master`.
- **Cómo retomarla:** `git switch feature/letra`, `git status`, y
  `HOME=$(mktemp -d) MUSICPLAYER_SILENT=1 ./target/release/musicplayer --shot /tmp/x.png --delay 40000 --search "紅蓮華 LiSA" --autoplay --autoplay-delay 5000 --panel --tab letra`.
- **Cuidado:** en KRC los tiempos de cada sílaba son relativos al comienzo de la línea; en YRC,
  absolutos. `docs.py check` ya fallaba en `master` por `docs/guia/guia.{aux,log,…}` subidos a git
  (no es de esta tarea).

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
