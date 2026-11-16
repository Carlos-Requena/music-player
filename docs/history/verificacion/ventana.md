# Historial de verificación · Ventana y navegación

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/ventana.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-16 · «Sonando» en dos disposiciones (Grande y Clásica)

- **Cambio:** opción `sonando` (Opciones › Vistas). Grande, por defecto: carátula sola y más
  grande, letra y cola estrechas (380–460 px) a su altura, conjunto centrado con el mismo margen a
  los dos lados. Clásica: la de antes, con título y letra ancha. La carátula se redondea con
  `Cover.radius` en vez de una capa con máscara.
- **Verificado:** capturas en Retina (1440×900) de Grande con cola, con letra
  («Supercalifragilisticexpialidocious») y sin panel; de Clásica con letra; y de Opciones › Vistas.
  Memoria con «Sonando» abierta: 252–264 MB en la rama frente a 254–273 MB en `master` (ruido
  ±10 MB), con la app del propietario abierta a la vez.
- **No verificado:** Linux, ventanas estrechas (la letra tiene 380 px como mínimo), la transición
  al cambiar la opción con «Sonando» abierta.

## 2026-11-16 · El panel de letra y cola arranca oculto

- **Cambio:** `lyricsOn` empieza en `false` (lo pidió el propietario); el argumento de depuración
  `--no-panel` pasa a ser `--panel`, que lo abre al arrancar.
- **Verificado:** nada todavía (falta compilar y capturar con y sin `--panel`).
- **No verificado:** Linux.

## 2026-11-16 · Panel lateral y barra más baja

- **Cambio:** `barHeight` de 84 a 64; en el panel, carátula redondeada y pie fijo del retraso de la
  letra con separador.
- **Verificado:** captura con «Creep» cargada y su letra: pie «Letra en hora · − 0,0 s +» bajo la
  letra, carátula con esquinas redondas.
- **No verificado:** el panel a la izquierda; ventanas estrechas (la isla central ocupa el hueco).

## 2026-11-15 · Mascota en Opciones y aviso del «Me gusta»

`mascotLoader` sigue a `SettingsSheet.panel` con las opciones abiertas; `ContextMenu` avisa del
resultado de `Library.gustado`. Captura con `--settings --settings-cat apariencia`: la mascota en la
esquina inferior izquierda del panel y fuera de la barra. El aviso del «Me gusta» no se vio (no
llegó a sonar nada).

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
