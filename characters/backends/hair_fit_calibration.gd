class_name HairFitCalibration
extends RefCounted

## MakeHuman hair exports do not share an origin. These transforms were measured
## from the scalp contact band (temples, forehead roots and occipital roots), not
## from the loose-hair AABB extrema.
const ASSETS: Dictionary[StringName, String] = {
	&"short": "short01", &"crop": "short01", &"bob": "bob01", &"tied": "ponytail01",
}
const BASE_SCALE: Dictionary[StringName, Vector3] = {
	&"short": Vector3(0.112, 0.120, 0.140),
	&"crop": Vector3(0.110, 0.118, 0.135),
	&"bob": Vector3(0.100, 0.100, 0.100),
	&"tied": Vector3(0.105, 0.104, 0.120),
}
const MODEL_ORIGIN: Dictionary[StringName, Vector3] = {
	# Depth and crown expansion pivot around the authored forehead-root contact,
	# preserving the hairline while carrying the shell over the actual occiput.
	&"short": Vector3(0.0002, 0.598, -0.0745),
	&"crop": Vector3(0.0002, 0.610, -0.0705),
	&"bob": Vector3(0.0084, 0.889, -0.003),
	&"tied": Vector3(0.0010, 0.873, -0.0193),
}


static func asset_for(id: StringName) -> String:
	return ASSETS.get(id, "short01")


static func source_to_model(id: StringName, appearance: CharacterAppearance) -> Transform3D:
	var base: Vector3 = BASE_SCALE.get(id, BASE_SCALE[&"short"])
	var eye_width: float = clampf(float(appearance.face_morphs.get(&"eye_distance", 0.0)), -1.0, 1.0)
	var cheek_width: float = clampf(float(appearance.face_morphs.get(&"cheek_size", 0.0)), -1.0, 1.0)
	var head_depth: float = clampf(float(appearance.face_morphs.get(&"chin_length", 0.0)), -1.0, 1.0)
	var width_fit: float = 1.0 + eye_width * 0.015 + cheek_width * 0.025
	var depth_fit: float = 1.0 + head_depth * 0.025 + cheek_width * 0.008
	var fitted_scale := Vector3(base.x * width_fit, base.y, base.z * depth_fit)
	return Transform3D(Basis.IDENTITY.scaled(fitted_scale), MODEL_ORIGIN.get(id, MODEL_ORIGIN[&"short"]))
