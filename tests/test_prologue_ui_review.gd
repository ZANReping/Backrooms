extends Node

var app: PrologueApplication
var checks := 0
var failures := 0
var output_dir := "res://artifacts/ui_review"


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	Input.use_accumulated_input = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	SaveService.save_path = output_dir + "/review.save"
	app = (load("res://core/prologue/main.tscn") as PackedScene).instantiate() as PrologueApplication
	add_child(app)
	app.photos.base_path = output_dir + "/photos"
	SaveService.photo_storage = app.photos
	await _wait_for_route()
	_check(await app.new_game(0), "fresh prologue session starts")
	await _frames(5)

	# Exercise the real input dispatch path: pause, enter settings, back to pause home, resume.
	_tap_key(KEY_ESCAPE)
	await _frames(3)
	_check(GameState.mode == &"pause", "Escape opens pause")
	var settings_button := _visible_button(tr(&"PROLOGUE_SETTINGS"))
	_check(settings_button != null, "pause settings button is visible")
	if settings_button != null:
		settings_button.pressed.emit()
	await _frames(2)
	_check(app.shell._pause_pages[&"settings"].get_parent().visible, "settings page opens")
	_tap_key(KEY_ESCAPE)
	await _frames(2)
	_check(GameState.mode == &"pause" and app.shell._pause_pages[&"home"].get_parent().visible, "Escape returns settings to pause home")
	_tap_key(KEY_ESCAPE)
	await _frames(3)
	_check(GameState.mode == &"play", "second Escape resumes play")

	# Enter the real phone-owned creator flow without relying on a completed save.
	var phone: ItemInstance = app.director.find_item(&"phone")
	_check(phone != null, "session phone exists")
	if phone != null:
		app._pickup(phone.uid)
		app.show_phone(phone.uid)
		app.handheld.view.show_registration()
		app.handheld.view.appearance_edit_requested.emit()
	await _frames(12)
	var creator := app.appearance_creator
	_check(creator != null and creator.visible and GameState.mode == &"appearance", "real phone opens creator")
	if creator != null:
		await _resize_960()
		await _review_creator(creator)

	print("PROLOGUE_UI_REVIEW: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _review_creator(creator: CharacterCreator) -> void:
	creator._show_page(0)
	await _frames(4)
	_check(creator._pages[0].visible and creator._tab_buttons[0].button_pressed, "basics tab is selected")
	_check(_actions_inside(creator), "creator actions fit 960x540")
	await _shot("creator_960_basics")

	creator._show_page(1)
	await _frames(4)
	_check(not creator._full_body and creator._pages[1].visible, "face tab selects close view")
	await _shot("creator_960_face")
	var scroll := creator._pages[1] as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	_check(bar.max_value > bar.page, "long face page exposes a real scroll range")
	scroll.scroll_vertical = int(bar.max_value)
	await _frames(4)
	var visible_rows := 0
	for slider: Slider in creator._morph_controls.values():
		if slider.get_parent().visible and slider.get_global_rect().intersects(scroll.get_global_rect()):
			visible_rows += 1
	_check(visible_rows > 0, "long list bottom remains reachable after scrolling")
	_check(_actions_inside(creator), "actions remain visible after list scroll")
	await _shot("creator_960_face_bottom")

	creator._show_page(2)
	await _frames(4)
	_check(creator._full_body and creator._pages[2].visible, "body tab selects full view")
	await _shot("creator_960_body")


func _actions_inside(creator: CharacterCreator) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var found := 0
	for node: Node in creator.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text in [tr(&"CHARACTER_CREATOR_CANCEL"), tr(&"CHARACTER_CREATOR_CONFIRM")]:
			found += 1
			if not button.is_visible_in_tree() or not viewport_rect.encloses(button.get_global_rect()):
				return false
	return found == 2


func _visible_button(text_value: String) -> Button:
	for node: Node in app.shell.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text_value and button.is_visible_in_tree():
			return button
	return null


func _tap_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func _resize_960() -> void:
	get_tree().root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_size(Vector2i(960, 540))
	var deadline := Time.get_ticks_msec() + 3000
	while get_viewport().get_visible_rect().size != Vector2(960, 540) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _frames(3)
	_check(get_viewport().get_visible_rect().size == Vector2(960, 540), "native viewport reaches 960x540")


func _wait_for_route() -> void:
	await _frames(20)
	while SceneRouter.busy or SceneRouter.current_room == null:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_webp(output_dir + "/" + file_name + ".webp", true, 0.9)
	_check(result == OK, "saved " + file_name)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
