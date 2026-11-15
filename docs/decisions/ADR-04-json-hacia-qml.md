---
adr: ADR-04
titulo: Datos estructurados de Rust a QML como JSON en una propiedad QString
estado: aceptada
fecha: 2026-11-13
areas: [catalogo]
---

# ADR-04 · Datos estructurados de Rust a QML como JSON en una propiedad QString

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [catalogo](../areas/catalogo.md) (la forma vale para todo el proyecto)

## Decisión

Las listas (secciones, búsqueda, detalle, cola, letra) se publican como JSON en una propiedad `QString` y `qml/Catalog.qml` las convierte con `JSON.parse` una vez por cambio.

## Alternativas descartadas

- **`QAbstractListModel` por lista**: mucho código de puente por cada dato nuevo, para un volumen pequeño (zonas de 60 elementos como mucho).
- **`QVariantList`**: cxx-qt no lo hace cómodo y no ahorra nada medible.

## Motivo

Es simple, cada dato nuevo cuesta una propiedad, y basta para el volumen actual.

## Consecuencias

- Cada zona se limita a 60 elementos (`library::ZONE_LIMIT`).
- Si una lista creciera mucho (miles de filas que cambian a menudo), habría que medir y quizá pasar esa lista a un modelo.
