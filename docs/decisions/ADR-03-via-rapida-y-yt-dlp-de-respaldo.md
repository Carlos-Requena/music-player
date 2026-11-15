---
adr: ADR-03
titulo: Vía rápida por la API /player con el cliente de visionOS, y yt-dlp de respaldo
estado: aceptada
fecha: 2026-11-13
areas: [resolucion]
---

# ADR-03 · Vía rápida por la API /player con el cliente de visionOS, y yt-dlp de respaldo

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [resolucion](../areas/resolucion.md)

## Decisión

La URL de audio se pide primero a `/youtubei/v1/player` con el cliente de visionOS y un «visitor data» (`src/stream.rs`), que devuelve URLs directas sin descifrado JavaScript ni tokens. Si falla, yt-dlp (el residente y, si no, un proceso). Las pistas que YouTube reserva a cuentas van directas a yt-dlp con `web_music` y las cookies.

## Alternativas descartadas

- **Solo yt-dlp**: 3,5–4,2 s por pista (2026-11-13, M4 Pro); demasiado para «clic y que suene».
- **El gancho de yt-dlp de mpv**: 8,2–9,5 s; queda como plan B.
- **Otros clientes de InnerTube** (web, Android): piden descifrado o tokens PO.

## Motivo

La vía rápida sirve unas 9 de cada 10 pistas en 0,2–0,4 s.

## Consecuencias

- Sin «visitor data» YouTube responde `LOGIN_REQUIRED`: se pide una vez y se reutiliza.
- Cuando YouTube cambie, lo primero que falla es esta vía: yt-dlp debe seguir funcionando solo.
- `--probe fast` dice por qué falla cada pista.
