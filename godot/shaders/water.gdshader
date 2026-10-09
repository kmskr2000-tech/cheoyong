shader_type canvas_item;
// Dark pond: slow brightness swell and moonlit glints that crawl across the surface.
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = floor(world);
	float swell = sin(p.x * 0.05 + p.y * 0.11 + TIME * 0.9) * 0.5 + 0.5;
	c.rgb *= 0.9 + swell * 0.2;
	float row = floor(p.y / 3.0);
	float g = step(0.985, hash(vec2(floor(p.x / 4.0 + TIME * (0.6 + hash(vec2(row)) )), row)));
	c.rgb += g * vec3(0.35, 0.42, 0.55) * step(mod(p.y, 3.0), 0.5);
	COLOR = c;
}
