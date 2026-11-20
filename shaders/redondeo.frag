#version 440
// Esquinas redondeadas de la carátula animada de «Sonando». Sustituye a una capa con máscara
// (`layer` + `MultiEffect`), que reservaba ~20 MB y gastaba ~5 % de CPU más con el vídeo: lee la
// textura del vídeo y calcula el borde con una distancia a un rectángulo redondeado. Se compila
// con `scripts/shaders.sh` (qsb) y el .qsb va en el repositorio.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;     // tamaño del elemento en píxeles lógicos
    float radius;  // radio de las esquinas, en píxeles lógicos
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    vec2 q = abs(p) - (0.5 * size - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    fragColor = texture(source, qt_TexCoord0) * alpha * qt_Opacity;
}
