# Plantilla: decisión de arquitectura (ADR)

Una decisión por archivo, en `docs/decisions/ADR-NN-palabras-clave.md`, con el número siguiente
al último (sin huecos). Cuándo hace falta una y cómo se escribe:
[runbooks/registrar-decision.md](../runbooks/registrar-decision.md).

- **El texto de una ADR no se reescribe.** Si algo cambia, se escribe otra y en la antigua solo
  se cambia `estado:` a «ampliada por ADR-NN» o «sustituida por ADR-NN» (y la línea de estado).
- Cada área de `areas:` cita la ADR en su `adr:`, y al revés: el comprobador lo exige.

## Esqueleto

```markdown
---
adr: ADR-NN
titulo: <La decisión en una frase>
estado: aceptada
fecha: AAAA-MM-DD
areas: [<áreas de docs/areas/ a las que afecta, o vacío si es de todo el proyecto>]
---

# ADR-NN · <La decisión en una frase>

- **Estado:** Aceptada.
- **Registrada:** AAAA-MM-DD
- **Ámbito:** <áreas enlazadas, o «todo el proyecto»>

## Decisión

<Qué se decidió, en concreto: lo que una persona tiene que saber para no romperlo.>

## Alternativas descartadas

- **<Alternativa>**: por qué no (con la medida si la hay).

## Motivo

<El problema que había y por qué esta solución. Las cifras, con fecha y máquina.>

## Consecuencias

- <Qué obliga a hacer a partir de ahora; qué queda más difícil.>
```
