shader_type canvas_item;
// Low drifting night fog, quantised to 2px world cells so it stays pixel-art. Two layers drift at
// different speeds; a sickly green tint creeps in where the fog is thickest (역병 기운).
uniform vec2 world_size = vec2(640.0, 368.0);
uniform vec4 tint : source_color = vec4(0.42, 0.5, 0.58, 1.0);
uniform vec4 sick : source_color = vec4(0.35, 0.6, 0.3, 1.0);
uniform float density = 0.55;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += noise(p) * a; p *= 2.03; a *= 0.5; } return v; }

void fragment() {
	vec2 w = floor(UV * world_size / 2.0) * 2.0;
	float a = fbm(w / 110.0 + vec2(TIME * 0.025, TIME * 0.008));
	float b = fbm(w / 60.0 + vec2(-TIME * 0.04, TIME * 0.015) + 7.0);
	float n = smoothstep(0.42, 0.9, a * 0.65 + b * 0.45);
	n = floor(n * 5.0) / 5.0; // banded, like painted fog
	vec3 col = mix(tint.rgb, sick.rgb, smoothstep(0.55, 0.9, b));
	COLOR = vec4(col, n * density);
}
