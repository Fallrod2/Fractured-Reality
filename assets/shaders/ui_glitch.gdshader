shader_type canvas_item;

// Glitch effect parameters
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.05;
uniform float scan_line_speed : hint_range(0.0, 5.0) = 1.0;
uniform float scan_line_density : hint_range(100.0, 1000.0) = 800.0;
uniform float noise_amount : hint_range(0.0, 0.2) = 0.02;
uniform float horizontal_shake : hint_range(0.0, 0.1) = 0.01;
uniform vec4 glitch_color : source_color = vec4(0.0, 1.0, 1.0, 0.3);

// Random function for noise
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Noise function
float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV;

    // Horizontal glitch distortion
    float glitch_line = floor(uv.y * 20.0);
    float glitch_time = floor(TIME * 2.0);
    float glitch_trigger = step(0.95, random(vec2(glitch_line, glitch_time)));

    // Apply horizontal offset on random lines
    float offset = (random(vec2(glitch_line, glitch_time)) - 0.5) * glitch_strength * glitch_trigger;
    uv.x += offset;

    // Subtle horizontal shake
    uv.x += sin(TIME * 10.0 + uv.y * 50.0) * horizontal_shake * step(0.98, sin(TIME * 2.0));

    // Get base texture color
    vec4 color = texture(TEXTURE, uv);

    // Add scanlines
    float scanline = sin(uv.y * scan_line_density - TIME * scan_line_speed) * 0.04;
    color.rgb += vec3(scanline);

    // Add noise
    float noise_val = noise(uv * 100.0 + TIME * 5.0) * noise_amount;
    color.rgb += vec3(noise_val);

    // Add glitch color tint on glitched lines
    color.rgb = mix(color.rgb, glitch_color.rgb, glitch_trigger * glitch_color.a * 0.5);

    // RGB split effect on glitched areas
    if (glitch_trigger > 0.5) {
        float split_offset = 0.005;
        float r = texture(TEXTURE, uv + vec2(split_offset, 0.0)).r;
        float b = texture(TEXTURE, uv - vec2(split_offset, 0.0)).b;
        color.r = r;
        color.b = b;
    }

    COLOR = color;
}
