---
adr: ADR-12
titulo: Registrar las escuchas con los avisos del reproductor de YouTube Music, activado por defecto
estado: aceptada
fecha: 2026-11-14
areas: [historial]
---

# ADR-12 · Registrar las escuchas con los avisos del reproductor de YouTube Music, activado por defecto

- **Estado:** Aceptada.
- **Registrada:** 2026-11-14 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [historial](../areas/historial.md)

## Decisión

Cuando una pista ya suena, un hilo pide `/player` con la sesión y envía los mismos avisos que el reproductor de YouTube Music (`videostatsPlaybackUrl` al empezar y `videostatsWatchtimeUrl` con los tramos), todos con `c=WEB_REMIX`. Activado por defecto (opción `historial`).

## Alternativas descartadas

- **Confiar en la petición del audio**: no cuenta como reproducción.
- **`yt-dlp --mark-watched`**: lo apunta en el historial de YouTube, no en el de YouTube Music, y no envía el tiempo escuchado.

## Motivo

El propietario quiere que lo que escucha en la app cuente para sus recomendaciones.

## Consecuencias

- YouTube ve la escucha y aplica su límite de un dispositivo a la vez por cuenta.
- Nada espera a estos avisos: un fallo solo va a stderr (`historial:`).
