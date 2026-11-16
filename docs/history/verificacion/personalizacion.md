# Historial de verificación · Opciones, skins y aspecto

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/personalizacion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

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
