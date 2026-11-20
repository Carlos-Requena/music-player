---
adr: ADR-21
titulo: La carátula animada se toma de la página pública de Apple Music y se reproduce con Qt Multimedia desde la caché
estado: aceptada
fecha: 2026-11-20
areas: [ventana]
---

# ADR-21 · La carátula animada se toma de la página pública de Apple Music y se reproduce con Qt Multimedia desde la caché

- **Estado:** Aceptada.
- **Registrada:** 2026-11-20
- **Ámbito:** [ventana](../areas/ventana.md)

## Decisión

La carátula animada de «Sonando» (opción `caratulaAnimada`, desactivada por defecto) sale de
Apple Music sin cuenta: la API pública de iTunes para dar con el álbum y la página pública del
álbum para la lista HLS del vídeo (`motionDetailSquare`). `ffmpeg` la guarda una vez como MP4 en
`<caché>/musicplayer/animadas/` y QML la reproduce con **Qt Multimedia** (`MotionCover.qml`), en
un `Loader` que solo existe con «Sonando» a la vista. Qt Multimedia y `ffmpeg` pasan a ser
dependencias de la app.

## Alternativas descartadas

- **Reproducir la lista HLS en directo con Qt Multimedia** (la A que se propuso): descargaba el
  vídeo cada vez que se abría «Sonando».
- **WebP animado con `AnimatedImage`** (la C): sin módulos nuevos, pero se decodifica por CPU,
  fotograma a fotograma, y se ve peor que un vídeo.
- **La API oficial de Apple Music** (MusicKit, `editorialVideo`): necesita una cuenta de
  desarrollador de pago y un token firmado.
- **mpv para el vídeo:** va en un proceso aparte ([ADR-02](ADR-02-mpv-en-proceso-aparte.md)) y
  no puede pintar dentro de la ventana de Qt.

## Motivo

El propietario lo pidió («en Apple algunos fondos están animados… que se muestren en vez de la
carátula en Sonando») y eligió la opción B: descargar una vez y reproducir desde la caché.

## Consecuencias

- La página de Apple no es una API: si cambia, no se encuentra nada y queda la carátula fija (sin
  errores en la interfaz; el detalle va a stderr con el prefijo `animada:`).
- Con el vídeo a la vista, ~17–20 % de CPU y hasta ~15 MB más (ficha de
  [ventana](../areas/ventana.md#medidas)); por eso va desactivada por defecto y quieta en pausa.
- `crear-app-macos.sh` y `instalar-linux.sh` instalan `qtmultimedia` / `qt6-multimedia`.
