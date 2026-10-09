shader_type canvas_item;
uniform float strength = 0.75;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.46)) * vec2(1.0, 0.75);
	float v = smoothstep(0.25, 0.75, length(d));
	COLOR = vec4(0.01, 0.0, 0.03, v * strength);
}
