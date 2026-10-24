// Film grade over the whole game view (3D world, sprites, glows, light pass), under the UI.
// Filmic contrast, restrained saturation, split toning (cool shadows, warm highlights), vignette and grain.
// view3d.set_mood() eases the uniforms per zone so dread places read darker and colder.
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float exposure = 1.0;
uniform float contrast = 1.12;
uniform float saturation = 0.8;
uniform vec3 shadow_tint = vec3(0.86, 0.92, 1.12);
uniform vec3 highlight_tint = vec3(1.06, 1.0, 0.9);
uniform float vignette = 0.38;
uniform float grain = 0.035;
uniform float time = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb * exposure;
	// filmic S-curve around mid grey
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
	c = c * c * (3.0 - 2.0 * c) * 0.35 + c * 0.65;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	// split toning by luminance
	vec3 tone = mix(shadow_tint, highlight_tint, smoothstep(0.15, 0.75, l));
	c *= tone;
	// vignette (aspect aware)
	vec2 q = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	c *= 1.0 - vignette * smoothstep(0.35, 0.95, length(q));
	// fine animated grain, stronger in the darks like film
	float n = hash(FRAGCOORD.xy + fract(time) * 97.0) - 0.5;
	c += n * grain * (1.2 - l);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
