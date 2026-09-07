extends Node3D

var checks: int = 0
var failures: int = 0
var phone: HandheldPhone
var app_received: StringName = &""

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = get_tree().root.get_node("GameState")
	game_state.call("set_mode", &"phone")
	phone = HandheldPhone.new()
	add_child(phone)
	phone.configure(camera)
	phone.view.app_requested.connect(func(id: StringName) -> void: app_received = id)
	var state := PhoneState.new()
	var charge := ChargeState.new()
	charge.current = 72.0
	charge.maximum = 100.0
	var profile := CharacterProfile.new()
	profile.appearance_preset["skin"] = 4
	phone.show_phone(state, charge, profile)
	await get_tree().create_timer(0.3).timeout

	_check(phone.visible and phone.get_parent() == camera, "physical phone is parented under the configured player camera")
	_check(phone.view != null and phone.camera_viewport != null, "screen UI and independent capture viewport exist")
	_check(phone.camera_viewport.size == Vector2i(640, 480), "capture viewport uses 640x480")
	_check(phone.get_node("PhoneScreenViewport").size == Vector2i(360, 640), "physical screen viewport uses 360x640")
	_check(is_equal_approx(camera.fov, 36.0), "open transition narrows main camera FOV for readable phone text")
	_check(phone.position.distance_to(Vector3(0.05, -0.012, -0.29)) < 0.002, "open transition settles phone in front of camera with safe framing")
	_check(_all_geometry_on_phone_layer(phone), "phone model, UI screen and holding hand use dedicated layer 20")

	phone.view.call("_show_home")
	await _frames(3)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://artifacts/phone_modern")
		await RenderingServer.frame_post_draw
		(phone.get_node("PhoneScreenViewport") as SubViewport).get_texture().get_image().save_webp("res://artifacts/phone_modern/home_screen_native.webp")
	var home_app := _find_button_with_tooltip(phone.view, tr(&"PHONE_APP_CHAT"))
	_check(home_app != null, "home screen exposes a live app button")
	if home_app != null:
		await _click_screen_pixel(home_app.get_global_rect().get_center())
		await _frames(3)
	_check(app_received == &"chat", "real root-viewport mouse click reaches the 3D phone screen and opens Chat")
	var colleague_thread := _find_button_with_tooltip(phone.view, tr(&"PHONE_CHAT_COLLEAGUE"))
	_check(colleague_thread != null, "Chat opens on a conversation list with a selectable recipient")
	if colleague_thread != null:
		await _click_screen_pixel(colleague_thread.get_global_rect().get_center())
		await _frames(3)

	var input := _find_named(phone.view, "MessageInput") as TextEdit
	_check(input != null, "Chat page exposes the free-text editor")
	if input != null:
		await _click_screen_pixel(input.get_global_rect().get_center())
		await _type_character("A")
		await _frames(2)
		_check(input.text == "A", "keyboard text follows phone focus through SubViewport.push_input")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			(phone.get_node("PhoneScreenViewport") as SubViewport).get_texture().get_image().save_webp("res://artifacts/phone_modern/chat_screen_native.webp")
	if DisplayServer.get_name() != "headless":
		state.offline = true
		state.changed.emit()
		phone.view.call("_show_maps")
		await _frames(2)
		await _save_native_phone_screen("maps_offline_screen_native.webp")
		phone.view.call("_show_browser_page", &"weather")
		await _frames(2)
		await _save_native_phone_screen("browser_detail_screen_native.webp")
		phone.view.show_registration()
		await _frames(2)
		await _save_native_phone_screen("registration_screen_native.webp")
		state.offline = false
		phone.view.call("_show_chat_detail", &"lin_qian")
	charge.current = 0.0
	await get_tree().create_timer(0.3).timeout
	var chat_send := phone.view.get("_chat_send") as Button
	_check(chat_send != null and chat_send.disabled, "quarter-second polling disables Chat send after charge drains without a signal")

	phone.view.call("_show_app", &"camera")
	var shutter := phone.view.get("_camera_capture") as Button
	_check(shutter != null and shutter.disabled, "empty charge also disables the camera shutter")
	charge.current = 72.0
	await get_tree().create_timer(0.3).timeout
	_check(not shutter.disabled, "quarter-second polling re-enables cached actions without rebuilding the page")
	if DisplayServer.get_name() != "headless":
		var capture: Image = await phone.capture_image()
		_check(capture != null and capture.get_size() == Vector2i(640, 480), "immediate camera-page capture waits for and returns the actual 640x480 frame")
		_check(capture != null and not _is_black(capture), "immediate capture contains rendered world pixels")
		var landscape: Image = await phone.capture_image(Vector2i(1280, 720))
		_check(landscape != null and landscape.get_width() > landscape.get_height(), "full-screen camera capture uses a landscape target")
		var capture_camera := phone.camera_viewport.get_node("CaptureCamera") as Camera3D
		_check(phone.camera_viewport.find_children("*", "Control", true, false).is_empty() and capture_camera.cull_mask == 1, "camera capture viewport excludes phone and overlay UI")
	else:
		print("SKIP: rendered phone image assertions require a graphical display")
	phone.view.open_app(&"workspace")
	await _frames(3)
	if DisplayServer.get_name() != "headless":
		_save_screenshot()

	phone.hide_phone()
	await get_tree().create_timer(0.3).timeout
	_check(not phone.visible and is_equal_approx(camera.fov, 75.0), "hide transition restores original FOV and hides physical model")
	var draft := CharacterAppearance.new()
	draft.face_morphs[&"nose_width"] = 0.42
	phone.view.set_appearance_data(draft.to_data())
	phone.view.bind_state(state, charge, profile)
	_check(is_equal_approx(phone.view.get_appearance_data()["face_morphs"][&"nose_width"], 0.42), "same phone session retains creator draft")
	phone.view.bind_state(PhoneState.new(), charge, CharacterProfile.new())
	_check(not phone.view.get_appearance_data()["face_morphs"].has(&"nose_width"), "new run clears the previous registration appearance draft")
	phone.queue_free()
	await _frames(2)
	print("HANDHELD_PHONE_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _click_screen_pixel(pixel: Vector2) -> void:
	var screen := phone.get_node("InteractiveScreen") as MeshInstance3D
	var screen_size := HandheldPhone.SCREEN_SIZE
	var local := Vector3(
		(pixel.x / 360.0 - 0.5) * screen_size.x,
		(0.5 - pixel.y / 640.0) * screen_size.y,
		0.0
	)
	var viewport_position: Vector2 = camera.unproject_position(screen.to_global(local))
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = viewport_position
		event.global_position = viewport_position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


func _type_character(character: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_A
		event.physical_keycode = KEY_A
		event.unicode = character.unicode_at(0) if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


func _all_geometry_on_phone_layer(root: Node) -> bool:
	for child: Node in root.get_children():
		var geometry := child as GeometryInstance3D
		if geometry != null and geometry.layers != (1 << 19):
			return false
		if not _all_geometry_on_phone_layer(child):
			return false
	return true


func _is_black(image: Image) -> bool:
	for y: int in range(0, image.get_height(), 48):
		for x: int in range(0, image.get_width(), 64):
			var color: Color = image.get_pixel(x, y)
			if color.r > 0.02 or color.g > 0.02 or color.b > 0.02:
				return false
	return true


func _find_button_with_prefix(root: Node, prefix: String) -> Button:
	for child: Node in root.get_children():
		var button := child as Button
		if button != null and button.text.begins_with(prefix):
			return button
		var nested: Button = _find_button_with_prefix(child, prefix)
		if nested != null:
			return nested
	return null


func _find_button_with_tooltip(root: Node, tooltip: String) -> Button:
	for child: Node in root.get_children():
		var button := child as Button
		if button != null and button.tooltip_text == tooltip:
			return button
		var nested: Button = _find_button_with_tooltip(child, tooltip)
		if nested != null:
			return nested
	return null


func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named(child, node_name)
		if found != null:
			return found
	return null


func _save_screenshot() -> void:
	var directory: String = ProjectSettings.globalize_path("res://artifacts/handheld_phone")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_webp(directory.path_join("handheld_phone.webp"), true, 0.9)
	_check(error == OK, "graphical phone screenshot saved")


func _save_native_phone_screen(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := (phone.get_node("PhoneScreenViewport") as SubViewport).get_texture().get_image()
	var error := image.save_webp("res://artifacts/phone_modern/" + file_name)
	_check(error == OK, "%s saved" % file_name)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
