---
adr: ADR-06
titulo: Canciones de un álbum o playlist desde su página VL, no desde la cola next
estado: aceptada
fecha: 2026-11-14
areas: [catalogo]
---

# ADR-06 · Canciones de un álbum o playlist desde su página VL, no desde la cola next

- **Estado:** Aceptada.
- **Registrada:** 2026-11-14 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [catalogo](../areas/catalogo.md)

## Decisión

Las canciones de un álbum o playlist salen de su página `VL<id>` y sus continuaciones (`ytm::playlist_tracks`), solo la lista principal y en su orden. La radio de una canción sí usa `next`, tomando solo el `primaryRenderer` de cada elemento.

## Alternativas descartadas

- **La cola `next`**: trae junto a cada canción su versión en vídeo (`counterpart`, con otra duración), se corta en ~50 y puede añadir canciones ajenas.

## Motivo

Las listas largas salían incompletas o mezcladas con vídeos.

## Consecuencias

- Una lista de 500 pistas tarda ~3 s (2026-11-14, M4 Pro): se muestra lo conocido al instante y las canciones después.
- `--probe album ID` prueba la página real.
