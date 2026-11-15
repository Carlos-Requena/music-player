# Historial

Lo que pasó, no cómo es la app hoy. Los documentos vigentes (la guía, ARCHITECTURE, TRAMPAS, las
fichas) solo describen el presente y enlazan aquí cuando hace falta el contexto.

| Archivo | Qué contiene |
|---|---|
| [CHANGELOG-TECNICO.md](CHANGELOG-TECNICO.md) | Cronología, medidas de cada época, lo que se quitó y los fallos resueltos |
| [verificacion/](verificacion/) | Un archivo por área con cómo se verificó en cada momento (lo nuevo, arriba) |

**Cómo se añade:** al verificar un área, una sección `## AAAA-MM-DD · qué se verificó` encima de
las anteriores en su archivo de `verificacion/` ([plantilla](../templates/verificacion.md)), y la
fecha en el «Estado actual» de su ficha. Al cambiar algo importante, resolver un fallo o sustituir
una medida, una fila arriba en la tabla correspondiente del changelog. **Nada de esto se edita
después:** es un registro.
