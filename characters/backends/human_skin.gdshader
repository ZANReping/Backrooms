shader_type spatial;
render_mode cull_back;

uniform vec4 skin_color : source_color = vec4(0.75, 0.56, 0.44, 1.0);
uniform sampler2D skin_texture : source_color, filter_linear_mipmap;
uniform bool has_skin_texture = false;
uniform bool first_person = false;
uniform bool right_hand_only = false;
uniform bool covered_torso = true;
uniform bool covered_legs = true;
varying vec3 rest_position;
varying flat float body_region;
varying flat float hand_region;

void vertex() {
	rest_position = VERTEX;
	body_region = COLOR.r;
	hand_region = COLOR.g;
}

void fragment() {
	if (right_hand_only && hand_region < 0.5) { discard; }
	// The supplied wardrobe shares the neutral rig. Hide covered body regions
	// before shading; face and hands remain skin, without changing collision.
	if (first_person && body_region > 0.27 && body_region < 0.33) { discard; }
	if (covered_torso && body_region > 0.075 && body_region < 0.125) { discard; }
	if (covered_legs && body_region > 0.175 && body_region < 0.225) { discard; }
	if (body_region > 0.375) { discard; }
	vec3 pigment = has_skin_texture ? texture(skin_texture, UV).rgb / vec3(0.72, 0.48, 0.36) * skin_color.rgb : skin_color.rgb;
	ALBEDO = clamp(pigment, vec3(0.0), vec3(0.85));
	ROUGHNESS = 0.78;
	SPECULAR = 0.18;
	SSS_STRENGTH = 0.12;
}
