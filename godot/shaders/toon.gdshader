// Cel-shaded 3D model (characters and props from GLB). Same per-draw controls as billboard.gdshader:
// flash (hit white), alpha (ordered dither), dark (cursed purple), tint (recolour), global sprite_tint (zone mood).
shader_type spatial;
render_mode depth_draw_opaque, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;
uniform float dark = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
global uniform vec4 sprite_tint;

void fragment() {
	vec3 c = albedo.rgb * texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	float amt = 0.5 * (1.0 - step(2.995, tint.r + tint.g + tint.b));
	c = mix(c, lum * tint.rgb * 1.6, amt);
	c *= mix(vec3(1.0), vec3(0.6, 0.48, 0.75), dark) * sprite_tint.rgb;
	float fa = clamp(flash, 0.0, 1.0);
	ALBEDO = mix(c, vec3(1.0), fa);
	EMISSION = emission.rgb * emission_energy + c * 0.06 + vec3(fa);
	float bayer = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) + 0.125 * mod(floor(FRAGCOORD.y), 2.0));
	if (alpha < 0.999 && alpha <= bayer) discard;
}

// two-band cel light: lit / half / shade, with the shadow map folded into the bands
void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = smoothstep(0.0, 0.04, ndl) * 0.55 + smoothstep(0.45, 0.49, ndl) * 0.45;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * band * 0.55;
	// thin rim on the side away from the camera light, sells the 3D form against the ground
	float rim = smoothstep(0.62, 0.7, 1.0 - dot(NORMAL, VIEW)) * smoothstep(-0.1, 0.2, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * rim * 0.15;
}
