---
area: vistas
titulo: Vistas de las secciones
resumen: Muro, Lomos y Cubeta, elegibles por sección, y el selector que las alterna al vuelo.
archivos: [qml/SectionView.qml, qml/MuroView.qml, qml/CategoriasView.qml, qml/LomosView.qml, qml/CubetaView.qml, qml/ViewSwitcher.qml]
opciones: [caratulas, brillo]
adr: [ADR-14, ADR-22, ADR-23]
---

# Vistas de las secciones

Cómo se recorre cada sección. Opciones › Vistas, el selector de arriba a la derecha o la tecla `V`.

## Qué hace

| Vista | Qué es | Por defecto en |
|---|---|---|
| **Muro** | Cuadrícula de carátulas por zonas, la enfocada ampliada; en Explorar, una tarjeta por categoría | Inicio, Explorar, Me gusta, Historial, Búsqueda |
| **Lomos** | Estantería 3D: la elegida de frente y más grande, sus vecinas giradas hacia ella, el resto como lomos; reflejo en el suelo y halo de color | Playlists, Álbumes |
| **Cubeta** | Discos de uno en uno, como en una caja de tienda | — |

Tamaño de las carátulas del Muro: opción `caratulas`. Sus esquinas, la opción `esquinas`
([personalizacion](personalizacion.md)); los artistas (en la búsqueda), siempre en círculo.

**Sin cabecera de sección** ([ADR-23](../decisions/ADR-23-sistema-de-diseno-medidas-y-piezas-comunes.md)):
la píldora blanca de la navegación ya dice dónde estás. Muro, Lomos y Cubeta muestran el nombre y
el subtítulo de lo enfocado con la misma pieza (`FocusedCaption`, 40 px) y las etiquetas de zona
con `SectionLabel`. Todas usan el margen común (`Theme.margin`).

**Brillo al pasar el ratón** (opción `brillo`, Opciones › Vistas; vacío = activado, `no`): en el
Muro de cualquier sección, la carátula bajo el ratón crece un 4,5 %, pierde el velo oscuro y brilla
con el color de su carátula (halo, borde y reflejo); en Explorar, igual en las tarjetas.
Desactivado, el ratón no cambia nada. Lo elegido con el teclado lleva siempre el aro blanco
(`Theme.cursorWidth`), en el Muro y en Explorar: el brillo es del ratón y el aro, del teclado.
Sin etiqueta encima de la primera fila (una categoría de Explorar abierta), el Muro reserva arriba
el hueco que crece la elegida, para que su aro no se corte (`topMargin` de `MuroView`).

**La rueda del ratón** baja 120 px por muesca en el Muro y en Explorar (`WheelScroll`,
[interfaz-comun](interfaz-comun.md)); el trackpad sigue igual.

**Explorar en Muro va por categorías** (`CategoriasView`,
[ADR-22](../decisions/ADR-22-explorar-por-categorias-con-recomendados.md)): una tarjeta por zona
(«Recomendados» la primera), con su primera carátula a sangre y el nombre en mayúsculas sobre un
degradado del fondo de la skin, y debajo cuántos elementos tiene. Más separadas que el Muro (40 px
entre tarjetas; 5, 4 o 3 columnas según `caratulas`). Al pasar el ratón la tarjeta crece un 4,5 % y
brilla: halo, borde y reflejo del color de su carátula; la del teclado crece y lleva el aro. Un
clic (o Intro) la abre como detalle ([detalle](detalle.md)).

En Lomos, bajo el título de la elegida, una barra (`posición —●— total`) recorre la estantería:
arrastrarla salta a cualquier elemento y, con el foco en ella, las flechas avanzan de uno en uno.
Cubeta muestra la posición («3 de 40») en el frontal de la caja, que toma el color de fondo de la
skin.

## Reglas y decisiones

- **Vistas por sección**, preferencia del propietario ([AGENTES §11](../AGENTES.md#11-cómo-trabajar-con-el-propietario));
  los valores por defecto están en `DEFAULT_VIEWS` de `src/settings.rs`.
- **Contrato de una vista:** propiedad `zonas`, `currentItem` y `signal activated(var item)`; si
  sigue el puntero, `signal hinted(var item, bool on)` (al entrar y salir de un elemento) para que
  la ventana lo precargue.
  Añadir una: `XxxView.qml` con ese contrato, registrarla en `build.rs`, en `SectionView.qml` y en
  `Catalog.views`.
- **Tarjetas de categoría con «hover» por tarjeta**: son pocas y no se mueven, así que no pagan el
  repaso por fotograma de [TRAMPAS](../TRAMPAS.md#qt-quick-y-qml). Su color sale de una
  `TintProbe` por tarjeta, centrada bajo la carátula (en una esquina asomaba por el redondeo).
  Solo brilla la del ratón; la del teclado lleva el aro.
- **En el Muro, el brillo solo existe en la carátula bajo el ratón**: un `Loader` crea su halo y su
  `TintProbe` al entrar y los quita al salir; con una sonda por carátula serían decenas de lienzos.
  No añade gestores: usa el `HoverHandler` que ya tenía cada carátula. El color, `Theme.glow`.
- **Lomos con matrices propias** y funciones continuas del desplazamiento
  ([ADR-14](../decisions/ADR-14-lomos-con-matrices-propias.md)): una caja que cruza el centro no
  salta.
- **Clic en el Muro** (opción `clic`, [reproduccion](reproduccion.md)): con «Doble clic» (por
  defecto) un clic elige y el doble abre o hace sonar; con «Un clic», un clic ya lo hace, y el nombre
  de abajo (`FocusedCaption`) sigue a la carátula bajo el ratón (`hoverItem`) en vez de a la elegida:
  sin elegir, no habría forma de leerlo. Lo pidió el propietario.
- **La etiqueta de cada zona del Muro deja sitio** a la carátula elegida, que crece ×1,12 con su
  aro: el hueco bajo ella es `tile · 0,06 + cursorWidth + 8`.
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
| Explorar por categorías (4 tarjetas, fuente YouTube), a los 30 s, `phys_footprint` | 200 MB (Inicio en Muro, misma prueba: 400 MB) | 2026-11-21, M4 Pro, release |
| Inicio en Muro sin sesión, a los 30 s, `phys_footprint`: esquinas redondeadas (sombreador) / cuadradas, tres medidas de cada | 216–219 MB / 205–208 MB | 2026-11-21, M4 Pro, release |

## Archivos

| Archivo | Contenido |
|---|---|
| `qml/SectionView.qml` | Elige la vista de una sección; teclas de categorías en Playlists |
| `qml/MuroView.qml` | Cuadrícula por zonas |
| `qml/CategoriasView.qml` | Explorar en Muro: una tarjeta por categoría, con brillo al pasar el ratón |
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
| Brillo de la carátula bajo el ratón en el Muro | [`lit`](../../qml/MuroView.qml), [`glowBack`](../../qml/MuroView.qml) |
| Opción y color del brillo | [`hoverGlow`](../../qml/Theme.qml), [`glow`](../../qml/Theme.qml) |
| Tarjetas de Explorar y cuál brilla | [`cards`](../../qml/CategoriasView.qml), [`lit`](../../qml/CategoriasView.qml), [`glow`](../../qml/CategoriasView.qml) |
| Qué vista monta cada sección | [`loader`](../../qml/SectionView.qml) |
| Paso en la Cubeta | [`step`](../../qml/CubetaView.qml) |
| Saltar a un elemento (`--index`) | [`jump`](../../qml/SectionView.qml) |

## Dependencias

- **[catalogo](catalogo.md)** (`Catalog.zonas`, `Catalog.views`): las zonas de cada sección.
- **[reproduccion](reproduccion.md)** (`Player.prefetchItem`, `Player.prefetchTracks`): precarga.
- **[personalizacion](personalizacion.md)** (`AppSettings`, `TintProbe`): vista elegida, opción
  `caratulas` y color del halo.
- El menú de clic derecho de las tarjetas lo abre `Main.openMenu` ([ventana](ventana.md)).
- **[interfaz-comun](interfaz-comun.md)** (`WheelScroll`, `Cover`, `SectionLabel`): la rueda del Muro y de Explorar y las carátulas.
- **La usan:** [ventana](ventana.md) (`Main.qml` monta `SectionView`).

## Estado actual

- **Última verificación:** 2026-11-21, fila de arriba sin recortar en una categoría de Explorar y rueda ([historial](../history/verificacion/vistas.md)).
- **Pruebas:** ninguna automática; capturas con `--section` e `--index`
  ([verificar-interfaz](../runbooks/verificar-interfaz.md)).
- **Sin verificar:** el brillo del foco del teclado en las capturas (sale solo si la ventana de
  prueba queda activa); Explorar por categorías con el ratón de verdad (el brillo se probó con un
  movimiento simulado) y con 5 tarjetas (ListenBrainz con usuario); en Linux; Lomos en Linux con Vulkan; la barra de Lomos en Álbumes y Playlists con
  sesión (mismo componente, probada en Inicio).
- **Historial:** [docs/history/verificacion/vistas.md](../history/verificacion/vistas.md).
