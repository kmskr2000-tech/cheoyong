shader_type canvas_item;
render_mode blend_add;
// Slanted light shafts falling through the haze; soft-edged, slowly breathing and drifting.
uniform vec3 tint : source_color = vec3(0.55, 0.72, 1.0);
uniform float strength = 0.16;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float x = uv.x + uv.y * 0.35 + TIME * 0.004; // slant
	float s = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float cx = hash(fi * 7.1) * 1.3 - 0.1;
		float w = 0.015 + hash(fi * 3.3) * 0.05;
		float k = smoothstep(w, 0.0, abs(x - cx));
		s += k * (0.5 + 0.5 * sin(TIME * (0.3 + hash(fi) * 0.4) + fi * 2.0));
	}
	s *= smoothstep(1.0, 0.1, uv.y); // fade toward the ground
	COLOR = vec4(tint * s * strength, 1.0);
}
