class_name PreferenceSchema
extends RefCounted

const DEFAULTS: Dictionary[StringName, Variant] = {
	&"immersive_hud": true, &"headbob": true, &"developer_mode": false,
	&"dynamic_crosshair": true, &"resolution": 3, &"window_mode": 0,
	&"shadows": true, &"ambient_occlusion": true, &"glow": true,
	&"vsync": true, &"fps_limit": 1, &"render_scale": 1.0, &"msaa": 1,
	&"vcr_filter": false, &"master_volume": 1.0, &"ambience_volume": 1.0,
	&"effects_volume": 1.0, &"mouse_sensitivity": 1.0, &"invert_y": false, &"fov": 75.0,
}
const RANGES: Dictionary[StringName, Vector2] = {
	&"resolution": Vector2(0, 3), &"window_mode": Vector2(0, 2),
	&"fps_limit": Vector2(0, 3), &"msaa": Vector2(0, 2),
	&"render_scale": Vector2(0.5, 1.0), &"master_volume": Vector2(0, 1),
	&"ambience_volume": Vector2(0, 1), &"effects_volume": Vector2(0, 1),
	&"mouse_sensitivity": Vector2(0.3, 2.0), &"fov": Vector2(65, 100),
}


static func valid_value(key: StringName, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	var expected: int = typeof(DEFAULTS[key])
	if expected == TYPE_BOOL:
		return value is bool
	if expected == TYPE_INT and not value is int:
		return false
	if expected == TYPE_FLOAT and not (value is float or value is int):
		return false
	var bounds: Vector2 = RANGES[key]
	return is_finite(float(value)) and float(value) >= bounds.x and float(value) <= bounds.y

