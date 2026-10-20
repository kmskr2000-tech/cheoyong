// Upright sprite facing the camera (HD-2D style). Feet sit on the node origin; casts a silhouette shadow.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D white : source_color, filter_linear_mipmap;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // uv x, y, w, h
uniform float flip = 0.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;
uniform float dark = 0.0;
global uniform vec4 sprite_tint;

varying float v_flip;
varying float v_alpha;

void vertex() {
	// spherical billboard keeping the model scale
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	v_flip = flip;
	v_alpha = alpha;
	if (INSTANCE_CUSTOM.a > 0.0) { // multimesh props: r = flip, g = alpha
		v_flip = INSTANCE_CUSTOM.r;
		v_alpha = INSTANCE_CUSTOM.g;
	}
}

void fragment() {
	vec2 uv = UV;
	if (v_flip > 0.5) uv.x = 1.0 - uv.x;
	uv = region.xy + uv * region.zw;
	vec4 c = texture(tex, uv);
	vec3 col = c.rgb * mix(vec3(1.0), vec3(0.55, 0.42, 0.7), dark) * sprite_tint.rgb;
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0) * texture(white, uv).a);
	ALBEDO = col;
	// partial alpha (blink, fade) as an ordered dither so the sprite stays depth-sorted and keeps its shadow
	float bayer = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) + 0.125 * mod(floor(FRAGCOORD.y), 2.0));
	if (v_alpha < 0.999 && v_alpha <= bayer) discard;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}
