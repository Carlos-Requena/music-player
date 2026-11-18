# Trabajo en curso

Nota de la tarea larga que está a medias, para quien la retome sin memoria de la conversación
(otra persona, otro agente o el mismo tras compactar el contexto). Cómo se usa:
[runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md).

- **Se actualiza al terminar cada paso**, no al final.
- **Se vacía al unir la rama** (deja solo «Ninguna tarea en curso»): lo que valga la pena guardar
  pasa antes a su ficha, a una ADR o al historial.

---

## Menú «Ir al álbum / Ver artista», ecualizador y vista de artista · rama `feature/artista-y-ecualizador`

- **Objetivo:** el propietario pidió (2026-11-18): en el clic derecho de una carátula o canción,
  ir a su álbum y ver su artista; un plugin de ecualizador y amplificador de volumen; y una vista
  de artista acorde con la app, con la foto del artista en el centro y sus 3 canciones más
  escuchadas flotando alrededor (como su captura de ejemplo, «Flowrbit»), y al bajar las canciones
  y los álbumes.
- **Áreas:** [ventana](areas/ventana.md), [catalogo](areas/catalogo.md),
  [reproduccion](areas/reproduccion.md), [detalle](areas/detalle.md).
- **Decisiones tomadas en la conversación:** el menú y el ecualizador, escritos en AGENTES §11 y
  en sus fichas. Para la vista de artista se propusieron tres alternativas (A «Órbita»: foto
  redonda con anillos y tres tarjetas fijas, sin animación, recomendada; B «Constelación»: las
  tarjetas flotan con vaivén; C «Escenario»: foto panorámica difuminada y tarjetas en fila).
  El propietario eligió la A, «Órbita» (escrita en AGENTES §11 y en la ficha de detalle).
- **Hecho (sin commit):** menú (`ytm::song_links`, `ytm::album_info`, `Library.openRelated`,
  `ContextMenu` se recoloca al cambiar de alto), ecualizador (`audio::effects_chain`,
  `Player.applyEffects`, Opciones › Plugins); build sin avisos, tests, capturas, fichas,
  historiales, trampas.
- **Hecho también (sin commit):** la vista «Órbita» (`qml/ArtistHero.qml`, `qml/DetailView.qml`),
  capturas, medida de memoria, ficha de detalle e historial.
- **Falta:** commits y unir a `master` con el visto bueno del propietario.
- **Cómo retomarla:** `git switch feature/artista-y-ecualizador`, `git status`.
- **Cuidado:** las pruebas con clics sobre la búsqueda dependen de que hayan llegado los
  resultados (clic derecho a los 14 s); los resultados cambian de orden entre pasadas.

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
