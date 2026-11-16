#!/bin/sh
# Compila los sombreadores de shaders/ con qsb (Qt Shader Tools) a .qsb, que van en el
# repositorio: así compilar la app no necesita qsb. Vuelve a ejecutarlo al cambiar un .frag.
#   macOS: brew install qtshadertools   ·   CachyOS: pacman -S qt6-shadertools
set -e
cd "$(dirname "$0")/.."
for frag in shaders/*.frag; do
    qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$frag.qsb" "$frag"
    echo "compilado: $frag.qsb"
done
