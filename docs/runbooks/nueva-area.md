# Crear un área nueva

Casi todo cambio cabe en un área existente ([INDEX](../INDEX.md#áreas)). Un área nueva hace falta
cuando aparece algo con archivos propios y reglas propias (un plugin nuevo, una vista nueva que
no es como las demás, un servicio).

## Pasos

1. **Rama:** `git switch -c feature/<area>` desde `master`
   ([AGENTES §13](../AGENTES.md#13-norma-una-rama-por-tarea)).
2. **Ficha:** `docs/areas/<area>.md` copiando el esqueleto de
   [la plantilla](../templates/area.md). Rellena el frontmatter desde el principio: `docs.py check`
   irá diciendo qué falta.
3. **Historial:** `docs/history/verificacion/<area>.md` con la cabecera de
   [su plantilla](../templates/verificacion.md).
4. **Código:** cada archivo nuevo, en el `archivos:` de la ficha; si mueves uno de otra área,
   quítalo de la otra (cada archivo, en una sola).
5. **Decisión:** si cruza la arquitectura o la fijó el propietario, una ADR
   ([registrar-decision](registrar-decision.md)).
6. **Índices:** `python3 scripts/docs.py index` y `check`.
7. **Verificar** ([AGENTES §8](../AGENTES.md#8-norma-verificar-antes-de-dar-algo-por-terminado)) y
   apuntarlo arriba en su historial y en «Estado actual».
