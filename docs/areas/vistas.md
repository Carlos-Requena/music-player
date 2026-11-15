---
area: vistas
titulo: Vistas de las secciones
resumen: Muro, Lomos y Cubeta, elegibles por sección, y el selector que las alterna al vuelo.
archivos: [qml/SectionView.qml, qml/MuroView.qml, qml/LomosView.qml, qml/CubetaView.qml, qml/ViewSwitcher.qml]
opciones: [caratulas]
adr: [ADR-14]
---

# Vistas de las secciones

Cómo se recorre cada sección. Opciones › Vistas, el selector de arriba a la derecha o la tecla `V`.

## Qué hace

| Vista | Qué es | Por defecto en |
|---|---|---|
| **Muro** | Cuadrícula de carátulas por zonas, la enfocada ampliada | Inicio, Explorar, Me gusta, Búsqueda |
| **Lomos** | Estantería 3D: la elegida de frente y más grande, sus vecinas giradas hacia ella, el resto como lomos; reflejo en el suelo y halo de color | Playlists, Álbumes |
| **Cubeta** | Discos de uno en uno, como en una caja de tienda | — |

Tamaño de las carátulas del Muro: opción `caratulas`.

## Reglas y decisiones

- **Vistas por sección**, preferencia del propietario ([AGENTES §11](../AGENTES.md#11-cómo-trabajar-con-el-propietario));
  los valores por defecto están en `DEFAULT_VIEWS` de `src/settings.rs`.
- **Contrato de una vista:** propiedad `zonas`, `currentItem` y `signal activated(var item)`.
  Añadir una: `XxxView.qml` con ese contrato, registrarla en `build.rs`, en `SectionView.qml` y en
  `Catalog.views`.
- **Lomos con matrices propias** y funciones continuas del desplazamiento
  ([ADR-14](../decisions/ADR-14-lomos-con-matrices-propias.md)): una caja que cruza el centro no
  salta.
- **El Muro solo descarga las carátulas** de las filas visibles o cercanas.

## Cómo funciona

### Lomos

- Cada caja es un cuerpo con frontal y dos lomos; cada cara, un `Item` plano con una `Matrix4x4`
  de `faceMatrix`: giro en Y, escala y una perspectiva suave con la cámara delante del eje de la
  caja. Solo se pinta el lomo que mira a la cámara.
- Posición continua (`pos`) que sigue a `index` con una animación; ángulo (`signedAngle`), escala
  y sitio (`slots`, interpolados) son funciones continuas de ella.
- `slots` encaja las cajas proyectando sus esquinas: lomos pegados, hueco solo junto a la elegida.
- Reflejo por caja: una cara más con la carátula volteada (misma textura en caché) y un degradado
  como máscara (`MultiEffect`; ver [TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)). Halo con
  `RectangularShadow`.

### Precarga

`SectionView` resuelve de antemano las cuatro primeras canciones sueltas de la sección
([resolucion](resolucion.md)); Muro y Lomos piden la precarga del elemento bajo el ratón.

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Álbumes en Lomos (memoria total de la app, Retina) | ~290 MB | 2026-11-13, M4 Pro, release |
| Reflejos de las cajas visibles | ~7 MB | 2026-11-13, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/SectionView.qml` | Elige la vista de una sección; teclas de categorías en Playlists |
| `qml/MuroView.qml` | Cuadrícula por zonas |
| `qml/LomosView.qml` | Estantería 3D |
| `qml/CubetaView.qml` | Discos de uno en uno |
| `qml/ViewSwitcher.qml` | Selector rápido de vista |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Matriz de cada cara | [`faceMatrix`](../../qml/LomosView.qml) |
| Ángulo continuo | [`signedAngle`](../../qml/LomosView.qml) |
| Sitio de cada caja | [`slotAt`](../../qml/LomosView.qml) |
| Filas del Muro | [`moveRow`](../../qml/MuroView.qml) |
| Paso en la Cubeta | [`step`](../../qml/CubetaView.qml) |
| Saltar a un elemento (`--index`) | [`jump`](../../qml/SectionView.qml) |

## Dependencias

- **[catalogo](catalogo.md)** (`Catalog.zonas`, `Catalog.views`): las zonas de cada sección.
- **[reproduccion](reproduccion.md)** (`Player.prefetchItem`, `Player.prefetchTracks`): precarga.
- **[personalizacion](personalizacion.md)** (`AppSettings`, `TintProbe`): vista elegida, opción
  `caratulas` y color del halo.
- El menú de clic derecho de las tarjetas lo abre `Main.openMenu` ([ventana](ventana.md)).
- **La usan:** [ventana](ventana.md) (`Main.qml` monta `SectionView`).

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** ninguna automática; capturas con `--section` e `--index`
  ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** Lomos en Linux con Vulkan.
- **Historial:** [docs/history/verificacion/vistas.md](../history/verificacion/vistas.md).
