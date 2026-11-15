---
adr: ADR-08
titulo: yt-dlp residente para no pagar el arranque de Python en cada pista
estado: aceptada
fecha: 2026-11-13
areas: [resolucion]
---

# ADR-08 · yt-dlp residente para no pagar el arranque de Python en cada pista

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [resolucion](../areas/resolucion.md)

## Decisión

Un intérprete de yt-dlp que se queda cargado (`src/ytdlp_daemon.py`, lanzado por `src/daemon.rs` con el intérprete del `yt-dlp` instalado) resuelve las pistas que no da la vía rápida. Se cierra solo tras un minuto sin uso y se puede desactivar (opción `ytdlp`).

## Alternativas descartadas

- **Un proceso por petición siempre**: 3,5–4,2 s frente a 2,2–2,5 s (2026-11-13, M4 Pro).
- **Residente sin límite de tiempo**: ~120 MB todo el rato para algo que se usa poco.

## Motivo

Las pistas que exigen yt-dlp (con sesión, Premium) suenan ~1 s antes.

## Consecuencias

- Si yt-dlp es un binario autónomo (no un script de Python), se usa un proceso por petición.
- Mientras vive ocupa ~120 MB: la opción lo dice.
