extends Node

signal changed()

const DEFAULTS = PreferenceSchema.DEFAULTS

var immersive_hud: bool = true
var headbob: bool = true
var developer_mode: bool = false
var dynamic_crosshair: bool = true
var resolution: int = 3
var window_mode: int = 0
var shadows: bool = true
var ambient_occlusion: bool = true
var glow: bool = true
var vsync: bool = true
var fps_limit: int = 1
var render_scale: float = 1.0
var msaa: int = 1
var vcr_filter: bool = false
var master_volume: float = 1.0
var ambience_volume: float = 1.0
var effects_volume: float = 1.0
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var fov: float = 75.0
var storage_path: String = "user://preferences.cfg"


func _ready() -> void:
	# Portable profiles and test callers can isolate user preferences.
	if OS.has_environment("BACKROOMS_PREFERENCES_PATH"):
		storage_path = OS.get_environment("BACKROOMS_PREFERENCES_PATH")
	var config := ConfigFile.new()
	if not storage_path.is_empty() and config.load(storage_path) == OK:
		var data: Dictionary = {}
		for key: StringName in DEFAULTS:
			data[String(key)] = config.get_value("preferences", String(key), DEFAULTS[key])
		load_data(data)


func apply(immersive: bool, bob: bool) -> void:
	immersive_hud = immersive
	headbob = bob
	_commit()


func set_value(key: StringName, value: Variant) -> bool:
	if not valid_value(key, value):
		return false
	if get(key) == value:
		return true
	set(key, value)
	_commit()
	return true


func reset_defaults() -> void:
	for key: StringName in DEFAULTS:
		set(key, DEFAULTS[key])
	_commit()


func to_data() -> Dictionary:
	var data: Dictionary = {}
	for key: StringName in DEFAULTS:
		data[String(key)] = get(key)
	return data


func load_data(data: Dictionary) -> bool:
	if not data.get("immersive_hud") is bool or not data.get("headbob") is bool:
		return false
	for key: StringName in DEFAULTS:
		if data.has(String(key)) and not valid_value(key, data[String(key)]):
			return false
	for key: StringName in DEFAULTS:
		set(key, data.get(String(key), DEFAULTS[key]))
	changed.emit()
	return true


func valid_value(key: StringName, value: Variant) -> bool:
	return PreferenceSchema.valid_value(key, value)


func _commit() -> void:
	changed.emit()
	if storage_path.is_empty():
		return
	var config := ConfigFile.new()
	for key: StringName in DEFAULTS:
		config.set_value("preferences", String(key), get(key))
	var error: Error = config.save(storage_path)
	if error != OK:
		push_warning("Could not save preferences: %s" % error_string(error))
