shader_type canvas_item;
// HD-2D finishing pass over the whole screen (one full-rect ColorRect on a top CanvasLayer):
// tilt-shift depth of field, bloom, split-tone colour grade, top haze, aerial perspective and vignette.
// Blur comes from the screen texture's mipmaps, so it is cheap enough for phones.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float tilt = 0.4;            // depth-of-field strength (0 = off)
uniform float focus_y = 0.56;        // screen height that stays sharp (the hero's row)
uniform float bloom = 0.9;
uniform float bloom_threshold = 0.32;
uniform vec3 shadow_tint : source_color = vec3(0.02, 0.05, 0.14);
uniform vec3 high_tint : source_color = vec3(0.72, 0.86, 1.0);
uniform float grade = 0.4;
uniform vec3 haze : source_color = vec3(0.16, 0.26, 0.48);
uniform float haze_amount = 0.38;
uniform float vignette = 0.6;
uniform float depth_fade = 0.22;     // the far (top) ground sinks back: darker, flatter — the camera looks down at an angle

vec3 bright(vec3 c) { return max(c - bloom_threshold, vec3(0.0)) / (1.0 - bloom_threshold); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = abs(uv.y - focus_y);
	float lod = smoothstep(0.26, 0.6, d) * 2.0 * tilt;
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	// bloom: wide soft halo from two blurred mip levels
	vec3 b = bright(textureLod(screen_tex, uv, 2.5).rgb) * 0.6 + bright(textureLod(screen_tex, uv, 4.0).rgb) * 0.9;
	c += b * bloom;
	// split-tone grade: shadows sink into deep navy, highlights go pale moon-silver
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 toned = mix(shadow_tint, high_tint, smoothstep(0.0, 0.9, l)) * (0.35 + l * 1.4);
	// saturated colours (lantern fire, ghost-fires, talismans) keep their hue against the grade
	float sat = (max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b))) / max(max(c.r, max(c.g, c.b)), 0.001);
	c = mix(c, toned, grade * (1.0 - smoothstep(0.25, 0.7, sat) * 0.85));
	// haze thickening toward the top of the screen (distance), lifted blacks
	float h = smoothstep(0.75, 0.0, uv.y) * haze_amount;
	c = mix(c, haze * (0.35 + l), h * 0.6) + haze * h * 0.12;
	// aerial perspective: the far rows lose contrast and light, the near rows keep it
	float far = 1.0 - smoothstep(0.0, 0.62, uv.y);
	c = mix(c, vec3(l) * 0.6 + haze * 0.25, far * depth_fade * 0.5) * (1.0 - far * depth_fade);
	// vignette
	vec2 v = (uv - vec2(0.5, 0.5)) * vec2(1.0, 0.8);
	c *= 1.0 - smoothstep(0.3, 0.8, length(v)) * vignette;
	COLOR = vec4(c, 1.0);
}
