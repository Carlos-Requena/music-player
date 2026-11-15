---
adr: ADR-01
titulo: Qt 6 / QML para la interfaz y Rust con cxx-qt para el núcleo
estado: aceptada
fecha: 2026-11-13
areas: []
---

# ADR-01 · Qt 6 / QML para la interfaz y Rust con cxx-qt para el núcleo

- **Estado:** Aceptada.
- **Registrada:** 2026-11-13 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** todo el proyecto

## Decisión

Interfaz en **Qt 6 / QML** (Qt Quick sobre Metal en macOS y Vulkan/OpenGL en Linux) y núcleo en **Rust**, unidos con **cxx-qt 0.10**. Los objetos que ve QML son singletons definidos en Rust (`Player`, `Library`, `Account`, `AppSettings`, `Plugins`). Nada de Electron ni de un navegador embebido en el reproductor.

## Alternativas descartadas

- **Electron / Tauri con web**: lo que se quiere sustituir (Pear Desktop pasa de 500 MB a 1 GB sumando procesos); un WebView por sí solo ya cuesta más que la app entera.
- **GTK o una interfaz nativa por sistema**: dos interfaces que mantener y sin las animaciones 3D y el vidrio que pide el propietario.
- **Qt con C++ en el núcleo**: posible, pero Rust da hilos y red más seguros y el propietario lo eligió.

## Motivo

El propietario quiere un cliente ligero y rápido para macOS y CachyOS, muy personalizable y con estética cuidada (vidrio, modo ambiente, estantería 3D). Lo eligió entre varias alternativas el 2026-11-13.

## Consecuencias

- Toda la interfaz pasa por QML y sus trampas ([TRAMPAS](../TRAMPAS.md)); el puente tiene las suyas (invocables y `#[auto_cxx_name]`).
- Cada archivo QML y cada puente se registran en `build.rs` (lo comprueba `scripts/docs.py`).
- La memoria base la marca Qt Quick, no nuestro código ([ARCHITECTURE](../ARCHITECTURE.md#memoria-y-arranque)).
