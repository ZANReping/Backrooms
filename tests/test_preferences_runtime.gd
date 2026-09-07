extends Node

const OUTPUT := "res://artifacts/preferences"
const SHOT_NAMES: Array[String] = ["game", "display_basic", "display_light", "display_performance", "display_atmosphere", "audio", "controls"]

var app: PrologueApplication
var checks := 0
var failures := 0
var graphical := false
var _old_settings: Dictionary
var _old_storage_path: String


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	Input.use_accumulated_input = false
	graphical = DisplayServer.get_name() != "headless"
	_old_settings = Settings.to_data().duplicate(true)
	_old_storage_path = Settings.storage_path
	Settings.storage_path = OUTPUT + "/runtime.cfg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Settings.reset_defaults()
	Settings.set_value(&"fps_limit", 0)

	app = (load("res://core/prologue/main.tscn") as PackedScene).instantiate() as PrologueApplication
	add_child(app)
	await _wait_for_route()
	_check(await app.new_game(0), "fresh main scene starts")
	await _frames(5)
	# Let the startup phone-hide camera tween settle before measuring persistent FOV.
	await get_tree().create_timer(0.5).timeout
	_check(GameState.mode == &"play", "session enters play")

	# Developer mode gates the actual F1 input and closes debug when disabled.
	_tap(KEY_F1)
	await _frames(2)
	_check(GameState.mode == &"play", "F1 is ignored while developer mode is disabled")
	_check(Settings.set_value(&"developer_mode", true), "developer mode accepts valid value")
	_tap(KEY_F1)
	await _frames(2)
	_check(GameState.mode == &"debug", "F1 opens debug when developer mode is enabled")
	Settings.set_value(&"developer_mode", false)
	await _frames(2)
	_check(GameState.mode == &"play", "disabling developer mode exits debug")

	# Player and renderer/audio runtime application.
	Settings.set_value(&"headbob", false)
	Settings.set_value(&"invert_y", true)
	Settings.set_value(&"mouse_sensitivity", 1.6)
	Settings.set_value(&"fov", 92.0)
	Settings.set_value(&"render_scale", 0.75)
	Settings.set_value(&"msaa", 2)
	Settings.set_value(&"fps_limit", 2)
	Settings.set_value(&"master_volume", 0.0)
	Settings.set_value(&"ambience_volume", 0.4)
	Settings.set_value(&"effects_volume", 0.7)
	await _frames(3)
	_check(not app.player.headbob_enabled and app.player.invert_look_y, "headbob and invert Y reach player")
	_check(is_equal_approx(app.player.look_sensitivity_multiplier, 1.6), "sensitivity reaches player (actual %.2f)" % app.player.look_sensitivity_multiplier)
	_check(is_equal_approx(app.player.camera.fov, 92.0), "FOV reaches player (actual %.2f)" % app.player.camera.fov)
	_check(is_equal_approx(get_viewport().scaling_3d_scale, 0.75) and get_viewport().msaa_3d == Viewport.MSAA_4X, "render scale and MSAA reach viewport")
	_check(Engine.max_fps == 90, "FPS limit reaches engine")
	var master := AudioServer.get_bus_index(&"Master")
	var ambience := AudioServer.get_bus_index(&"Ambience")
	var effects := AudioServer.get_bus_index(&"Effects")
	_check(AudioServer.is_bus_mute(master), "zero master volume mutes bus")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(ambience)) - 0.4) < 0.002, "ambience volume reaches bus")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(effects)) - 0.7) < 0.002, "effects volume reaches bus")

	# A FOV change made while the phone owns the camera must become the new world baseline.
	var phone: ItemInstance = app.director.find_item(&"phone")
	_check(phone != null, "phone exists for FOV transition check")
	if phone != null:
		app._pickup(phone.uid)
		app.show_phone(phone.uid)
		await get_tree().create_timer(0.25).timeout
		_check(GameState.mode == &"phone", "phone display owns the camera")
		Settings.set_value(&"fov", 88.0)
		app._resume()
		await get_tree().create_timer(0.3).timeout
		_check(GameState.mode == &"play" and is_equal_approx(app.player.camera.fov, 88.0), "phone hide preserves FOV changed during display")
		Settings.set_value(&"fov", 92.0)

	# Persistence is written by real set_value calls.
	var config := ConfigFile.new()
	_check(config.load(Settings.storage_path) == OK, "preferences ConfigFile persists")
	_check(config.get_value("preferences", "fov", 0.0) == 92.0 and config.get_value("preferences", "developer_mode", true) == false, "persisted values match runtime")

	# Backward compatibility and atomic rejection.
	_check(Settings.load_data({"immersive_hud": false, "headbob": false}), "legacy two-key data loads")
	_check(not Settings.immersive_hud and not Settings.headbob and Settings.fov == Settings.DEFAULTS[&"fov"], "legacy data receives new defaults")
	var before_bad := Settings.to_data().duplicate(true)
	var bad := before_bad.duplicate(true)
	bad["fov"] = 400.0
	_check(not Settings.load_data(bad), "invalid data is rejected")
	_check(Settings.to_data() == before_bad, "invalid data does not partially mutate settings")

	# Open the real pause settings page and inspect the embedded component.
	_tap(KEY_ESCAPE)
	await _frames(2)
	var settings_button := _visible_button(tr(&"PROLOGUE_SETTINGS"))
	_check(settings_button != null, "pause exposes settings")
	if settings_button != null:
		settings_button.pressed.emit()
	await _frames(3)
	var view: SettingsView = app.shell._settings_views.back()
	_check(view != null and view.is_visible_in_tree(), "pause embeds SettingsView")
	_check(view._category_pages.size() == 4 and view._display_pages.size() == 4, "four categories and four graphics pages exist")
	var crosshair_toggle := view.find_child("dynamic_crosshair", true, false) as BaseButton
	crosshair_toggle.set_pressed_no_signal(false)
	crosshair_toggle.toggled.emit(false)
	await _frames(2)
	_check(not Settings.dynamic_crosshair, "real settings toggle reaches Settings through shell")
	await _review_pages(view)

	# Real restore signal travels through shell into Settings.
	Settings.set_value(&"fov", 99.0)
	view.restore_requested.emit()
	await _frames(2)
	_check(Settings.to_data() == _string_defaults(), "restore request resets all defaults")

	# Restore process-local state without writing the user's preference file.
	Settings.storage_path = ""
	Settings.load_data(_old_settings)
	Settings.storage_path = _old_storage_path
	Engine.max_fps = 0
	print("PREFERENCES_RUNTIME: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _review_pages(view: SettingsView) -> void:
	for category: int in 4:
		view._show_category(category)
		await _frames(2)
		_check(view._category_pages[category].visible, "category %d can be selected" % category)
		_check(await _controls_reachable(view, view._category_pages[category]), "category %d controls are visible or scroll reachable" % category)
	if graphical:
		await _capture_set(view, Vector2i(1920, 1080), "1080")
		await _capture_set(view, Vector2i(960, 540), "960")
		await _verify_performance_bottom(view)


func _verify_performance_bottom(view: SettingsView) -> void:
	view._show_category(1)
	view._show_display_page(2)
	await _frames(4)
	var scroll := view._category_pages[1] as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(4)
	var msaa := view.find_child("msaa", true, false) as OptionButton
	var back := _visible_button(tr(&"PROLOGUE_BACK"))
	_check(scroll.get_global_rect().encloses(msaa.get_global_rect()), "MSAA full click area is reachable at performance bottom")
	_check(back == null or not msaa.get_global_rect().intersects(back.get_global_rect()), "MSAA does not overlap the Back button")
	await RenderingServer.frame_post_draw
	var path := OUTPUT + "/display_performance_bottom_960.webp"
	_check(get_viewport().get_texture().get_image().save_webp(path, true, 0.88) == OK, "saved " + path)


func _controls_reachable(view: SettingsView, scroll: ScrollContainer) -> bool:
	var original := scroll.scroll_vertical
	for control: Control in view._controls.values():
		if not scroll.is_ancestor_of(control) or not control.is_visible_in_tree():
			continue
		var local_y := control.global_position.y - scroll.global_position.y + scroll.scroll_vertical
		scroll.scroll_vertical = maxi(0, int(local_y - 24.0))
		await get_tree().process_frame
		if not control.get_global_rect().intersects(scroll.get_global_rect()):
			scroll.scroll_vertical = original
			return false
	scroll.scroll_vertical = original
	return true


func _capture_set(view: SettingsView, size_value: Vector2i, suffix: String) -> void:
	get_tree().root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_size(size_value)
	await _frames(5)
	for index: int in 7:
		if index == 0:
			view._show_category(0)
		elif index in [1, 2, 3, 4]:
			view._show_category(1)
			view._show_display_page(index - 1)
		else:
			view._show_category(index - 3)
		await _frames(3)
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.webp" % [OUTPUT, SHOT_NAMES[index], suffix]
		_check(get_viewport().get_texture().get_image().save_webp(path, true, 0.88) == OK, "saved " + path)


func _string_defaults() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in Settings.DEFAULTS:
		result[String(key)] = Settings.DEFAULTS[key]
	return result


func _visible_button(text_value: String) -> Button:
	for node: Node in app.shell.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text_value and button.is_visible_in_tree():
			return button
	return null


func _tap(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _wait_for_route() -> void:
	await _frames(20)
	while SceneRouter.busy or SceneRouter.current_room == null:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
