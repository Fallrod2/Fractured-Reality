shader_type canvas_item;

// Title-specific glitch effect with horizontal distortion
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.015;
uniform float glitch_frequency : hint_range(0.0, 10.0) = 2.0;
uniform vec4 glow_color : source_color = vec4(0.498039, 0, 1, 0.8);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;

// Random function
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Subtle horizontal displacement on random rows
    float row = floor(uv.y * 30.0);
    float time_step = floor(TIME * glitch_frequency);
    float glitch_trigger = step(0.97, random(vec2(row, time_step)));

    // Apply horizontal offset
    float offset = (random(vec2(row, time_step)) - 0.5) * distortion_strength * glitch_trigger;
    uv.x += offset;

    // Sample texture
    vec4 color = texture(TEXTURE, uv);

    // Add electric purple glow
    if (color.a > 0.1) {
        vec2 center_offset = UV - vec2(0.5, 0.5);
        float dist_from_center = length(center_offset);

        // Pulsing glow effect
        float pulse = 0.5 + 0.5 * sin(TIME * 3.0);
        float glow = (1.0 - smoothstep(0.0, 0.5, dist_from_center)) * pulse * glow_intensity;

        color.rgb += glow_color.rgb * glow * 0.3;
    }

    // RGB chromatic aberration on glitched rows
    if (glitch_trigger > 0.5 && color.a > 0.1) {
        float split = 0.003;
        float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
        float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
        color.r = mix(color.r, r, 0.7);
        color.b = mix(color.b, b, 0.7);
    }

    COLOR = color;
}
