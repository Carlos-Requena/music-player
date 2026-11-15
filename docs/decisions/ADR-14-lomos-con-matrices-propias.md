---
adr: ADR-14
titulo: La estantería Lomos con matrices 3D propias y funciones continuas
estado: aceptada
fecha: 2026-11-13
areas: [vistas]
---

# ADR-14 · La estantería Lomos con matrices 3D propias y funciones continuas

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [vistas](../areas/vistas.md)

## Decisión

Cada cara de una caja es un `Item` plano con una `Matrix4x4` calculada (`faceMatrix`); ángulo, escala y sitio son funciones continuas de una posición `pos` que sigue a `index`.

## Alternativas descartadas

- **Qt Quick 3D**: un motor 3D entero (memoria y arranque) para cajas planas.
- **`Rotation` de Qt por cara**: el eje y el lomo visible cambiaban de lado de golpe al cruzar el centro.

## Motivo

Una caja que cruza el centro no salta; el reflejo y el halo cuestan ~7 MB.

## Consecuencias

- Un ángulo positivo en Y aleja el lado derecho ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- Las rotaciones grandes agrandan la pieza: la tapa de inspeccionar se pliega con `Scale`.
