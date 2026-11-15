---
adr: ADR-02
titulo: mpv en un proceso aparte, controlado por su socket IPC JSON
estado: aceptada
fecha: 2026-11-13
areas: [reproduccion]
---

# ADR-02 · mpv en un proceso aparte, controlado por su socket IPC JSON

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [reproduccion](../areas/reproduccion.md)

## Decisión

El audio lo reproduce un proceso `mpv --idle` sin vídeo, controlado por su socket IPC JSON (`src/audio.rs`). Sin sus scripts de interfaz y con caché de 16 MB.

## Alternativas descartadas

- **libmpv embebido**: una dependencia nativa más en dos sistemas y un fallo de mpv tumbaría la app; queda pendiente medir si ahorra memoria ([ROADMAP](../ROADMAP.md)).
- **QtMultimedia**: no lee bien las URLs de googlevideo ni Opus en todos los sistemas, y no tiene el gancho de yt-dlp como plan B.

## Motivo

mpv lee todo lo que sirve YouTube (con ffmpeg), tiene un gancho de yt-dlp que sirve de plan B y se puede reiniciar sin cerrar la app (al cambiar de sesión).

## Consecuencias

- mpv solo avisa de la pausa cuando cambia: el estado se reaplica al empezar cada pista.
- En macOS hay que buscar mpv en `/opt/homebrew/bin` y `/usr/local/bin` (`audio::search_path`).
- Las URLs de yt-dlp van como `lavf://URL` y las de la vía rápida tal cual.
