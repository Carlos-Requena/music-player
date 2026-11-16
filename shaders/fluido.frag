#version 440
// Fondo de «carátula fluida» (modo ambiente «Fluido»), con la técnica que describe Kawarp
// (MIT): la carátula, muy desenfocada, se deforma con ruido (domain warping) para que sus colores
// fluyan. Aquí la carátula llega ya diminuta (unos 32 px) y el desenfoque se completa con un
// anillo de muestras: con una textura tan pequeña cuesta poco y no hace falta ningún paso
// previo. Se compila con `scripts/shaders.sh` (qsb) y el .qsb va en el repositorio.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // segundos de animación (solo avanza mientras se mueve)
    float mixAmount;  // 0 = carátula anterior, 1 = la nueva (fundido al cambiar)
    float warp;       // intensidad de la deformación
    float saturation; // realce del color
    float darken;     // 0–1: cuánto se oscurece hacia `ground` para que el texto se lea
    float aspect;     // ancho / alto del fondo
    vec4 ground;      // color de fondo de la skin
};
layout(binding = 1) uniform sampler2D source0;
layout(binding = 2) uniform sampler2D source1;

float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Ruido de valor suave.
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;
    for (int k = 0; k < 3; ++k) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return v;
}

// Media de un anillo de muestras alrededor de `uv`: termina de desenfocar la carátula diminuta.
vec3 blurred(sampler2D tex, vec2 uv)
{
    vec3 sum = texture(tex, uv).rgb * 2.0;
    const float r = 0.05;
    for (int k = 0; k < 8; ++k) {
        float a = float(k) * 0.785398;
        sum += texture(tex, uv + r * vec2(cos(a), sin(a))).rgb;
    }
    return sum / 10.0;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y) * 1.4;
    float t = time * 0.06;

    // Deformación de dominio en dos niveles: el ruido desplaza al ruido.
    vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3) - t));
    vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + 0.7 * t),
                  fbm(p + 3.0 * q + vec2(8.3, 2.8) - 0.6 * t));
    vec2 w = uv + warp * 0.35 * (r - 0.5);
    // Acercada para no ver los bordes de la carátula al deformarla.
    w = 0.5 + (w - 0.5) * 0.7;

    vec3 c = blurred(source0, w);
    if (mixAmount > 0.0)
        c = mix(c, blurred(source1, w), mixAmount);

    // Realce del color y oscurecido hacia el fondo de la skin.
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    c = clamp(mix(vec3(l), c, saturation), 0.0, 1.0);
    // Las carátulas claras no pasan de un brillo medio: encima va texto blanco.
    l = dot(c, vec3(0.299, 0.587, 0.114));
    c *= min(1.0, 0.42 / max(l, 0.001));
    c = mix(c, ground.rgb, darken);
    // Un poco de grano para que los degradados oscuros no salgan con escalones.
    c += (hash(gl_FragCoord.xy + fract(time)) - 0.5) / 255.0 * 1.5;

    fragColor = vec4(c, 1.0) * qt_Opacity;
}
