# Historial de verificación · Piezas comunes de la interfaz

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/interfaz-comun.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-16 · `Cover` redondeada sin el borde repetido

- **Cambio:** `fillTransform` escala la textura de `ShapePath.fillItem` para cubrir la carátula y
  la centra; antes ocupaba su tamaño en píxeles físicos (272 px de 311 en el panel) y el último
  píxel se repetía por la derecha y por abajo.
- **Verificado:** capturas con ventana (Retina) del panel lateral y de «Sonando»: la carátula
  coincide con la de Lomos, esquinas incluidas.
- **No verificado:** pantalla con densidad 1 (CachyOS); la captura sin ventana no pinta la forma.

## 2026-11-16 · `Cover` con radio, `Slider` con paso, `Glass` sin máscara de sobra

- **Cambio:** `Cover.radius` (forma rellena con la imagen), `Slider.stepSize`, y `Glass` solo
  reserva la máscara del desenfoque si desenfoca.
- **Verificado:** capturas de la barra (carátula en círculo) y del panel.
- **No verificado:** la carátula redonda tras ocultar la ventana (mini reproductor) y volver.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
