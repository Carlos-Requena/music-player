---
adr: ADR-13
titulo: Letra de LRCLIB y un solo gestor de clics para toda la vista, sin hover
estado: ampliada por ADR-18
fecha: 2026-11-14
areas: [letra]
---

# ADR-13 · Letra de LRCLIB y un solo gestor de clics para toda la vista, sin hover

- **Estado:** Ampliada por [ADR-18](ADR-18-letra-de-varias-fuentes.md) (varias fuentes de letra).
- **Registrada:** 2026-11-14 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [letra](../areas/letra.md)

## Decisión

La letra sale de LRCLIB (abierta, sin sesión). La vista tiene un único gestor de clics que calcula la línea con `childAt`, sin «hover» ni cursor por línea, y tres calidades (`letraCalidad`) que cambian los fotogramas por segundo.

## Alternativas descartadas

- **Un gestor por línea** (o uno solo con «hover»): ~25 % de CPU incluso sin animaciones.
- **`Text.CurveRendering`**: ~95 MB más.
- **Brillo con `layer.effect`**: el texto se veía borroso.

## Motivo

Con «Equilibrado» la letra cuesta 4,8–5,0 s de CPU en 25 s, frente a 3,5 s de la pestaña Cola (2026-11-14, M4 Pro, release).

## Consecuencias

- Un efecto nuevo en la letra se mide con CPU acumulada en los tres modos.
- Cualquier gestor nuevo en la letra va en el único que hay.
