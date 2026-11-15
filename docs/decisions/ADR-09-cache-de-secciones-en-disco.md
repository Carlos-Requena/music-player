---
adr: ADR-09
titulo: Cada sección se guarda en disco y se muestra al abrir mientras llega la nueva
estado: aceptada
fecha: 2026-11-13
areas: [catalogo]
---

# ADR-09 · Cada sección se guarda en disco y se muestra al abrir mientras llega la nueva

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [catalogo](../areas/catalogo.md)

## Decisión

Cada sección se guarda en `<caché>/musicplayer/<anonimo|cuenta>-<sección>.json` y se muestra al arrancar mientras se pide la nueva (~0,5 s). Las de la cuenta se borran al cerrar sesión.

## Alternativas descartadas

- **Esperar a la red**: la ventana salía vacía medio segundo o más.

## Motivo

Respuesta instantánea al abrir: a los 300 ms ya se ven contenido y carátulas (2026-11-13, M4 Pro).

## Consecuencias

- Lo que se ve al abrir puede ser de la vez anterior durante medio segundo.
- Cerrar sesión debe borrar las copias de la cuenta (`library::forget_account`).
