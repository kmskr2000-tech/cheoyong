// HD-2D tilt-shift: blur the top and bottom of the 3D view, keep the middle band sharp.
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float band = 0.28;
uniform float strength = 2.2;

void fragment() {
	float d = abs(SCREEN_UV.y - 0.52);
	float k = clamp((d - band) / (0.5 - band), 0.0, 1.0);
	float lod = k * strength;
	COLOR = vec4(textureLod(screen, SCREEN_UV, lod).rgb, k > 0.001 ? 1.0 : 0.0);
}
