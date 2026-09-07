extends Node

var app: PrologueApplication
var failures: int = 0
var checks: int = 0
var graphical: bool


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Input.use_accumulated_input = false
	graphical = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/prologue_runtime"))
	SaveService.save_path = "res://artifacts/prologue_runtime/test.save"
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SaveService.save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.save_path + suffix))
	app = (load("res://core/prologue/main.tscn") as PackedScene).instantiate() as PrologueApplication
	add_child(app)
	app.photos.base_path = "res://artifacts/prologue_runtime/photos"
	SaveService.photo_storage = app.photos
	await _frames(60)
	while SceneRouter.busy or SceneRouter.current_room == null:
		await get_tree().process_frame
	await _frames(3)
	await _shot("01_menu")
	_check(await app.new_game(0), "new prologue starts")
	_check(not SaveService.has_save(), "no checkpoint before registration")
	_check(Session.data.prologue.enabled and SceneRouter.current_id == &"prologue_apartment", "apartment route and state")
	await _frames(10)
	await _shot("02_apartment")
	await _benchmark("apartment")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(-1.65, 0.03, 1.7)))
	await _frames(10)
	var before: Vector3 = app.player.global_position
	_key(KEY_W, true)
	await _frames(18)
	_key(KEY_W, false)
	_check(app.player.global_position.distance_to(before) > 0.25, "physical WASD movement")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(-2.0, 0.03, 0)))
	_look_at(Vector3(-3.35, 0.68, -0.27))
	await _frames(3)
	app.interactor.refresh_focus()
	_check(app.interactor.target is PrologueAction, "alarm visible to real interaction ray")
	_key(KEY_E, true)
	await _frames(2)
	_key(KEY_E, false)
	await get_tree().create_timer(0.3).timeout
	_check(not Session.data.prologue.alarm_active and GameState.mode == &"phone", "E stops alarm and opens owned phone")
	_check(app.director.find_item(&"phone") != null and Session.data.inventory.is_owned(app.director.find_item(&"phone").uid), "same physical phone acquired")
	await _shot("03_phone_workspace")
	app.handheld.view.show_registration()
	await _shot("04_registration")
	var unregistered_before: Dictionary = Session.data.profile.to_data()
	app.handheld.view.appearance_edit_requested.emit()
	await _frames(4)
	_check(GameState.mode == &"appearance" and app.appearance_creator.visible, "phone opens the shared character creator")
	if app.appearance_creator == null:
		get_tree().quit(1)
		return
	var nose_slider := app.appearance_creator.find_child("nose_width", true, false) as HSlider
	nose_slider.value = 0.6
	await _frames(3)
	_check(Session.data.profile.to_data() == unregistered_before, "creator edits a draft without changing the live registered data")
	await _shot("04b_character_creator")
	app.appearance_creator._confirm()
	_check(GameState.mode == &"phone" and is_equal_approx(app.handheld.view.get_appearance_data()["face_morphs"][&"nose_width"], 0.6), "confirmed creator draft returns to phone")
	app.handheld.view.appearance_edit_requested.emit()
	await _frames(2)
	nose_slider.value = -0.8
	app.appearance_creator._cancel()
	_check(is_equal_approx(app.handheld.view.get_appearance_data()["face_morphs"][&"nose_width"], 0.6), "cancelled creator draft does not overwrite confirmed appearance")
	var profile: Dictionary = {"surname": "陈", "given_name": "默", "birth_date": {"year": 1988, "month": 6, "day": 15}, "gender_id": "unspecified", "appearance_preset": {"skin": 1, "body": 1, "hair": 2, "hair_color": 0, "face": 1}}
	profile["appearance"] = app.handheld.view.get_appearance_data()
	_check(app.director.register_profile(profile), "valid profile registers")
	_check(SaveService.has_save() and SaveService.read_snapshot().session.profile.registered, "registration checkpoint exists")
	_check(is_equal_approx(SaveService.read_snapshot().session.profile.appearance.face_morphs[&"nose_width"], 0.6), "custom face survives the real registration checkpoint")
	_check(not app.director.register_profile(profile), "registration cannot overwrite an existing character")
	app.handheld.view.open_app(&"chat")
	app.handheld.view._show_chat_detail(&"a_ming")
	app.handheld.view.conversation_send_requested.emit(&"a_ming", "今天正常出门了。🙂")
	_check(Session.data.phone.messages.back()["text"] == "今天正常出门了。🙂" and Session.data.phone.messages.back()["conversation_id"] == "a_ming", "phone message integrates with the selected conversation and current session")
	if graphical:
		var album_before: int = Session.data.album.photos.size()
		app.handheld.view.open_app(&"camera")
		await _frames(4)
		_check(GameState.mode == &"phone" and Session.data.album.photos.size() == album_before, "camera app first opens its phone page without taking a photo")
		app.handheld.view._camera_capture.pressed.emit()
		await _frames(4)
		_check(GameState.mode == &"camera" and app.camera_overlay.visible and Session.data.album.photos.size() == album_before, "phone capture button opens full-screen framing without taking a photo")
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and app.player.look_enabled and app.player.input_enabled, "camera allows both mouse look and player movement")
		var camera_move_before: Vector3 = app.player.global_position
		Input.action_press(&"move_right")
		for tick: int in 12:
			await get_tree().physics_frame
		Input.action_release(&"move_right")
		_check(app.player.global_position.distance_to(camera_move_before) > 0.15, "actual movement works while framing a photograph")
		var yaw_before: float = app.player.rotation.y
		_mouse_motion(Vector2(90, -24))
		await _frames(3)
		_check(not is_equal_approx(app.player.rotation.y, yaw_before), "real mouse motion changes view while full-screen camera is active")
		_mouse_click()
		var capture_deadline: int = Time.get_ticks_msec() + 5000
		while Session.data.album.photos.size() == album_before and Time.get_ticks_msec() < capture_deadline:
			await get_tree().process_frame
		_check(Session.data.album.photos.size() == album_before + 1, "left click saves one real viewport photo")
		if Session.data.album.photos.size() > album_before:
			var row: Dictionary = Session.data.album.photos.back()
			var texture: Texture2D = app.photos.read(Session.data.run_id, String(row["id"]))
			var photo: Image = texture.get_image() if texture != null else null
			_check(photo != null and photo.get_width() > photo.get_height(), "saved camera photo keeps a landscape frame")
			var capture_viewport := app.handheld.get_node("PhoneCameraViewport") as SubViewport
			var capture_camera := capture_viewport.get_node("CaptureCamera") as Camera3D
			_check(capture_viewport.find_children("*", "Control", true, false).is_empty() and capture_camera.cull_mask == 1, "saved photo source contains world geometry without phone or camera UI")
		await _shot("05_phone_camera")
		var first_photo_id: String = Session.data.album.photos.back()["id"]
		app._select_photo(first_photo_id)
		_mouse_motion(Vector2(220, 15))
		await _frames(3)
		_mouse_click()
		capture_deadline = Time.get_ticks_msec() + 5000
		while Session.data.album.photos.size() < album_before + 2 and Time.get_ticks_msec() < capture_deadline:
			await get_tree().process_frame
		var second_photo_id: String = Session.data.album.photos.back()["id"]
		_check(Session.data.album.photos.size() == album_before + 2 and app.handheld.view._selected_photo_id == second_photo_id, "new capture updates preview texture and selected photo ID together")
		app._select_photo(first_photo_id)
		var restored_picture: Texture2D = app.photos.read(Session.data.run_id, first_photo_id)
		_check(app.handheld.view._selected_photo_id == first_photo_id and app.handheld.view._photo_texture.get_image().get_data() == restored_picture.get_image().get_data(), "selecting the older photo restores its actual image")
		_key(KEY_ESCAPE, true)
		_key(KEY_ESCAPE, false)
		await _frames(4)
		_check(GameState.mode == &"phone" and app.handheld.visible and not app.camera_overlay.visible, "Escape returns from camera to the phone")
	_key(KEY_P, true)
	_key(KEY_P, false)
	await _frames(20)
	_check(GameState.mode == &"play" and app.player.input_enabled and app.player.look_enabled, "P puts phone away and restores movement and look control")
	if graphical:
		app.show_phone(app.director.find_item(&"phone").uid)
		app.handheld.view.open_app(&"camera")
		app.handheld.view._camera_capture.pressed.emit()
		await _frames(4)
		var phone_for_drain: ItemInstance = app.director.find_item(&"phone")
		var previous_charge: float = phone_for_drain.charge.current
		phone_for_drain.charge.current = 0.0
		await _frames(4)
		_check(GameState.mode == &"play" and not app.camera_overlay.visible and app.player.input_enabled, "empty battery closes camera and restores player control")
		phone_for_drain.charge.current = previous_charge
	# Pick up bag, keys and wallet using the same ray + E path as a player.
	await _pick(&"commuter_bag", Vector3(0.2, 0.03, -1.35))
	await _pick(&"keys", Vector3(2.65, 0.03, 2.82))
	await _pick(&"wallet", Vector3(2.65, 0.03, 3.1))
	_check(app.director._has_essentials(), "all everyday essentials are owned")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	await _frames(3)
	_check(GameState.mode == &"inventory" and app.inventory_view is FieldInventoryView, "Tab uses the equipment sidebar inventory presentation")
	await _shot("06a_equipment")
	var laptop: ItemInstance = app.director.find_item(&"work_laptop")
	app.inventory_view._on_item_selected(laptop.uid)
	await _shot("06_backpack")
	_check(Session.data.inventory.get_parent_container(laptop.uid) == Session.data.inventory.get_back_container(), "laptop nested in carried physical bag")
	var bag_uid: String = Session.data.inventory.get_back_container()
	app._place(laptop.uid, bag_uid, Vector2i(2, 1), 1)
	_check(Session.data.inventory.get_placement(laptop.uid).rotation == 1, "integrated rotated placement")
	_key(KEY_TAB, true)
	_key(KEY_TAB, false)
	await _frames(3)
	# Real door interaction, then the building exit's scene transition.
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(2.8, 0.02, 2.17)))
	_look_at(Vector3(4.035, 1.02, 2.17))
	await _frames(3)
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _frames(3)
	_check(bool(WorldState.data.flags.get("apartment_door_open", false)), "apartment door opens on E")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(5.25, 0.02, 0.7)))
	await _frames(3)
	await _shot("07_corridor")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(5.3, 0.02, -3.0)))
	_look_at(Vector3(5.32, 1.02, -4.72))
	await _frames(3)
	app.interactor.refresh_focus()
	var exit_door := SceneRouter.current_room.find_child("BuildingExitMotion", true, false) as HingedDoor
	var exit_pivot := exit_door.get_node(exit_door.pivot_path) as Node3D
	var exit_origin: Vector3 = app.player.position
	var last_exit_position: Vector3 = exit_origin
	var max_exit_step: float = 0.0
	var walked_past_threshold: bool = false
	var saw_partial_door: bool = false
	_key(KEY_E, true)
	_key(KEY_E, false)
	# Input dispatch and threaded loading may begin on the next frame.
	var exit_deadline: int = Time.get_ticks_msec() + 10000
	while (app.director.sequence_busy() or SceneRouter.busy or SceneRouter.current_id != &"prologue_commute") and Time.get_ticks_msec() < exit_deadline:
		await get_tree().process_frame
		if SceneRouter.current_id == &"prologue_apartment" and not SceneRouter.busy:
			max_exit_step = maxf(max_exit_step, app.player.position.distance_to(last_exit_position))
			last_exit_position = app.player.position
			walked_past_threshold = walked_past_threshold or app.player.position.z < -5.1
			if is_instance_valid(exit_pivot) and absf(exit_pivot.rotation.y) > 0.1 and absf(exit_pivot.rotation.y) < 1.4 and not saw_partial_door:
				saw_partial_door = true
				await _shot("07b_exit_opening")
	_check(saw_partial_door, "building door visibly swings through an intermediate angle")
	_check(walked_past_threshold and max_exit_step < 0.45, "player crosses the real threshold in swept steps before scene travel")
	await _frames(5)
	_check(SceneRouter.current_id == &"prologue_commute", "building exit transitions to commute")
	await _shot("08_commute")
	await _benchmark("commute")
	await _capture_walker()
	var wallet_before: int = Session.data.prologue.credits
	_check(app.director.buy_water(), "optional vending purchase")
	_check(Session.data.prologue.credits == wallet_before - 3, "water costs exactly three")
	_check(not app.director.buy_water(), "vending purchase is idempotent")
	var water: ItemInstance = app.director.find_item(&"water")
	_check(water != null and Session.data.inventory.is_owned(water.uid), "purchased bottle is carried")
	var before_inventory: Dictionary = Session.data.inventory.to_data().duplicate(true)
	var before_clock: float = WorldState.data.clock_seconds
	GameState.set_mode(&"pause")
	await _frames(10)
	_check(is_equal_approx(WorldState.data.clock_seconds, before_clock), "pause freezes story clock")
	GameState.set_mode(&"inventory")
	await _frames(10)
	_check(WorldState.data.clock_seconds > before_clock, "diegetic inventory keeps time advancing")
	GameState.set_mode(&"play")
	_check(await app.director.fall_through(), "real-time noclip reaches arrival")
	_check(SceneRouter.current_id == &"level0_arrival" and Session.data.prologue.stage == PrologueState.Stage.ARRIVED, "arrival state and route")
	_check(Session.data.inventory.to_data() == before_inventory, "all item UIDs layout liquid and charge survive noclip")
	_check(WorldState.data.clock_seconds > before_clock and WorldState.data.time_scale == 24.0, "story time continuous with 24x Backrooms scale")
	_check(Session.data.phone.offline, "phone offline after arrival")
	Session.data.phone.send_message("能看到消息吗？")
	_check(Session.data.phone.messages.back()["status"] == &"failed", "offline message persists as failed")
	await _shot("09_arrival")
	app.show_phone(app.director.find_item(&"phone").uid)
	app.handheld.view.open_app(&"chat")
	await get_tree().create_timer(0.3).timeout
	await _shot("10_offline_phone")
	GameState.set_mode(&"play")
	await _frames(10)
	_check(app.save_run(true), "arrival save writes")
	_check(await app.load_run(), "registered run resumes")
	_check(Session.data.prologue.stage == PrologueState.Stage.ARRIVED and Session.data.profile.surname == "陈", "profile stage survive resume")
	await _benchmark("arrival")
	# Independent second run proves that skipping the vending machine adds no water.
	_check(await app.new_game(0), "second independent prologue starts")
	_check(app.director.find_item(&"water") == null and not Session.data.prologue.bought_water, "skipping purchase creates no bottle")
	app.queue_free()
	await _frames(3)
	print("PROLOGUE_RUNTIME: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _pick(id: StringName, position: Vector3) -> void:
	GameState.set_mode(&"play")
	var item: ItemInstance = app.director.find_item(id)
	var target: Transform3D = WorldState.data.world_items[item.uid]["transform"]
	app.player.restore_transform(Transform3D(Basis.IDENTITY, position))
	_look_at(target.origin)
	await _frames(3)
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _frames(3)
	_check(Session.data.inventory.is_owned(item.uid), "ray pickup " + String(id))


func _look_at(target: Vector3) -> void:
	var direction: Vector3 = (target - app.player.global_position).normalized()
	var yaw: float = atan2(-direction.x, -direction.z)
	app.player.apply_look(Vector2(-wrapf(yaw - app.player.rotation.y, -PI, PI), 0) / app.player.config.mouse_sensitivity)
	direction = (target - app.player.camera.global_position).normalized()
	var pitch: float = asin(clampf(direction.y, -1, 1))
	app.player.apply_look(Vector2(0, app.player.camera_pivot.rotation.x - pitch) / app.player.config.mouse_sensitivity)


func _benchmark(scene_id: String) -> void:
	if not graphical:
		return
	await _frames(60)
	var elapsed: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for index: int in 180:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		elapsed.append((now - last) / 1000.0)
		last = now
	elapsed.sort()
	print("BENCHMARK %s ms median=%.2f p95=%.2f p99=%.2f draw_calls=%d primitives=%d" % [scene_id, elapsed[90], elapsed[171], elapsed[178], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _capture_walker() -> void:
	if not graphical:
		return
	var walker := SceneRouter.current_room.find_child("DistantCommuterA", true, false) as AmbientWalker
	var view := Camera3D.new()
	add_child(view)
	view.current = true
	view.fov = 50.0
	view.global_position = walker.global_position + Vector3(2.4, 1.3, -2.0)
	for frame: int in 3:
		view.look_at(walker.global_position + Vector3(0, 0.85, 0))
		await _shot("08b_walker_%d" % frame)
		await get_tree().create_timer(0.22).timeout
	view.queue_free()
	app.player.camera.current = true


func _shot(name_text: String) -> void:
	if graphical:
		await _frames(4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/prologue_runtime/" + name_text + ".png")
		var review: Image = get_viewport().get_texture().get_image()
		review.resize(1568, 882, Image.INTERPOLATE_LANCZOS)
		review.save_webp("res://artifacts/prologue_runtime/" + name_text + ".webp", true, 0.86)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = get_viewport().get_visible_rect().size * 0.5
	event.global_position = event.position
	Input.parse_input_event(event)


func _mouse_click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	event.position = get_viewport().get_visible_rect().size * 0.5
	event.global_position = event.position
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
