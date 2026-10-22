// Inverted-hull ink outline drawn as next_pass of toon.gdshader.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.09, 0.06, 0.1, 1.0);
uniform float width = 0.035;  // metres
uniform float alpha = 1.0;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
	float bayer = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) + 0.125 * mod(floor(FRAGCOORD.y), 2.0));
	if (alpha < 0.999 && alpha <= bayer) discard;
}
