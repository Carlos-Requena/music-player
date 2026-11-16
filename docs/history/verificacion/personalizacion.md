# Historial de verificación · Opciones, skins y aspecto

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/personalizacion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-16 · Modo ambiente «Fluido» (carátula fluida) y letra sin recuadro

- **Cambio:** valor `fluido` de `ambiente`: sombreador `shaders/fluido.frag` (desenfoque en anillo
  sobre la carátula a 32 px, deformación de dominio con ruido, límite de brillo y grano), fundido
  de un segundo entre carátulas y animación a 15 Hz con la opción `ambienteMovimiento`. En
  «Sonando», la letra y la cola sin recuadro sobre el fondo. ADR-17.
- **Verificado:** capturas de Inicio y de «Sonando» con letra (Queen, de LRCLIB) sobre el fondo; con
  una carátula clara el fondo no pasa de un gris medio y la letra se lee. CPU y memoria en release
  (ficha, «Medidas»), con la condición de que suene quitada a mano y repuesta después.
- **No verificado:** el movimiento a la vista (dos fotogramas de la misma carátula), el fundido,
  Linux y Windows, con música sonando de verdad (YouTube pedía sesión).

## 2026-11-16 · Movimiento del ambiente: deriva lenta

- **Cambio:** opción `ambienteMovimiento` (No, En Sonando, Siempre) y deriva de los focos en
  `Ambient.qml` a 10 Hz. Elegida por el propietario (B) entre respiración, deriva, oleada en los
  cambios y carátula fluida, tras una demostración animada y un prototipo medido.
- **Verificado:** CPU acumulada y memoria en release en cada modo (ficha, «Medidas»); a 60 fps el
  prototipo gastaba 6,2–7,6 s de CPU en 25 s, y 4,4 s sin desenfoque. Con la ventana minimizada o
  en el mini, la CPU vuelve a ~0. Capturas de «Sonando» a los 6 y 14 s con los focos en otro sitio;
  la fila nueva en Opciones › Apariencia.
- **No verificado:** con música sonando (YouTube pedía sesión: se midió quitando esa condición a
  mano); pausa y reanudación; Linux.

## 2026-11-16 · Opciones ya no deja pasar clics ni rueda a la sección de debajo

- **Cambio:** el `TapHandler` de fuera de la hoja con agarre exclusivo y todos los botones, y un
  `MouseArea` que se queda la rueda. Rama `fix/clics-y-barra`.
- **Verificado:** con la rueda simulada (`MUSICPLAYER_DEBUG_CLICK="300,600,wheel,5000,8"`) sobre
  Opciones › Apariencia: antes la sección de debajo bajaba; ahora no se mueve. Un clic en un hueco
  de la hoja no cambia el foco de debajo.
- **No verificado:** trackpad (desplazamiento por píxeles e inercia); Linux.

## 2026-11-16 · Modo ambiente «Plano»

- **Cambio:** valor `plano` de la opción `ambiente` (rama `feature/personalizacion-fondo-plano`),
  pedido por el propietario para pantallas antiguas donde los degradados salen con escalones: un
  solo color sólido (`Qt.tint` del fondo con el color de lo enfocado), sin focos ni suelo, y sin el
  halo de la carátula de «Sonando». Elegido entre tres propuestas (Plano, Dos bloques, Plano con
  grano).
- **Verificado:** capturas en Retina de Inicio y de «Sonando» con «Plano» (fondo liso, del color
  de lo enfocado) y de Opciones › Apariencia con los cinco valores.
- **No verificado:** en una pantalla antigua de verdad; Linux.

## 2026-11-16 · Apariencia rediseñada: miniaturas de skins y mascotas

- **Cambio:** tarjetas de skin con miniatura en sus colores, recuadros de mascota con su pose
  `reposo`, «Añadir…» y botones de carpeta y recargar (rama `feature/rediseno`). `skins_list`
  añade `colores`, `radio` e `imagen`; las carpetas del usuario se crean al pedirlas.
- **Verificado:** `cargo test` (pruebas nuevas de `preview_image` y `skins_list`); captura de
  `--settings-cat apariencia` con dos mascotas copiadas al `HOME` de pruebas: las cuatro skins con
  sus colores, el aro de la elegida entero y las dos mascotas con su imagen.
- **No verificado:** pulsar los botones de carpeta (abren el Finder); skins de carpeta con fondo;
  Linux.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
