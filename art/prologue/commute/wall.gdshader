shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D plaster_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 wall_tint : source_color = vec3(0.62, 0.60, 0.55);
uniform float texture_strength : hint_range(0.0, 1.0) = 0.19;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.10;
uniform float meters_per_repeat = 2.3;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(6.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 coord = world_position / meters_per_repeat;
	vec3 sx = texture(plaster_albedo, coord.zy).rgb;
	vec3 sy = texture(plaster_albedo, coord.xz).rgb;
	vec3 sz = texture(plaster_albedo, coord.xy).rgb;
	vec3 sample_color = sx * weights.x + sy * weights.y + sz * weights.z;
	float fine = dot(sample_color, vec3(0.3333));
	ALBEDO = mix(wall_tint, wall_tint * mix(vec3(0.82), vec3(1.12), fine), texture_strength);
	float rx = texture(plaster_arm, coord.zy).g;
	float ry = texture(plaster_arm, coord.xz).g;
	float rz = texture(plaster_arm, coord.xy).g;
	ROUGHNESS = mix(0.78, rx * weights.x + ry * weights.y + rz * weights.z, 0.34);
	vec3 nx = texture(plaster_normal, coord.zy).xyz * 2.0 - 1.0;
	vec3 ny = texture(plaster_normal, coord.xz).xyz * 2.0 - 1.0;
	vec3 nz = texture(plaster_normal, coord.xy).xyz * 2.0 - 1.0;
	NORMAL_MAP = normalize(nx * weights.x + ny * weights.y + nz * weights.z) * vec3(normal_strength, normal_strength, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;
}
