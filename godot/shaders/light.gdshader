// Screen-space lighting: dusk tint lifted by soft light pools, plus vignette. Coloured glows are drawn additively in the world.
shader_type canvas_item;

uniform vec2 view_size = vec2(1280.0, 600.0);
uniform float darkness = 0.15;
uniform vec3 dark_color = vec3(0.13, 0.08, 0.2);
uniform int light_count = 0;
uniform vec4 lights[48]; // x, y, radius, strength in screen pixels

void fragment() {
	vec2 p = UV * view_size;
	float lit = 0.0;
	for (int i = 0; i < 48; i++) {
		if (i >= light_count) break;
		vec4 L = lights[i];
		float k = clamp(1.0 - length(p - L.xy) / L.z, 0.0, 1.0);
		lit = max(lit, k * k * L.w);
	}
	vec2 q = (UV - 0.5) * vec2(view_size.x / view_size.y, 1.0);
	float v = smoothstep(0.45, 1.05, length(q));
	COLOR = vec4(mix(dark_color, vec3(0.08, 0.04, 0.08), v), clamp(darkness * (1.0 - lit) + v * 0.32, 0.0, 0.95));
}
