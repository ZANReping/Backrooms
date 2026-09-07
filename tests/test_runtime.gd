extends Node

var app: FoundationApp
var failures: int = 0
var checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.storage_path = ""
	Settings.reset_defaults()
	Input.use_accumulated_input = false
	DirAccess.make_dir_recursive_absolute("res://artifacts/runtime_test")
	SaveService.save_path = "res://artifacts/runtime_test/session.save"
	if "--user-storage" in OS.get_cmdline_user_args():
		var user_folder: String = "user://m1_validation_" + str(OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(user_folder)
		SaveService.save_path = user_folder + "/session.save"
	app = (load("res://core/main.tscn") as PackedScene).instantiate() as FoundationApp
	add_child(app)
	await _frames(2)
	_check(GameState.mode == &"menu", "Boot starts at main menu")
	_check(await app.new_game(0), "New game creates a Casual session")
	await _frames(15)
	_check(app.player.is_on_floor(), "Player rests on real floor collision")
	_check(SceneRouter.current_id == &"test_room_a", "Initial route resolves test room A")
	var spawn: Transform3D = app.player.global_transform
	Input.action_press(&"move_forward")
	await _frames(30)
	Input.action_release(&"move_forward")
	var walk_distance: float = spawn.origin.z - app.player.global_position.z
	_check(walk_distance > 1.3 and walk_distance < 2.1, "WASD uses configured walk speed")
	app.player.restore_transform(spawn)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(25)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(spawn.origin.z - app.player.global_position.z > walk_distance, "Sprint moves farther in fewer frames")
	_check(Session.data.stats.get_value(&"stamina") < 100.0, "Sprint consumes stamina")
	app.player.restore_transform(spawn)
	await _frames(3)
	Input.action_press(&"jump")
	await _frames(4)
	_check(app.player.global_position.y > spawn.origin.y + 0.1, "Jump leaves floor")
	await _frames(70)
	_check(app.player.is_on_floor() and app.player.global_position.y < 0.1, "Holding jump does not bunny-hop")
	Input.action_release(&"jump")
	Input.action_press(&"crouch")
	await _frames(12)
	_check(app.player.camera_pivot.position.y < 1.3, "Crouch lowers camera")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(-4, 0.02, -1.5)))
	await _frames(3)
	Input.action_release(&"crouch")
	await _frames(12)
	_check(app.player.camera_pivot.position.y < 1.3, "Low beam prevents standing")
	_check(not app.save_run(), "Saving under an unsafe low ceiling is rejected")
	app.player.restore_transform(spawn)
	await _frames(12)
	_check(app.player.camera_pivot.position.y > 1.5, "Standing recovers after clearing ceiling")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(35, -15)
	motion.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(motion)
	await _frames(2)
	if DisplayServer.get_name() == "headless":
		print("SKIP: Mouse capture requires graphical DisplayServer; verified in graphical suite")
	else:
		_check(absf(app.player.rotation.y) > 0.02 and app.player.camera_pivot.rotation.x > 0.0, "Mouse input rotates yaw and pitch")
	app.player.restore_transform(spawn)
	app.player.camera_pivot.rotation.x = 0.0
	await _tap(&"inventory")
	_check(GameState.mode == &"inventory" and app.inventory_view.visible, "Tab opens inventory through input event")
	var paused_position: Vector3 = app.player.global_position
	var paused_time: float = WorldState.data.clock_seconds
	Input.action_press(&"move_forward")
	await _frames(10)
	Input.action_release(&"move_forward")
	_check(app.player.global_position.is_equal_approx(paused_position) and is_equal_approx(WorldState.data.clock_seconds, paused_time), "Modal UI locks movement and world clock")
	await _tap(&"inventory")
	var water_uid: String = _world_item(&"water")
	_check(not water_uid.is_empty(), "Room seeds a physical water bottle")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 2.0)))
	await _frames(3)
	app.player.camera.look_at(Vector3(0, 1.48, 0))
	await _frames(3)
	app.interactor.refresh_focus()
	_check(app.interactor.target is PickupInteractable, "Center ray focuses visible pickup")
	await _tap(&"interact")
	_check(Session.data.inventory.is_owned(water_uid), "E transfers physical item into the actual backpack")
	_check(not WorldState.data.world_items.has(water_uid), "Picked-up world record is removed")
	var bag_uid: String = Session.data.inventory.get_back_container()
	var model: InventoryModel = Session.data.inventory
	await _tap(&"inventory")
	app.inventory_view.placement_requested.emit(water_uid, bag_uid, Vector2i(2, 2), 1)
	_check(model.get_placement(water_uid).cell == Vector2i(2, 2) and model.get_placement(water_uid).rotation == 1, "UI signal commits rotated placement")
	app.inventory_view.equip_requested.emit(water_uid, &"primary_hand")
	_check(model.equipment.get(&"primary_hand", "") == water_uid, "Equipment references original UID")
	await _tap(&"inventory")
	await _tap(&"use_primary")
	_check(is_equal_approx(model.get_item(water_uid).contents.current, 350.0), "Primary-hand use drinks a measured sip and keeps bottle")
	await _tap(&"use_secondary")
	_check(GameState.mode == &"phone", "Secondary-hand use opens the same physical phone")
	app.shell.phone_send_requested.emit("这是离线测试消息，保留 Unicode ✓")
	_check(Session.data.phone.messages.size() == 1, "Phone accepts and stores free text")
	await _tap(&"pause")
	await _frames(4)
	_check(app.save_run(), "Casual can write save from a legal standing position")
	var saved_charge: float = model.get_item(model.equipment[&"secondary_hand"]).charge.current
	# Wall occlusion: move beyond the front wall and look at a known bottle in the room.
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(-1.05, 0.02, -7.0)))
	app.player.camera.look_at(Vector3(-1.05, 1.48, 0))
	await _frames(3)
	app.interactor.refresh_focus()
	_check(app.interactor.target == null, "World walls occlude interaction rays")
	_check(not await app.travel(&"missing_route"), "Unknown route is rejected")
	_check(SceneRouter.current_id == &"test_room_a", "Failed transition preserves current room")
	app.player.restore_transform(Transform3D(Basis.IDENTITY, Vector3(3.25, 0.02, -3.7)))
	app.player.camera.rotation = Vector3.ZERO
	app.player.camera.look_at(Vector3(3.25, 1.2, -5.88))
	await _frames(3)
	app.interactor.refresh_focus()
	_check(app.interactor.target is TravelInteractable, "Door uses the same interaction protocol")
	await _tap(&"interact")
	await _frames(10)
	# Fixed physics steps can run faster than the threaded scene loader. Wait for
	# completion rather than treating ten simulated frames as a disk I/O deadline.
	var routing_deadline: int = Time.get_ticks_msec() + 5000
	while SceneRouter.busy and Time.get_ticks_msec() < routing_deadline:
		await get_tree().process_frame
	_check(SceneRouter.current_id == &"test_room_b", "Door E input actually changes scene")
	_check(Session.data.inventory.equipment.get(&"primary_hand", "") == water_uid, "Scene travel preserves item UID and equipment")
	_check(Session.data.phone.messages.size() == 1, "Scene travel preserves phone history")
	_check(await app.travel(&"test_room_a"), "Return route works")
	_check(not WorldState.data.world_items.has(water_uid), "Returning does not respawn picked-up item")
	await _frames(3)
	app._drop(bag_uid)
	_check(model.get_back_container().is_empty() and WorldState.data.world_items.has(bag_uid), "Backpack unequips as a persistent world entity")
	_check(app.world_items.pickup(bag_uid), "Backpack and nested contents can be picked up again")
	_check(await app.load_run(), "Saved snapshot restores successfully")
	_check(SceneRouter.current_id == &"test_room_a", "Load restores saved scene")
	_check(Session.data.phone.messages.size() == 1, "Save/load preserves phone text")
	_check(is_equal_approx(Session.data.inventory.get_item(Session.data.inventory.equipment[&"secondary_hand"]).charge.current, saved_charge), "Save/load preserves physical phone battery")
	Settings.apply(false, false)
	Settings.set_value(&"developer_mode", true)
	await _frames(2)
	_check(not app.player.headbob_enabled, "Headbob setting reaches player")
	await _tap(&"debug_panel")
	_check(GameState.mode == &"debug", "F1 action opens debug-only panel")
	await _capture("debug")
	await _tap(&"debug_panel")
	await _capture("hud")
	await _tap(&"inventory")
	await _capture("inventory")
	await _tap(&"inventory")
	await _tap(&"phone")
	await _capture("phone")
	await _tap(&"pause")
	app.player.restore_transform(spawn)
	app.player.apply_look(Vector2(0, 650))
	await _capture("body")
	app.player.restore_transform(spawn)
	# The heavy fixture proves load constraints affect actual locomotion, not only a label.
	var heavy: ItemInstance = Session.data.inventory.add_item(app.item_catalog.find(&"weight_block"))
	_check(Session.data.inventory.auto_place(heavy.uid, Session.data.inventory.get_back_container()), "Overweight item may still be collected")
	app.player.restore_transform(spawn)
	await _frames(3)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(30)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(spawn.origin.z - app.player.global_position.z < walk_distance * 0.75, "Overloaded body slows movement and prevents sprint")
	_check(await app.new_game(1), "Hardcore can start a new difficulty-bound run")
	await _frames(5)
	_check(not app.save_run(), "Hardcore manual save is rejected through application API")
	Session.data.stats.change_value(&"health", -100.0)
	_check(GameState.mode == &"dead", "Health depletion opens death summary")
	_check(await app.load_run(), "Hardcore death can restore the last automatic checkpoint")
	_check(await app.new_game(2), "Extreme run receives its own automatic checkpoint")
	await _frames(5)
	var extreme_run: String = Session.data.run_id
	Session.data.stats.change_value(&"health", -100.0)
	_check(GameState.mode == &"dead", "Extreme death opens the summary")
	await _tap(&"pause")
	await _tap(&"debug_panel")
	_check(GameState.mode == &"dead", "Esc and F1 cannot escape death state")
	_check(not await app.load_run(), "Extreme death cannot invoke load even via application API")
	await _capture("death")
	app.return_to_menu()
	_check(GameState.mode == &"menu", "Death summary can return to menu")
	var remaining: SaveSnapshot = SaveService.read_snapshot()
	_check(remaining == null or remaining.session.run_id != extreme_run, "Extreme checkpoint is deleted only after leaving death summary")
	print("RUNTIME_RESULT: %d checks, %d failures" % [checks, failures])
	app.queue_free()
	# The mixer thread needs wall time even when the test uses --fixed-fps.
	var audio_deadline: int = Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < audio_deadline:
		await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _tap(action: StringName) -> void:
	var bindings: Array[InputEvent] = InputMap.action_get_events(action)
	assert(not bindings.is_empty(), "Missing InputMap action: " + String(action))
	var event: InputEvent
	if bindings[0] is InputEventKey:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = (bindings[0] as InputEventKey).physical_keycode
		key.pressed = true
		event = key
	else:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = (bindings[0] as InputEventMouseButton).button_index
		mouse.pressed = true
		mouse.position = get_viewport().get_visible_rect().size * 0.5
		event = mouse
	Input.parse_input_event(event)
	await _frames(2)
	event = event.duplicate()
	if event is InputEventKey:
		event.pressed = false
	elif event is InputEventMouseButton:
		event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _world_item(definition_id: StringName) -> String:
	for uid: String in WorldState.data.world_items:
		if Session.data.inventory.get_item(uid).definition.id == definition_id:
			return uid
	return ""


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	picture.save_webp("res://artifacts/runtime_test/" + label + ".webp")
