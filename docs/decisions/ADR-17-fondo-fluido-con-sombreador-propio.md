---
adr: ADR-17
titulo: El fondo «Fluido» es un sombreador propio, precompilado con qsb y guardado en el repositorio
estado: aceptada
fecha: 2026-11-16
areas: [personalizacion]
---

# ADR-17 · El fondo «Fluido» es un sombreador propio, precompilado con qsb y guardado en el repositorio

- **Estado:** Aceptada.
- **Registrada:** 2026-11-16
- **Ámbito:** [personalizacion](../areas/personalizacion.md)

## Decisión

El modo ambiente «Fluido» (la carátula muy desenfocada y deformada, al estilo Better Lyrics
Shaders) es un `ShaderEffect` con un sombreador propio, `shaders/fluido.frag`, que sigue la técnica
que describe Kawarp (MIT): desenfoque y deformación de dominio con ruido. El `.qsb` compilado con
`scripts/shaders.sh` va en el repositorio junto al `.frag` y `build.rs` lo mete en el binario con
`qrc_resources` (`qrc:/qt/qml/app/musicplayer/shaders/fluido.frag.qsb`); si el `.frag` es más
nuevo que su `.qsb`, la compilación avisa. La carátula llega diminuta (32 px) y el desenfoque se
completa en el propio sombreador, que se dibuja en una capa a la mitad de la resolución lógica.

## Alternativas descartadas

- **Copiar el sombreador de Better Lyrics Shaders**: la extensión es GPL-3.0; solo se toma la
  técnica, descrita por Kawarp (MIT).
- **Compilar con qsb en cada `cargo build`**: obligaría a tener `qsb` en el PATH al compilar y a
  servir el resultado desde `OUT_DIR`; el `.qsb` precompilado ocupa ~6 KB y cambia muy poco.
- **Desenfoque Kawase previo en texturas intermedias** (como Kawarp): con la carátula a 32 px, un
  anillo de nueve muestras en el propio sombreador basta y no necesita más capas ni memoria.
- **A la resolución completa de la pantalla**: el resultado es tan suave que dibujarlo a la mitad
  de la resolución lógica (un cuarto en Retina) y ampliarlo no se nota, con 16 veces menos píxeles.

## Motivo

El propietario quiere el aspecto de Better Lyrics Shaders, con la letra sobre el fondo y sin
recuadro. Medido el 2026-11-16 (M4 Pro, release, 1440×900 Retina, 25 s): quieto, 0,08 s de CPU y
196 MB (como sin él); moviéndose a 15 Hz, 2,2 s de CPU (~9 %) y ~300–317 MB, la misma memoria
extra que la deriva de los focos (cualquier redibujado continuo la sube).

## Consecuencias

- Cambiar `shaders/*.frag` obliga a ejecutar `scripts/shaders.sh` (necesita `qsb`:
  `qtshadertools` / `qt6-shadertools`) y a subir también el `.qsb`.
- Un sombreador nuevo se añade a `SHADERS` en `build.rs`.
- El `.qsb` incluye GLSL, HLSL y MSL: sirve en macOS (Metal), Linux (OpenGL/Vulkan) y Windows.
