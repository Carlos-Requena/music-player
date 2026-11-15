# Plantilla: historial de verificación de un área

Un archivo por área, `docs/history/verificacion/<area>.md`. Es un **registro**: lo que ya está
escrito no se edita; lo nuevo va **arriba**.

```markdown
# Historial de verificación · <Nombre legible>

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/<area>.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## AAAA-MM-DD · <qué se cambió o se verificó>

- **Cómo:** <comandos exactos: `--shot …`, `--probe …`, `cargo test`, máquina, release o debug>.
- **Resultado:** <qué se vio; la línea `estado: …`; las medidas con su método>.
- **No verificado:** <lo que quedó sin probar y por qué>.
```
