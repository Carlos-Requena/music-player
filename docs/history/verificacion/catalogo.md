# Historial de verificación · Catálogo de YouTube Music

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/catalogo.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-16 · `ytm::remove_like`

- **Cambio:** `Library.like` lleva `gusta` y llama a `ytm::like` o `ytm::remove_like`
  (`like/removelike`); `gustado` añade `videoId` y `gusta`.
- **Verificado:** el camino sin sesión (mensaje de error); compila sin avisos.
- **No verificado:** `like/removelike` con una sesión real.

## 2026-11-15 · `Library.like`

`ytm::like` (`like/like` de InnerTube) y `Library.like` → `gustado`, que después vuelve a pedir
«Me gusta». Compila sin avisos; **no verificado** contra YouTube con una sesión real (no se usan
las cookies del propietario en pruebas). Sin sesión responde «Hace falta iniciar sesión…».

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.
