---
adr: ADR-10
titulo: El mini reproductor oculta la ventana grande y libera su memoria gráfica
estado: aceptada
fecha: 2026-11-13
areas: [ventana]
---

# ADR-10 · El mini reproductor oculta la ventana grande y libera su memoria gráfica

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [ventana](../areas/ventana.md)

## Decisión

Al abrir el mini reproductor la ventana grande se **oculta** (no se minimiza) y `src/window.cpp` libera su grafo de escena y su memoria gráfica. Al volver, `Theme.renderEpoch` sube para recrear lo que no se redibuja solo.

## Alternativas descartadas

- **Minimizar**: en macOS Qt conserva los búferes de las ventanas minimizadas; no libera nada.
- **Mini dentro de la misma ventana**: no libera la memoria de la grande.

## Motivo

213 → 148 MB al pasar al mini (2026-11-13, M4 Pro, release).

## Consecuencias

- Las `Shape` con CurveRenderer no se redibujan tras liberar los gráficos: `Icon.qml` se recrea con un `Loader`.
- Una pieza nueva con ese problema necesita lo mismo.
