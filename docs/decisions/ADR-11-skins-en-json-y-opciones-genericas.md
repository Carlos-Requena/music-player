---
adr: ADR-11
titulo: Skins en JSON y opciones de disposición como un mapa clave → valor
estado: aceptada
fecha: 2026-11-13
areas: [personalizacion]
---

# ADR-11 · Skins en JSON y opciones de disposición como un mapa clave → valor

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [personalizacion](../areas/personalizacion.md)

## Decisión

Las skins son JSON (las incluidas dentro del binario con `include_str!`, las del usuario en `<config>/musicplayer/skins/`, también carpetas con imagen de fondo). Las opciones de disposición son un mapa genérico clave → valor en `settings.json` (`AppSettings.opcion` / `setOpcion`); vacío es el valor por defecto.

## Alternativas descartadas

- **Una propiedad de puente por opción**: cada opción nueva tocaría Rust, el puente y QML.
- **Skins con QML propio**: queda para más adelante ([ROADMAP](../ROADMAP.md)); los colores cubren casi todo.

## Motivo

Personalización total sin tocar Rust: una opción nueva es una fila en `optionRows`.

## Consecuencias

- Las claves no tienen tipo: cada una se documenta en el `opciones:` de la ficha de su área (lo comprueba `scripts/docs.py`).
- Un color nuevo va en las cuatro skins y en `Theme.pick`.
