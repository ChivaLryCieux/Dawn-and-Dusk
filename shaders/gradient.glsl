extern float elapsed;
extern vec2 screenSize;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 pixel = Texel(tex, tc);
    if (pixel.a < 0.01) return pixel;

    vec2 uv = sc / screenSize;
    float t = elapsed;

    // Multiple animated focal points
    vec2 c1 = vec2(0.3 + 0.2 * sin(t * 0.13), 0.4 + 0.2 * cos(t * 0.17));
    vec2 c2 = vec2(0.7 + 0.2 * cos(t * 0.11), 0.6 + 0.2 * sin(t * 0.19));
    vec2 c3 = vec2(0.5 + 0.25 * sin(t * 0.07 + 1.0), 0.3 + 0.25 * cos(t * 0.09 + 2.0));

    // Distance fields from each focal point
    float d1 = length(uv - c1);
    float d2 = length(uv - c2);
    float d3 = length(uv - c3);

    // Blend waves from each center, different frequencies
    float w1 = sin(d1 * 18.0 - t * 1.2) * 0.5 + 0.5;
    float w2 = sin(d2 * 14.0 - t * 0.9 + 1.0) * 0.5 + 0.5;
    float w3 = sin(d3 * 20.0 - t * 1.5 + 2.0) * 0.5 + 0.5;

    // Interference between sources
    float g = w1 * 0.4 + w2 * 0.35 + w3 * 0.25;
    g = smoothstep(0.2, 0.8, g);

    // Palette: deep blue → cyan → indigo
    vec3 gradColor = mix(
        vec3(0.03, 0.10, 0.25),
        vec3(0.0, 0.50, 0.68),
        g
    );
    gradColor = mix(gradColor,
        vec3(0.12, 0.06, 0.30),
        sin(d2 * 10.0 + t * 0.5) * 0.5 + 0.5
    );

    vec3 finalColor = mix(pixel.rgb, gradColor, 0.45) * 1.1;
    return vec4(finalColor, pixel.a);
}
