// Soft contact shadow lying on the ground under props and characters (anchors them to the terrain).
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.45;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.02, 0.02, 0.06);
	ALPHA = strength * (1.0 - smoothstep(0.35, 1.0, d)) * COLOR.a;
}
