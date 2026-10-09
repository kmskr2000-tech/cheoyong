shader_type canvas_item;
// HD-2D finishing pass over the whole screen (one full-rect ColorRect on a top CanvasLayer):
// tilt-shift depth of field, bloom, split-tone colour grade, top haze and vignette.
// Blur comes from the screen texture's mipmaps, so it is cheap enough for phones.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float tilt = 0.55;           // depth-of-field strength (0 = off)
uniform float focus_y = 0.56;        // screen height that stays sharp (the hero's row)
uniform float bloom = 0.9;
uniform float bloom_threshold = 0.32;
uniform vec3 shadow_tint : source_color = vec3(0.16, 0.03, 0.10);
uniform vec3 high_tint : source_color = vec3(1.0, 0.62, 0.55);
uniform float grade = 0.4;
uniform vec3 haze : source_color = vec3(0.55, 0.12, 0.2);
uniform float haze_amount = 0.38;
uniform float vignette = 0.6;

vec3 bright(vec3 c) { return max(c - bloom_threshold, vec3(0.0)) / (1.0 - bloom_threshold); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = abs(uv.y - focus_y);
	float lod = smoothstep(0.26, 0.6, d) * 2.0 * tilt;
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	// bloom: wide soft halo from two blurred mip levels
	vec3 b = bright(textureLod(screen_tex, uv, 2.5).rgb) * 0.6 + bright(textureLod(screen_tex, uv, 4.0).rgb) * 0.9;
	c += b * bloom;
	// split-tone grade: shadows sink into crimson-violet, highlights warm toward rose gold
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 toned = mix(shadow_tint, high_tint, smoothstep(0.0, 0.9, l)) * (0.35 + l * 1.4);
	c = mix(c, toned, grade);
	// haze thickening toward the top of the screen (distance), lifted blacks
	float h = smoothstep(0.75, 0.0, uv.y) * haze_amount;
	c = mix(c, haze * (0.35 + l), h * 0.6) + haze * h * 0.12;
	// vignette
	vec2 v = (uv - vec2(0.5, 0.5)) * vec2(1.0, 0.8);
	c *= 1.0 - smoothstep(0.3, 0.8, length(v)) * vignette;
	COLOR = vec4(c, 1.0);
}
