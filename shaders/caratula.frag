#version 440
// Carátula con esquinas redondeadas (`Cover.radius`). Sustituye a una `Shape` por carátula, que
// en un Muro lleno costaba unos 24 MB más que las cuadradas: lee la textura de la imagen, la
// recorta para cubrir el recuadro (como `PreserveAspectCrop`) y calcula el borde con una distancia
// a un rectángulo redondeado. Se compila con `scripts/shaders.sh` (qsb) y el .qsb va en el
// repositorio.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;     // tamaño del elemento en píxeles lógicos
    float radius;  // radio de las esquinas, en píxeles lógicos
    vec2 crop;     // parte de la textura que se ve en cada eje (1 = entera), centrada
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    vec2 q = abs(p) - (0.5 * size - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    vec2 uv = 0.5 + (qt_TexCoord0 - 0.5) * crop;
    fragColor = texture(source, uv) * alpha * qt_Opacity;
}
