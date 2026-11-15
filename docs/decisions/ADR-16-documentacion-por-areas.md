---
adr: ADR-16
titulo: Documentación por áreas, una fuente por tema y comprobada con scripts/docs.py
estado: aceptada
fecha: 2026-11-15
areas: []
---

# ADR-16 · Documentación por áreas, una fuente por tema y comprobada con scripts/docs.py

- **Estado:** Aceptada.
- **Registrada:** 2026-11-15
- **Ámbito:** todo el proyecto

## Decisión

La documentación se organiza como en el proyecto Quests del propietario, adaptada a un código plano: normas en `docs/AGENTES.md`; una **ficha por área** en `docs/areas/` (frontmatter con sus archivos, opciones y ADR); ADR en `docs/decisions/`; procedimientos en `docs/runbooks/`; trampas en `docs/TRAMPAS.md`; historia en `docs/history/`; tablas generadas en `docs/INDEX.md`; y `python3 scripts/docs.py check` comprueba que todo cuadre con el código.

## Alternativas descartadas

- **Mover el código a una carpeta por funcionalidad** (como en Quests): `build.rs` y QML esperan rutas planas y el cambio no aporta nada al programa.
- **Un AGENTS.md largo con todo**: crecía con cada tarea, mezclaba normas, mecanismo e historia, y se leía entero para cualquier cambio.

## Motivo

Mantener el proyecto a largo plazo con agentes que pierden la memoria al compactar el contexto: lo que no está en el repositorio, escrito y comprobado, se pierde.

## Consecuencias

- Cada archivo de código pertenece a una ficha; cada opción, también.
- Cada tarea actualiza su ficha y su historial (AGENTES §9), y las tareas largas su nota en `docs/EN-CURSO.md`.
- `scripts/docs.py` es Python sin dependencias: no hay CI, así que se pasa a mano antes de terminar.
