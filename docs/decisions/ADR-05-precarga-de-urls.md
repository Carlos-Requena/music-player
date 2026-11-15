---
adr: ADR-05
titulo: Precargar la URL de lo que probablemente se va a pedir
estado: aceptada
fecha: 2026-11-13
areas: [resolucion]
---

# ADR-05 · Precargar la URL de lo que probablemente se va a pedir

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [resolucion](../areas/resolucion.md)

## Decisión

Las URLs se resuelven por adelantado (foco detenido 250 ms, ratón sobre una carátula, las tres siguientes de la cola, las seis primeras de un álbum abierto, las cuatro primeras de una sección) y se guardan hasta 10 minutos antes de su `expire=`. `resolver::hint` solo atiende la última petición.

## Alternativas descartadas

- **Precargar todo lo visible**: decenas de peticiones a YouTube por pantalla y riesgo de que bloquee la IP.
- **Sin precarga**: ~0,4–0,6 s por clic frente a 64–254 ms con ella (2026-11-13, M4 Pro).

## Motivo

Con precarga el clic suena casi al instante, que es la segunda prioridad del propietario.

## Consecuencias

- Una petición en curso se comparte: si llega el clic mientras se precarga, espera a esa.
- Un disparador nuevo de precarga debe pasar por `hint` (último gana) o por `prefetch` (lista corta).
