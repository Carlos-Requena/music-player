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

En Lomos, bajo el título de la elegida, una barra (`1 —●— N`) recorre la estantería: arrastrarla
salta a cualquier elemento y, con el foco en ella, las flechas avanzan de uno en uno.

## Reglas y decisiones

- **Vistas por sección**, preferencia del propietario ([AGENTES §11](../AGENTES.md#11-cómo-trabajar-con-el-propietario));
  los valores por defecto están en `DEFAULT_VIEWS` de `src/settings.rs`.
- **Contrato de una vista:** propiedad `zonas`, `currentItem` y `signal activated(var item)`; si
  sigue el puntero, `signal hinted(var item, bool on)` (al entrar y salir de un elemento) para que
  la ventana lo precargue.
  Añadir una: `XxxView.qml` con ese contrato, registrarla en `build.rs`, en `SectionView.qml` y en
  `Catalog.views`.
- **Lomos con matrices propias** y funciones continuas del desplazamiento
  ([ADR-14](../decisions/ADR-14-lomos-con-matrices-propias.md)): una caja que cruza el centro no
  salta.
- **El Muro solo crea las filas cercanas** (una `ListView` con `cacheBuffer`) y solo descarga las
  carátulas de las filas visibles o cercanas. Una lista vertical pone cada fila en x = 0: el margen
  va en `leftMargin`.
- **Lomos crea un anillo fijo de cajas** (`ring`: las que caben a cada lado y tres más), no una
  por elemento; cada caja muestra el elemento más cercano a la posición que le toca en el anillo.
- **Lomos pide la carátula a 544 px solo en la elegida y sus vecinas** (`u < 2,5`); las demás, a
  226 px (se ven como franjas estrechas). Mientras llega la grande se ve la pequeña.
- **El reflejo de cada caja es un sombreador** (`shaders/reflejo.frag`) que lee la textura de la
  carátula pequeña (`Cover.picture`), no una capa con máscara y su propia copia de la imagen.

## Cómo funciona

### Lomos

- Cada caja es un cuerpo con frontal y dos lomos; cada cara, un `Item` plano con una `Matrix4x4`
  de `faceMatrix`: giro en Y, escala y una perspectiva suave con la cámara delante del eje de la
  caja. Solo se pinta el lomo que mira a la cámara.
- Posición continua (`pos`) que sigue a `index` con una animación; ángulo (`signedAngle`), escala
  y sitio (`slots`, interpolados) son funciones continuas de ella.
- `slots` encaja las cajas proyectando sus esquinas: lomos pegados, hueco solo junto a la elegida.
- Reflejo por caja: una cara más (`ShaderEffect` con `shaders/reflejo.frag`) que pinta la parte de
  abajo de la carátula volteada y fundida hacia abajo, con la misma curva que daba la máscara.
  Halo con `RectangularShadow`.
- Anillo: la caja `k` muestra el elemento `at = k + ring · round((pos − k) / ring)`; al avanzar
  uno solo cambia de elemento la caja que sale por un extremo, ya fuera de la vista.

### Precarga

`SectionView` resuelve de antemano las cuatro primeras canciones sueltas de la sección
([resolucion](resolucion.md)); Muro y Lomos avisan (`hinted`) del elemento bajo el ratón y la
ventana lo precarga si el puntero se queda 250 ms.

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|
| Álbumes en Lomos, `--index 5`, a los 20 s (memoria total de la app, Retina, `HOME` de pruebas) | 205–207 MB | 2026-11-17, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/SectionView.qml` | Elige la vista de una sección; teclas de categorías en Playlists |
| `qml/MuroView.qml` | Cuadrícula por zonas |
| `qml/LomosView.qml` | Estantería 3D |
| `qml/CubetaView.qml` | Discos de uno en uno |
| `qml/ViewSwitcher.qml` | Selector rápido de vista |
| `shaders/reflejo.frag` (+ `.qsb`) | Reflejo de las cajas de Lomos; se compila con `scripts/shaders.sh` |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Matriz de cada cara | [`faceMatrix`](../../qml/LomosView.qml) |
| Ángulo continuo | [`signedAngle`](../../qml/LomosView.qml) |
| Barra para recorrer la estantería | [`captions`](../../qml/LomosView.qml) (la barra va justo debajo) |
| Sitio de cada caja | [`slotAt`](../../qml/LomosView.qml) |
| Anillo de cajas | [`ring`](../../qml/LomosView.qml) |
| Reflejo | [`reflejo.frag`](../../shaders/reflejo.frag) |
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

- **Última verificación:** 2026-11-17, Lomos con anillo de cajas y reflejo por sombreador; Muro en una lista ([historial](../history/verificacion/vistas.md)).
- **Pruebas:** ninguna automática; capturas con `--section` e `--index`
  ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** Lomos en Linux con Vulkan; la barra de Lomos en Álbumes y Playlists con
  sesión (mismo componente, probada en Inicio).
- **Historial:** [docs/history/verificacion/vistas.md](../history/verificacion/vistas.md).
