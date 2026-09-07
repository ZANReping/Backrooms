shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D tile_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 ground_tint : source_color = vec3(0.40, 0.41, 0.39);
uniform float meters_per_repeat = 2.8;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_world = world_position.xz / meters_per_repeat;
	vec3 tex = texture(tile_albedo, uv_world).rgb;
	vec3 neutral_tex = mix(vec3(dot(tex, vec3(0.3333))), tex, 0.28);
	ALBEDO = mix(ground_tint, ground_tint * neutral_tex * 1.65, 0.32);
	ROUGHNESS = mix(0.86, texture(tile_arm, uv_world).g, 0.38);
	NORMAL_MAP = texture(tile_normal, uv_world).xyz;
	NORMAL_MAP_DEPTH = 0.16;
}
