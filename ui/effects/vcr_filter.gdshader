shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 uv = SCREEN_UV;
	float drift = sin(uv.y * 42.0 + TIME * 1.7) * 0.00018;
	float noise = fract(sin(dot(uv * vec2(1920.0, 1080.0), vec2(12.9898,78.233)) + floor(TIME * 24.0)) * 43758.5453);
	vec3 base = texture(screen_image, uv + vec2(drift, 0.0)).rgb;
	base.r = mix(base.r, texture(screen_image, uv + vec2(0.00065 + drift, 0.0)).r, 0.45);
	base.b = mix(base.b, texture(screen_image, uv - vec2(0.00065 - drift, 0.0)).b, 0.45);
	float scan = 1.0 - 0.025 * (0.5 + 0.5 * sin(uv.y * 1080.0 * 3.14159));
	COLOR = vec4(base * scan + (noise - 0.5) * 0.025, 1.0);
}
