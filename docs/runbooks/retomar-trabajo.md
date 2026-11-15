# Retomar una tarea a medias

Para quien sigue un trabajo sin la conversación en la que empezó: otra persona, otra sesión o el
mismo agente después de compactar su contexto. El resumen de una conversación pierde detalles;
el repositorio no ([AGENTES §9.1](../AGENTES.md#91-norma-escribir-para-quien-llega-sin-memoria)).

## Al empezar una tarea larga

Larga es la que no se termina en una sesión, la que tiene varios pasos que se pueden cortar o la
que acumula decisiones del propietario.

1. Rama propia ([AGENTES §13](../AGENTES.md#13-norma-una-rama-por-tarea)).
2. En [EN-CURSO.md](../EN-CURSO.md), el esqueleto con el objetivo, las áreas y los pasos.

## Durante

- **Al terminar cada paso**, actualiza «Hecho» y «Falta», y haz commit si el propietario lo ha
  autorizado.
- **Cada decisión del propietario**, en cuanto la tome: a su sitio definitivo (§11 de AGENTES,
  ADR o ficha) y una línea en «Decisiones tomadas» diciendo dónde está.
- **Lo que se probó y no funcionó**, en «Cuidado», con el porqué: es lo primero que se pierde al
  compactar y lo que más tiempo hace perder.

## Al retomar

1. Lee [EN-CURSO.md](../EN-CURSO.md).
2. `git status`, `git log --oneline master..HEAD` y `git diff`: lo que dice el repositorio manda
   sobre lo que diga el resumen de la conversación.
3. La ficha de cada área de la tarea.
4. `python3 scripts/docs.py check` y `cargo build --release`, para saber de qué estado partes.
5. Si algo de la nota no cuadra con el código, pregúntale al propietario antes de seguir.

## Al terminar

- Lo que valga la pena guardar de la nota pasa a su ficha, a una ADR o al historial.
- [EN-CURSO.md](../EN-CURSO.md) vuelve a «Ninguna tarea en curso».
