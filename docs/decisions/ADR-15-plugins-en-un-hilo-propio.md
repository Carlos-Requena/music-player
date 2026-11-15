---
adr: ADR-15
titulo: Los plugins reciben los eventos del reproductor en un hilo propio
estado: aceptada
fecha: 2026-11-13
areas: [plugins]
---

# ADR-15 · Los plugins reciben los eventos del reproductor en un hilo propio

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [plugins](../areas/plugins.md)

## Decisión

`Player` avisa con `plugins::emit(Event)` y un hilo (`plugins::worker`) reparte a Discord y Last.fm, que hablan con la red. Los controles del sistema no pasan por ahí: viven en `player.rs` porque en macOS van en el hilo principal.

## Alternativas descartadas

- **Llamar a cada plugin desde `Player`**: la red frenaría el hilo de Qt.

## Motivo

Los plugins nunca deben retrasar el arranque de una pista ni la interfaz.

## Consecuencias

- Un plugin nuevo se suma a `worker` y a la pestaña Plugins de Opciones.
- Su configuración va en `plugins.json` (permisos 600).
