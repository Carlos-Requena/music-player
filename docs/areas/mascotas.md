---
area: mascotas
titulo: Mascotas
resumen: Una imagen que cambia de pose según lo que pasa en el reproductor y da un saltito al cambiar; carpetas del usuario con PNG por pose.
archivos: [qml/Mascot.qml]
opciones: []
adr: []
---

# Mascotas

Opciones › Mascota. Van aparte de las skins, en `<config>/musicplayer/mascotas/<id>/` (un
`mascota.json` y los PNG de las poses). El formato, para quien usa la app:
[README](../../README.md#mascotas).

## Qué hace

La pose se elige por prioridad según el estado del reproductor (sonando, en pausa, cargando,
recién empezada, navegando…) y, si una pose no existe en la carpeta, se usa la que la sustituye
(tabla `fallback`). `Main.qml` le avisa al navegar (`browsed`).

## Reglas y decisiones

- **Sin código para crear una**: solo la carpeta. Un estado nuevo se añade en `mood` y en
  `fallback`.
- Las rutas las resuelve `Theme.mascotImage` a partir de `AppSettings.mascotaData` (que añade
  `carpeta`).

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/Mascot.qml` | Poses, prioridad y saltito |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Estado que decide la pose | [`mood`](../../qml/Mascot.qml) |
| Poses que se sustituyen | [`fallback`](../../qml/Mascot.qml) |
| Aviso al navegar | [`browsed`](../../qml/Mascot.qml) |
| Ruta de cada imagen | [`mascotImage`](../../qml/Theme.qml) |

## Dependencias

- **[reproduccion](reproduccion.md)** (`Player`): el estado que decide la pose.
- La mascota elegida llega por `Theme.mascotImage` ([personalizacion](personalizacion.md)).
- **La usan:** [ventana](ventana.md).

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** ninguna automática.
- **Sin verificar:** —
- **Historial:** [docs/history/verificacion/mascotas.md](../history/verificacion/mascotas.md).
