#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 resolution;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float amount = clamp(progress, 0.0, 1.0);
    vec2 viewport = max(resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 offset = vec2(2.0 * amount) / viewport;

    vec4 color = texture(source, uv) * 0.25;
    color += texture(source, uv + vec2(offset.x, 0.0)) * 0.125;
    color += texture(source, uv - vec2(offset.x, 0.0)) * 0.125;
    color += texture(source, uv + vec2(0.0, offset.y)) * 0.125;
    color += texture(source, uv - vec2(0.0, offset.y)) * 0.125;
    color += texture(source, uv + offset) * 0.0625;
    color += texture(source, uv - offset) * 0.0625;
    color += texture(source, uv + vec2(offset.x, -offset.y)) * 0.0625;
    color += texture(source, uv + vec2(-offset.x, offset.y)) * 0.0625;

    fragColor = color * qt_Opacity;
}
