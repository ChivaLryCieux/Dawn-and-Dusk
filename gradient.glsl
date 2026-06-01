extern float elapsed;
extern vec2 screenSize;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 pixel = Texel(tex, tc);
    if (pixel.a < 0.01) {
        return pixel;
    }

    vec2 uv = sc / screenSize;
    float t = elapsed;

    // Primary diagonal sweep — smooth horizontal flow
    float g = sin(uv.x * 5.0 + uv.y * 3.0 - t * 0.7) * 0.5 + 0.5;
    // Secondary perpendicular wave — slower, for organic variation
    g += sin(uv.y * 7.0 + uv.x * 2.5 + t * 0.3) * 0.3;
    g = smoothstep(0.2, 0.9, g);

    // Gradient color palette: dark blue ↔ cyan ↔ deep blue
    vec3 gradColor = mix(
        vec3(0.02, 0.08, 0.22),
        vec3(0.0, 0.55, 0.72),
        g
    );

    // Blend: 45% flowing gradient + 55% original tower colors
    vec3 finalColor = mix(pixel.rgb, gradColor, 0.45) * 1.1;

    return vec4(finalColor, pixel.a);
}
