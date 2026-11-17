#version 440
// Reflejo de una carátula en el suelo (vista Lomos): la parte de abajo de la carátula, volteada,
// que se funde hacia abajo. Sustituye a una capa con máscara (`layer` + `MultiEffect`) por caja:
// lee la textura que la carátula ya tiene y no reserva ninguna otra. Se compila con
// `scripts/shaders.sh` (qsb) y el .qsb va en el repositorio.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float ratio;   // alto del reflejo respecto al de la carátula
    float loaded;  // 1 con la carátula cargada; 0 mientras carga (se ve `base`)
    float cropX;   // parte de la textura que se ve a lo ancho (carátulas no cuadradas)
    float cropY;   // y a lo alto
    vec4 base;     // color de la caja mientras carga la carátula
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 uv = qt_TexCoord0;
    // Del borde de abajo de la carátula hacia arriba, recortada al centro como PreserveAspectCrop.
    vec2 at = vec2(uv.x, 1.0 - uv.y * ratio);
    at = 0.5 + (at - 0.5) * vec2(cropX, cropY);
    vec4 color = mix(base, texture(source, at), loaded);
    // Se funde hacia abajo, con la misma curva que daba la máscara (umbral 0,5 y difusión 1).
    float fade = smoothstep(0.0, 1.0, 1.0 - uv.y);
    fragColor = color * fade * qt_Opacity;
}
