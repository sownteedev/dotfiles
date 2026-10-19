#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 resolution;
    int transitionStyle;
};

layout(binding = 1) uniform sampler2D outgoingTexture;
layout(binding = 2) uniform sampler2D incomingTexture;

float hexDistance(vec2 position) {
    vec2 distance = abs(position);
    return max(distance.x * 0.577350269 + distance.y, distance.x * 1.154700538);
}

float revealBefore(float distance, float maximumDistance, float amount, float feather) {
    float edge = mix(-feather, maximumDistance + feather, amount);
    return 1.0 - smoothstep(edge - feather, edge + feather, distance);
}

void main() {
    vec4 outgoingColor = texture(outgoingTexture, qt_TexCoord0);
    vec4 incomingColor = texture(incomingTexture, qt_TexCoord0);
    float amount = clamp(progress, 0.0, 1.0);
    if (amount <= 0.0 || amount >= 1.0) {
        fragColor = (amount <= 0.0 ? outgoingColor : incomingColor) * qt_Opacity;
        return;
    }
    if (transitionStyle == 4) {
        fragColor = mix(outgoingColor, incomingColor, amount) * qt_Opacity;
        return;
    }

    vec2 viewport = max(resolution, vec2(1.0));
    vec2 position = (qt_TexCoord0 - vec2(0.5)) * viewport;
    float feather = max(2.0, min(viewport.x, viewport.y) * 0.006);
    float reveal;
    if (transitionStyle >= 5 && transitionStyle <= 10) {
        vec2 pixel = qt_TexCoord0 * viewport;
        float distance;
        float maximumDistance;
        if (transitionStyle <= 6) {
            distance = transitionStyle == 5 ? pixel.x : viewport.x - pixel.x;
            maximumDistance = viewport.x;
        } else if (transitionStyle <= 8) {
            distance = transitionStyle == 7 ? pixel.y : viewport.y - pixel.y;
            maximumDistance = viewport.y;
        } else {
            distance = transitionStyle == 9 ? pixel.x + pixel.y : viewport.x + viewport.y - pixel.x - pixel.y;
            maximumDistance = viewport.x + viewport.y;
        }
        reveal = revealBefore(distance, maximumDistance, amount, feather);
    } else if (transitionStyle == 13 || transitionStyle == 14) {
        float distance = transitionStyle == 13 ? abs(position.x) : abs(position.y);
        float maximumDistance = (transitionStyle == 13 ? viewport.x : viewport.y) * 0.5;
        reveal = revealBefore(distance, maximumDistance, amount, feather);
    } else if (transitionStyle == 15) {
        vec2 cell = floor(qt_TexCoord0 * viewport / 36.0);
        float threshold = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
        float edge = mix(-0.12, 1.12, amount);
        reveal = smoothstep(threshold - 0.12, threshold + 0.12, edge);
    } else {
        bool hexagon = transitionStyle == 2 || transitionStyle == 3;
        bool diamond = transitionStyle == 11 || transitionStyle == 12;
        bool shrinking = transitionStyle == 1 || transitionStyle == 3 || transitionStyle == 12;
        float distanceFromCenter = hexagon ? hexDistance(position) : length(position);
        float maximumDistance = hexagon ? hexDistance(viewport * 0.5) : length(viewport * 0.5);
        if (diamond) {
            distanceFromCenter = abs(position.x) + abs(position.y);
            maximumDistance = (viewport.x + viewport.y) * 0.5;
        }
        float inside = revealBefore(distanceFromCenter, maximumDistance, shrinking ? 1.0 - amount : amount, feather);
        reveal = shrinking ? 1.0 - inside : inside;
    }
    fragColor = mix(outgoingColor, incomingColor, reveal) * qt_Opacity;
}
