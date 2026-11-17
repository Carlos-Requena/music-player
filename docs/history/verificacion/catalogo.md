# Historial de verificación · Catálogo de YouTube Music

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/catalogo.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-17 · Cliente HTTP común y búsqueda en paralelo (rama `perf/letra`)

- **Cambio:** `ytm::http`, un cliente HTTP para toda la app que reutiliza las conexiones; la
  búsqueda pide sus cuatro listas a la vez; `to_json` recorta las zonas sin copiarlas;
  `Catalog.categorias` sale de `categoriasJson`; `Catalog.allItems` para Lomos y Cubeta; fuera
  `Catalog.lineProgress`, que no usaba nadie.
- **Verificado:** `--probe search "Vetusta Morla"`, tres veces con cada versión: 1,6–1,8 s → 0,50–0,57 s.
  `cargo test` en verde; capturas de Inicio, Lomos y Opciones sin errores de QML.
- **No verificado:** con sesión (la búsqueda y las secciones de la cuenta); cambiar de categoría de
  playlists tocando otra opción.

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
