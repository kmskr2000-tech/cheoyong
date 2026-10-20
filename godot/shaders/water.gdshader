// Water surface: translucent with moving glints.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 deep : source_color = vec4(0.05, 0.3, 0.45, 0.62);
uniform vec4 glint : source_color = vec4(0.8, 0.95, 1.0, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// sparse thin glints, gated by a slow large-scale swell
	float n = noise(w.xz * vec2(3.2, 6.0) + vec2(TIME * 0.35, TIME * 0.1));
	float swell = noise(w.xz * 0.45 - vec2(TIME * 0.05, TIME * 0.03));
	float g = smoothstep(0.8, 0.86, n) * smoothstep(0.45, 0.7, swell);
	vec3 base = mix(deep.rgb, deep.rgb * 1.35, swell);
	ALBEDO = mix(base, glint.rgb, g * 0.75);
	ALPHA = deep.a + g * 0.3;
}
