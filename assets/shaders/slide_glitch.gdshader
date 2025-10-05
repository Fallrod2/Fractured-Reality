shader_type canvas_item;

// Slide-in glitch effect for sidebar transitions
uniform float slide_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_glow : source_color = vec4(0, 1, 1, 0.8);
uniform float glitch_intensity : hint_range(0.0, 0.5) = 0.1;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Apply slide effect based on progress
    float slide_offset = (1.0 - slide_progress) * 1.2;
    uv.x += slide_offset;

    // Glitch distortion at the edge during slide
    if (slide_progress < 0.95) {
        float edge_dist = abs(uv.x - slide_offset);
        if (edge_dist < 0.1) {
            float row = floor(uv.y * 40.0);
            float glitch = (random(vec2(row, floor(TIME * 10.0))) - 0.5) * glitch_intensity;
            uv.x += glitch * (1.0 - slide_progress);
        }
    }

    // Sample texture
    vec4 color = texture(TEXTURE, uv);

    // Add edge glow during transition
    if (slide_progress > 0.0 && slide_progress < 1.0) {
        float edge_dist = abs(uv.x - slide_offset);
        float glow_strength = smoothstep(0.15, 0.0, edge_dist) * (1.0 - slide_progress);
        color.rgb += edge_glow.rgb * glow_strength * edge_glow.a;
    }

    // Fade in based on slide progress
    color.a *= slide_progress;

    COLOR = color;
}
