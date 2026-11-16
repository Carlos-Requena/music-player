---
area: mascotas
titulo: Mascotas
resumen: Una imagen que cambia de pose según lo que pasa en el reproductor, reacciona unos segundos a lo que haces (pincharla, pasar canción, guardar en una playlist) y puede dar «Me gusta»; carpetas del usuario con PNG por pose.
archivos: [qml/Mascot.qml]
opciones: []
adr: []
---

# Mascotas

Opciones › Mascota. Van aparte de las skins, en `<config>/musicplayer/mascotas/<id>/` (un
`mascota.json` y los PNG de las poses). El formato, para quien usa la app:
[README](../../README.md#mascotas).

## Qué hace

- **Pose de fondo** por prioridad según el estado del reproductor (error, cargando, recién
  empezada, sonando, navegando, en pausa, reposo). `Main.qml` le avisa al navegar (`browsed`).
- **Reacciones breves**, por encima de todo lo demás durante unos segundos (`react`):
  - `clic` al pincharla. Si `mascota.json` lleva `"pincharDaMeGusta": true` y suena una canción,
    además le da «Me gusta» (`Library.like`) y, tras `clic`, pasa a `megusta`; si falla (sin
    sesión, sin red), a `fallo`. El resultado se avisa con el aviso breve del menú contextual.
  - `enfado` al pincharla 5 veces en 4 segundos.
  - `saltada` cuando el usuario pasa a la siguiente canción (`Player.saltada`: botón, mini
    reproductor o teclas multimedia; no cuando una pista termina sola).
  - `playlist` al guardar algo en una playlist (`Library.guardado` sin error).
- **En Opciones** se muda a la esquina inferior izquierda del panel, bajo las categorías, y vuelve a
  la barra al cerrarlas (`Main.qml`, `mascotLoader`). Es la misma instancia: no pierde lo que
  estaba haciendo.
- Si una pose no existe en la carpeta se usa la que la sustituye (tabla `fallback`).
- **En Opciones › Apariencia** cada mascota sale en su recuadro con la pose `reposo`
  ([personalizacion](personalizacion.md)).

## Reglas y decisiones

- **Sin código para crear una**: solo la carpeta. Qué imagen sale en cada momento, su alto, cuánto
  dura cada reacción (`segundos`) y si pincharla da «Me gusta» se escriben en `mascota.json`. Un
  estado nuevo se añade en `mood` (o como reacción con `react`) y en `fallback`, y en la tabla del
  README.
- **Pincharla da «Me gusta» solo si la mascota lo pide** (`pincharDaMeGusta`) y solo con música
  sonando; sin música, pincharla solo cambia la pose. Pedido por el propietario para Ralsei.
- **Una petición por canción**: pincharla otra vez con la misma canción no repite el «Me gusta»
  (`likedId`); tras un fallo, o si se quitó desde la barra (`gustado` con `gusta` falso), se puede
  volver a dar. La mascota nunca lo quita.
- **Se queda el clic** (`gesturePolicy: TapHandler.ReleaseWithinBounds`): como pincharla puede dar
  «Me gusta», el clic no debe llegar también a la tarjeta que haya debajo.
- Las rutas las resuelve `Theme.mascotImage` a partir de `AppSettings.mascotaData` (que añade
  `carpeta`).

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/Mascot.qml` | Poses, prioridad, reacciones breves, «Me gusta» al pincharla y saltito |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Estado que decide la pose | [`mood`](../../qml/Mascot.qml) |
| Poses que se sustituyen | [`fallback`](../../qml/Mascot.qml) |
| Reacción breve y su duración | [`react`](../../qml/Mascot.qml), [`seconds`](../../qml/Mascot.qml) |
| Pincharla («Me gusta», enfado) | [`poke`](../../qml/Mascot.qml) |
| Aviso al navegar | [`browsed`](../../qml/Mascot.qml) |
| Ruta de cada imagen | [`mascotImage`](../../qml/Theme.qml) |
| Sitio en la barra y en Opciones | [`mascotLoader`](../../qml/Main.qml) |

## Dependencias

- **[reproduccion](reproduccion.md)** (`Player`): el estado que decide la pose y `saltada`.
- **[catalogo](catalogo.md)** (`Library.like`, `gustado`, `guardado`; `Catalog.currentVideoId`):
  dar «Me gusta» y enterarse de lo guardado en playlists.
- La mascota elegida llega por `Theme.mascotImage` ([personalizacion](personalizacion.md)).
- **La usan:** [ventana](ventana.md) (la coloca en la barra o en Opciones y muestra el aviso del
  «Me gusta»).

## Estado actual

- **Última verificación:** 2026-11-15, capturas con Ralsei: pincharla (vergüenza), cinco veces
  (enojo), «Siguiente» (desilusión) y en Opciones ([historial](../history/verificacion/mascotas.md)).
- **Pruebas:** ninguna automática.
- **Sin verificar:** el «Me gusta» de verdad (con sesión y música sonando), la reacción a
  «Guardar en una playlist», Linux.
- **Historial:** [docs/history/verificacion/mascotas.md](../history/verificacion/mascotas.md).
