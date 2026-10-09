shader_type canvas_item;
render_mode blend_add, unshaded;
// Animated light on the baked pond: TEXTURE is the water mask. Slow swell plus moonlit glints
// that crawl along the surface rows.
uniform vec3 glint : source_color = vec3(0.45, 0.4, 0.6);
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void fragment() {
	float m = texture(TEXTURE, UV).a;
	vec2 p = floor(world);
	float swell = sin(p.x * 0.05 + p.y * 0.11 + TIME * 0.9) * 0.5 + 0.5;
	float row = floor(p.y / 3.0);
	float g = step(0.985, hash(vec2(floor(p.x / 4.0 + TIME * (0.6 + hash(vec2(row)))), row))) * step(mod(p.y, 3.0), 0.5);
	COLOR = vec4(glint * (g + swell * 0.06) * m, 1.0);
}
