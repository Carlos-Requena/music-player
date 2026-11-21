---
adr: ADR-23
titulo: La interfaz se unifica con medidas de Theme, piezas comunes y la regla de dos
estado: aceptada
fecha: 2026-11-21
areas: [interfaz-comun, personalizacion, vistas, ventana, detalle, reproduccion]
---

# ADR-23 · La interfaz se unifica con medidas de Theme, piezas comunes y la regla de dos

- **Estado:** Aceptada.
- **Registrada:** 2026-11-21
- **Ámbito:** [interfaz-comun](../areas/interfaz-comun.md), [personalizacion](../areas/personalizacion.md),
  [vistas](../areas/vistas.md), [ventana](../areas/ventana.md), [detalle](../areas/detalle.md),
  [reproduccion](../areas/reproduccion.md)

## Decisión

El propietario notaba que la interfaz no estaba unificada. Una revisión pantalla a pantalla
encontró que cada una elegía sus propios tamaños de letra, márgenes, esquinas y forma de marcar
lo elegido. Se decide:

- **Medidas solo en `Theme`**: tipografía en ocho niveles (`fontDisplay` 40, `fontTitle` 28,
  `fontHeading` 20, `fontBody` 15, `fontBase` 14, `fontSmall` 13, `fontLabel` 12, `fontMini` 11),
  un margen de página (`margin` 32) y tres radios sacados del `radio` de la skin (`radiusS`,
  `radiusM`, `radiusL`). `docs.py check` rechaza tamaños de letra, radios y colores escritos a
  mano en `qml/` (salvo `Theme.qml`, `InspectView.qml` y líneas con `// fijo: <motivo>`).
- **Regla de dos para lo elegido**: lo que dice dónde estás (secciones, categorías, vista,
  Letra/Cola/Temporal, categorías de Opciones) se marca en blanco y es una píldora; un valor que
  eliges (segmentos de Opciones, la fila elegida) se marca en vidrio claro (`controlActive`). Una
  sola pieza, `Tabs`/`TabButton`, con los dos estilos.
- **Esquinas de las carátulas a elegir** (opción `esquinas`): «Redondeadas» (por defecto, el radio
  de la skin según su tamaño) o «Cuadradas». Los artistas van siempre en círculo; los objetos
  físicos (cajas de Lomos y Cubeta, Inspeccionar) siempre cuadrados; la carátula de la barra Islas
  es redonda, concéntrica con su píldora.
- **Sin cabecera de sección**: la navegación ya dice dónde estás. Lomos y Cubeta quitan su rótulo;
  la búsqueda sí lleva «Resultados de «…»», porque ninguna pestaña está elegida.
- **Qué hace un clic, a elegir** (opción `clic`): «Doble clic» (por defecto: un clic elige y el
  doble abre o hace sonar) o «Un clic». Filas de canción (detalle, cola, temporal) y carátulas del
  Muro. Con «Un clic», el nombre de la carátula bajo el ratón sale abajo, porque ya no hace falta
  elegirla para leerlo.
- **Una categoría de Explorar con álbumes o listas se recorre con el mismo Muro que Inicio**
  (elegir, aro, brillo, nombre abajo), no con una cuadrícula propia.
- **Hoja de Opciones compacta** (opción `compacto`, un segmento junto a la ×): sin descripciones
  en las filas; la de la fila bajo el ratón sale en un pie de la hoja, sin mover nada.
- **Piezas comunes nuevas** en [interfaz-comun](../areas/interfaz-comun.md): `Tabs`, `TabButton`,
  `FocusRing`, `TrackRow`, `SectionLabel`, `FocusedCaption` y `EmptyState`.
- **Volver y cerrar en el mismo sitio**: lo que ocupa el escenario (detalle, «Sonando»,
  Inspeccionar) se cierra con un botón arriba a la izquierda, en el margen de página; lo que flota
  encima (Opciones, el menú), con su × y Esc.

## Alternativas descartadas

- **Todo lo elegido en blanco** («Cápsula»): Opciones tiene más de veinte segmentos y se llenaba
  de blanco.
- **Todo lo elegido en vidrio claro** («Vidrio sereno»): cambiaba la navegación superior, salida
  de las muestras del propietario.
- **Esquinas fijas** (siempre cuadradas o siempre redondeadas): el propietario prefirió elegir.
- **Cabecera en todas las secciones**: repetía la navegación y quitaba alto a cada vista.
- **Compactar Opciones con más categorías, grupos plegables o búsqueda**: el propietario eligió el
  modo compacto.

## Motivo

Con solo cinco medidas en `Theme`, cada archivo escribía las suyas: había 16 tamaños de letra,
11 radios, 6 márgenes, 5 copias de las pestañas, 3 de la fila de canción y 4 formas de volver.
Poner nombre a las medidas y una pieza por papel hace que una pantalla nueva salga igual que las
demás sin pensarlo, y el candado de `docs.py` impide que se vuelva a desordenar.

## Consecuencias

- El `radio` de cada skin se nota en toda la app (carátulas, filas, menú, segmentos, paneles), no
  solo en el panel lateral.
- Las carátulas redondeadas se pintan con un sombreador (`shaders/caratula.frag`) que lee la
  textura de la imagen: el Inicio en Muro ocupa unos 10 MB más que con carátulas cuadradas (con una
  `Shape` por carátula eran unos 24 MB). Cifras en la ficha de [vistas](../areas/vistas.md#medidas);
  quien quiera ahorrarlos elige «Cuadradas».
- Un color nuevo de la skin, `error`, separa los errores del acento.
- Cambiar el aspecto de algo común (el foco, la fila, las pestañas) se hace en un solo archivo.
