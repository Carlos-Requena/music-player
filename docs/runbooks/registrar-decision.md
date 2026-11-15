# Registrar una decisión (ADR)

## Cuándo

- Algo que cruza áreas o que cambia cómo se hacen las cosas (un proceso nuevo, otro formato de
  datos hacia QML, otra fuente de audio).
- Algo que el propietario fija y que no se debe cambiar sin preguntarle.
- Algo que se probó y se descartó con una medida: para que nadie lo vuelva a intentar sin un
  motivo nuevo.

Un detalle de un área (un umbral, un formato interno) va en «Reglas y decisiones» de su ficha, no
en una ADR.

## Pasos

1. **¿Ya está decidido?** Mira el [índice](../decisions/README.md#índice). Si contradice una ADR
   vigente, explícaselo al propietario antes de seguir.
2. **Archivo:** `docs/decisions/ADR-NN-palabras-clave.md` con el número siguiente al último y el
   esqueleto de [la plantilla](../templates/adr.md).
3. **Alternativas con su porqué**, con la medida si la hay (fecha y máquina). Las que no se
   probaron se dicen como razonadas.
4. **Áreas:** en `areas:` de la ADR y la ADR en el `adr:` de cada una de esas fichas, con un enlace
   desde su «Reglas y decisiones».
5. **Si sustituye o amplía otra**, en la antigua solo cambian `estado:` y la línea de estado.
6. `python3 scripts/docs.py index` y `check`.
