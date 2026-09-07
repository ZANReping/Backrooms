shader_type spatial;

// World-scale surface relief with restrained color contrast. Photographic PBR
// inputs are reusable; individual rooms choose pigment and physical repeat.
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 pigment : source_color = vec4(0.82, 0.80, 0.72, 1.0);
uniform float texture_amount : hint_range(0.0, 1.0) = 0.2;
uniform float repeats_per_meter = 1.0;
uniform float relief : hint_range(0.0, 1.0) = 0.1;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.86;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(8.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 position = world_position * repeats_per_meter;
	vec3 tex = texture(surface_color, position.zy).rgb * weights.x;
	tex += texture(surface_color, position.xz).rgb * weights.y;
	tex += texture(surface_color, position.xy).rgb * weights.z;
	float lightness = sqrt(max(dot(tex, vec3(0.2126, 0.7152, 0.0722)), 0.0001));
	ALBEDO = pigment.rgb * mix(1.0, clamp(lightness * 1.7, 0.15, 1.35), texture_amount);
	vec2 plane_uv = weights.y > 0.5 ? position.xz : (weights.x > 0.5 ? position.zy : position.xy);
	NORMAL_MAP = texture(surface_normal, plane_uv).rgb;
	NORMAL_MAP_DEPTH = relief;
	vec3 arm = texture(surface_arm, plane_uv).rgb;
	ROUGHNESS = clamp(roughness_base * mix(0.9, 1.1, arm.g), 0.55, 1.0);
	AO = mix(1.0, arm.r, 0.20);
}
