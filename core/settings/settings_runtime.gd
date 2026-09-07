class_name SettingsRuntime
extends Node

signal view_preferences_applied(fov: float)

## Presentation preferences apply to each loaded scene, independently of gameplay.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_LIMITS: Array[int] = [0, 60, 90, 120]
var _player: PlayerController
var _last: Dictionary = {}
var _filter: ColorRect


func configure(player: PlayerController) -> void:
	_player = player
	_ensure_bus(&"Ambience")
	_ensure_bus(&"Effects")
	player.player_audio.audio_player.bus = &"Effects"
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_filter = ColorRect.new()
	_filter.name = "VCRFilter"
	_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/effects/vcr_filter.gdshader")
	_filter.material = material
	layer.add_child(_filter)
	Settings.changed.connect(apply_preferences)
	SceneRouter.travel_finished.connect(_on_room_changed)
	apply_preferences()


func apply_preferences() -> void:
	var first: bool = _last.is_empty()
	var data: Dictionary = Settings.to_data()
	_player.headbob_enabled = Settings.headbob
	_player.look_sensitivity_multiplier = Settings.mouse_sensitivity
	_player.invert_look_y = Settings.invert_y
	_player.camera.fov = Settings.fov
	_filter.visible = Settings.vcr_filter
	get_viewport().scaling_3d_scale = Settings.render_scale
	get_viewport().msaa_3d = Settings.msaa as Viewport.MSAA
	Engine.max_fps = FPS_LIMITS[Settings.fps_limit]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.vsync else DisplayServer.VSYNC_DISABLED)
		var launch_size: bool = first and "--resolution" in OS.get_cmdline_args()
		if not launch_size and (first or _last.get("window_mode") != Settings.window_mode or _last.get("resolution") != Settings.resolution):
			_apply_window()
	for pair: Array in [[&"Master", Settings.master_volume], [&"Ambience", Settings.ambience_volume], [&"Effects", Settings.effects_volume]]:
		var index: int = AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, float(pair[1]))))
		AudioServer.set_bus_mute(index, float(pair[1]) <= 0.0)
	if not Settings.developer_mode and GameState.mode == &"debug":
		GameState.set_mode(&"play")
	_apply_scene()
	_last = data
	view_preferences_applied.emit(Settings.fov)


func _apply_window() -> void:
	match Settings.window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(RESOLUTIONS[Settings.resolution])
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _on_room_changed(_id: StringName) -> void:
	_apply_scene()


func _apply_scene() -> void:
	var scope: Node = get_parent()
	for node: Node in scope.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = (node as WorldEnvironment).environment
		if environment != null:
			if not node.has_meta(&"settings_environment_owned"):
				environment = environment.duplicate(true) as Environment
				(node as WorldEnvironment).environment = environment
				node.set_meta(&"settings_environment_owned", true)
			for property: StringName in [&"ssao_enabled", &"ssil_enabled", &"glow_enabled"]:
				var tag: StringName = StringName("settings_original_" + String(property))
				if not node.has_meta(tag):
					node.set_meta(tag, environment.get(property))
				var allowed: bool = Settings.glow if property == &"glow_enabled" else Settings.ambient_occlusion
				environment.set(property, (bool(node.get_meta(tag)) if property == &"ssil_enabled" else true) and allowed)
	for node: Node in scope.find_children("*", "Light3D", true, false):
		var light: Light3D = node as Light3D
		if not light.has_meta(&"settings_original_shadow"):
			light.set_meta(&"settings_original_shadow", light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta(&"settings_original_shadow")) and Settings.shadows


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
