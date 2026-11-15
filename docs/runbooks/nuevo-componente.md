# Añadir un archivo QML o un puente de Rust

Las dos trampas que más veces han roto la compilación ([TRAMPAS](../TRAMPAS.md#compilación-y-cxx-qt)).
`python3 scripts/docs.py check` comprueba los tres registros.

## Archivo QML

1. Crea `qml/MiCosa.qml`. Si sirve en dos sitios, es una pieza común
   ([interfaz-comun](../areas/interfaz-comun.md)).
2. Regístralo en `build.rs`: `QML_FILES` (o `QML_SINGLETONS` si es un singleton, con
   `pragma Singleton`).
3. Añádelo al `archivos:` de la ficha de su área y a su tabla «Archivos».
4. Úsalo como `MiCosa { … }`.

## Propiedad o función en un singleton existente

Paso a paso con ejemplo: [GUIA §7.4](../GUIA.md#74-añadir-una-propiedad-o-función-a-player).
Lo que no se puede olvidar:

- La propiedad, `#[qproperty(tipo, nombre)]` dentro de `extern "RustQt"`, con su campo en el
  `struct …Rust` y su valor en `Default`.
- La función, `#[qinvokable]` con **solo la firma** en el puente; el cuerpo en
  `impl qobject::…`. Nunca dentro del bloque `extern "RustQt"`.
- En QML el nombre pasa a `camelCase`.
- Si es lenta, en un hilo con `qt_thread().queue(...)` y un contador para descartar respuestas
  obsoletas.

## Puente Rust nuevo (un singleton más)

1. `src/mi_cosa.rs` con su `#[cxx_qt::bridge]`.
2. En `build.rs`, dentro de `.files([...])`.
3. En `src/main.rs`, `mod mi_cosa;`.
4. En el `archivos:` de su ficha. Si es una pieza nueva del dibujo, en
   [ARCHITECTURE](../ARCHITECTURE.md#piezas-y-procesos).
5. `cargo build --release` sin avisos.
