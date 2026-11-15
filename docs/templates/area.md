# Plantilla: ficha de un área

El código no está repartido en carpetas por funcionalidad (`src/` y `qml/` son planos), así que
cada **área** del programa tiene su ficha en `docs/areas/<area>.md`: qué hace, sus reglas, qué
archivos son suyos y cómo se verificó. Es lo único que hace falta leer para tocarla.

`python3 scripts/docs.py check` comprueba el frontmatter, las secciones y su orden, que los
archivos existan y que **cada archivo de código esté en una sola ficha**, que las opciones existan
en el código (y que cada opción del código esté en una ficha), que «Dependencias» enlace las áreas
que su código usa de verdad, que las ADR citadas la citen a ella y que el historial exista y esté
enlazado. `python3 scripts/docs.py index` regenera con todo ello las tablas de
[INDEX.md](../INDEX.md).

## Reglas de escritura

- **Solo lo vigente.** Nada de «antes…», «hasta que exista…» ni fechas de cuándo se hizo algo:
  eso va a `docs/history/verificacion/<area>.md` o al
  [changelog técnico](../history/CHANGELOG-TECNICO.md).
- **Una sola fuente.** Lo que es de otra área se enlaza, no se copia. Las normas generales están
  en [AGENTES.md](../AGENTES.md) y las trampas en [TRAMPAS.md](../TRAMPAS.md): no se repiten.
- **Medidas con fecha y máquina** («2026-11-14, M4 Pro, release»). La medida vieja no se borra: se
  mueve al historial con su fecha.
- **Rutas completas desde la raíz** en `archivos:` (`src/player.rs`, no `player.rs`).
- **Dónde está cada cosa** (apartado de «Archivos»): una tabla corta *concepto → símbolo* para no
  tener que explorar. Cada símbolo enlaza a su archivo con ruta relativa,
  ``[`nombre`](../../src/archivo.rs)``, sin número de línea (caduca); el comprobador mira que el
  nombre exista en ese archivo.
- Secciones opcionales: **Cómo funciona**, **Interfaz**, **Medidas** y **Pendiente** (esta, solo con
  trabajo concreto; las ideas van al [ROADMAP](../ROADMAP.md)). Dentro de cada sección, los
  apartados que hagan falta con `###`. Ninguna sección de nivel 2 fuera de la lista.

## Esqueleto

Copia desde aquí (sin el bloque de código):

```markdown
---
area: <nombre del archivo, sin .md>
titulo: <Nombre legible>
resumen: <Una frase: qué hace para quien usa la app. Se copia en el índice.>
archivos: [<rutas desde la raíz de los archivos de código que son de esta área>]
opciones: [<claves de AppSettings.opcion que lee o escribe; retraso:* para las que llevan sufijo>]
adr: [<ADR-NN que la afectan>]
---

# <Nombre legible>

<Uno o dos párrafos si el resumen no basta: cómo se llega (tecla, botón, menú) y qué se ve.>

## Qué hace

<Comportamiento visible y lo que pidió el propietario.>

## Reglas y decisiones

<Reglas vigentes, preferencias del propietario (con su porqué) y alternativas descartadas en una
línea. Enlaza las ADR.>

## Cómo funciona

<El mecanismo: hilos, peticiones, formatos, el camino de los datos.>

## Interfaz

<Qué componentes usa, teclado, accesibilidad, animaciones y su coste.>

## Medidas

| Situación | Medida | Fecha y máquina |
|---|---|---|

## Archivos

| Archivo | Contenido |
|---|---|

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| <Qué hace o qué regla> | [`símbolo`](../../src/archivo.rs) |

## Dependencias

- **[<otra área>](<otra>.md)** (`<archivo o llamada>`): para qué. Si hace falta leer su ficha para
  tocar esta, dilo; si no, «no hace falta leerla».
- **La usan:** <áreas que la usan>.

## Estado actual

- **Última verificación:** AAAA-MM-DD, <cómo: captura, --autoplay, --probe, cargo test…>.
- **Pruebas:** <`mod tests` de qué archivos, o «ninguna»>.
- **Sin verificar:** <lo que nadie ha probado todavía: Linux, Wayland, sin sesión…>.
- **Historial:** [docs/history/verificacion/<area>.md](../history/verificacion/<area>.md).

## Pendiente

- <Trabajo concreto que falta.>
```
