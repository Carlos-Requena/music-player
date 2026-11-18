# Historial de verificación · Detalle e inspeccionar

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/detalle.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-18 · Vista de artista «Órbita» (rama `feature/artista-y-ecualizador`)

- **Cambio:** `ArtistHero.qml` (foto, anillo de rayas del color de la foto y tres canciones
  flotando); con un artista, la lista ocupa todo el ancho, lleva la cabecera y sus filas van
  centradas (`inset`); fuera la máscara circular de la carátula (ya no hace falta); argumento
  `--detail-at` de depuración.
- **Verificado:** capturas de Luis Fonsi y Daddy Yankee (el anillo cambia de color con la foto),
  bajando 700 px (canciones) y hasta el final (discografía); un álbum sigue igual; pulsar la
  primera tarjeta deja `sonando true` con las 50 canciones en la cola. Memoria igual con y sin la
  cabecera (290 / 287–290 MB).
- **No verificado:** ventana estrecha; Linux; rueda o trackpad reales.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
