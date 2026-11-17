---
adr: ADR-20
titulo: La fuente de Explorar se elige en Opciones (ListenBrainz por defecto o YouTube Music)
estado: aceptada
fecha: 2026-11-17
areas: [catalogo]
---

# ADR-20 · La fuente de Explorar se elige en Opciones (ListenBrainz por defecto o YouTube Music)

- **Estado:** Aceptada.
- **Registrada:** 2026-11-17
- **Ámbito:** [catalogo](../areas/catalogo.md)

## Decisión

Amplía [ADR-19](ADR-19-explorar-con-listenbrainz.md): Explorar ya no sustituye para siempre al
Explorar de YouTube Music. La opción `explorarFuente` (Opciones › Vistas › «Fuente de Explorar»)
elige entre **ListenBrainz** (por defecto, vacío) y **YouTube Music** (`youtube`, que vuelve a
pedir `FEmusic_explore`). Cada fuente guarda su propia copia en disco (`explorar-listenbrainz` y
`explorar`) y, al cambiar, Explorar se vacía y se vuelve a cargar: nunca se ve la copia de la
otra fuente.

## Alternativas descartadas

- **Mostrar las dos a la vez** (zonas de ListenBrainz y de YouTube en la misma sección): la sección
  sería muy larga y mezclaría criterios; el propietario pidió elegir.
- **Una sección más** («Descubrir») con ListenBrainz: ya se descartó en ADR-19.

## Motivo

El propietario lo pidió tras conectar ListenBrainz: sin escuchas, ListenBrainz tarda días en
tener recomendaciones, y el Explorar de YouTube sigue siendo útil.

## Consecuencias

- Rust lee la opción al arrancar y al cambiar (`library::set_explorar_youtube`); `Main.qml`
  llama a `Library.load` cuando cambia.
