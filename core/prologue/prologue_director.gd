class_name PrologueDirector
extends Node

## Narrative orchestration is confined to this module. Reusable inventory,
## player, router and save services know nothing about apartment or Level 0.
var app: PrologueApplication
var config: PrologueConfig = preload("res://resources/prologue/default_prologue.tres")
var _last_position: Vector3
var _hint_elapsed: float = 0.0
var _objective_elapsed: float = 0.0
var _arrival_elapsed: float = 0.0
var _falling: bool = false
var _starting: bool = false
var _leaving_building: bool = false
var _traversal: PlayerTraversal
var _sequence_id: int = 0
var _sequence_tweens: Array[Tween] = []


func configure(application: PrologueApplication) -> void:
	app = application
	_traversal = PlayerTraversal.new()
	_traversal.player = app.player
	add_child(_traversal)


func new_run(difficulty: int) -> bool:
	if SceneRouter.busy or sequence_busy() or difficulty < 0 or difficulty > 2:
		return false
	_sequence_tweens.clear()
	var session: SessionData = SessionData.new()
	session.run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session.difficulty = difficulty as SessionData.Difficulty
	session.story_date = config.story_date.duplicate()
	session.prologue.enabled = true
	var world: WorldData = WorldData.new()
	world.clock_seconds = config.opening_seconds
	world.flags["laptop_frontrooms"] = true
	if not _prepare_inventory(session, world):
		return false
	_starting = true
	_sequence_id += 1
	var sequence: int = _sequence_id
	if not await app.enter_session(config.apartment_route, &"default", session, world):
		_starting = false
		return false
	if not _sequence_valid(sequence, session.run_id):
		return false
	app.shell.notify("")
	GameState.set_mode(&"transition")
	app.loading_cover.visible = false
	app.audio.set_alarm(true)
	app.fade.color = Color.BLACK
	app.fade.visible = true
	app.player.set_control_enabled(false)
	app.interactor.enabled = false
	await get_tree().create_timer(0.7).timeout
	if not _sequence_valid(sequence, session.run_id):
		return false
	var wake: Tween = create_tween()
	_sequence_tweens.append(wake)
	wake.tween_property(app.fade, "color:a", 0.0, 1.3)
	await wake.finished
	if not _sequence_valid(sequence, session.run_id):
		return false
	app.fade.visible = false
	GameState.set_mode(&"play")
	_starting = false
	_hint(&"PRO_WAKE_HINT")
	return true


func sequence_busy() -> bool:
	return _starting or _falling or _leaving_building


func cancel_sequences() -> void:
	_sequence_id += 1
	_starting = false
	_falling = false
	_leaving_building = false
	if _traversal != null:
		_traversal.cancel()
	for tween: Tween in _sequence_tweens:
		if tween.is_valid():
			tween.kill()
	_sequence_tweens.clear()
	if app != null and is_instance_valid(app.fade):
		app.fade.visible = false


func _sequence_valid(sequence: int, run_id: String) -> bool:
	return is_inside_tree() and sequence == _sequence_id and Session.data.run_id == run_id


func _prepare_inventory(session: SessionData, world: WorldData) -> bool:
	var route: RouteDefinition = app.route_catalog.find(config.apartment_route)
	if route == null:
		return false
	var packed: PackedScene = load(route.scene_path) as PackedScene
	if packed == null:
		return false
	var room: FoundationRoom = packed.instantiate() as FoundationRoom
	if room == null:
		return false
	var bag: ItemInstance
	var ids: Dictionary[StringName, bool] = {}
	world.initialized_rooms.append(config.apartment_route)
	for spawn: ItemSpawn in room.get_item_spawns():
		var item: ItemInstance = session.inventory.add_item(app.item_catalog.find(spawn.definition_id))
		if item == null or ids.has(spawn.definition_id):
			room.free()
			return false
		ids[spawn.definition_id] = true
		if item.definition.id == &"commuter_bag":
			bag = item
		var at: Transform3D = spawn.transform
		var ancestor: Node = spawn.get_parent()
		while ancestor is Node3D and ancestor != room:
			at = (ancestor as Node3D).transform * at
			ancestor = ancestor.get_parent()
		world.world_items[item.uid] = {"level_id": String(config.apartment_route), "transform": at}
	room.free()
	for id: StringName in [&"phone", &"keys", &"wallet", &"commuter_bag"]:
		if not ids.has(id):
			return false
	var laptop: ItemInstance = session.inventory.add_item(app.item_catalog.find(&"work_laptop"))
	return laptop != null and bag != null and session.inventory.try_place(laptop.uid, bag.uid, Vector2i(1, 1), 0) and session.inventory.validate()


func enter_room() -> void:
	if not Session.data.prologue.enabled:
		return
	_last_position = app.player.position
	_hint_elapsed = 0.0
	var room: FoundationRoom = SceneRouter.current_room
	for node: Node in room.find_children("*", "StaticBody3D", true, false):
		if node is PrologueAction:
			node.activated.connect(action)
	if SceneRouter.current_id == config.apartment_route:
		app.audio.set_location(&"apartment")
		app.audio.set_alarm(Session.data.prologue.alarm_active)
		if not Session.data.prologue.alarm_active:
			_disable_alarm()
		if bool(WorldState.data.flags.get("apartment_door_open", false)):
			_open_apartment_door(true)
	elif SceneRouter.current_id == config.commute_route:
		app.audio.set_location(&"commute")
		for marker: Node in room.find_children("*", "Marker3D", true, false):
			if marker.has_meta("prologue_action"):
				_install_vending(marker as Marker3D)
			elif marker.has_meta("prologue_trigger"):
				_install_trigger(marker as Marker3D)
	else:
		app.audio.set_location(&"arrival")
		app.audio.set_alarm(false)
	_update_objective()


func action(id: StringName) -> void:
	if sequence_busy() or SceneRouter.busy:
		return
	match id:
		&"alarm":
			stop_alarm()
		&"leave_apartment":
			if not Session.data.profile.registered:
				_hint(&"PRO_REGISTER_FIRST")
			elif not _has_essentials():
				_hint(&"PRO_ESSENTIALS_HINT")
			else:
				WorldState.data.flags["apartment_door_open"] = true
				_open_apartment_door()
		&"leave_building":
			if not Session.data.profile.registered or not _has_essentials():
				_hint(&"PRO_ESSENTIALS_HINT")
				return
			await _leave_building()
		&"buy_water":
			buy_water()


func stop_alarm() -> void:
	var state: PrologueState = Session.data.prologue
	if not state.alarm_active:
		return
	state.alarm_active = false
	state.stage = PrologueState.Stage.REGISTRATION
	app.audio.set_alarm(false)
	_disable_alarm()
	var phone: ItemInstance = find_item(&"phone")
	if phone != null and not Session.data.inventory.is_owned(phone.uid):
		app.world_items.pickup(phone.uid)
	if phone != null:
		app.show_phone(phone.uid)
		app.handheld.view.open_app(&"workspace")
	_hint(&"PRO_REGISTER_HINT")


func register_profile(data: Dictionary) -> bool:
	if not Session.data.prologue.enabled or Session.data.profile.registered:
		return false
	var candidate: Dictionary = data.duplicate(true)
	candidate["registered"] = true
	candidate["employee_id"] = "%02d%02d%02d%s" % [int(Session.data.story_date["year"]) % 100, int(Session.data.story_date["month"]), int(Session.data.story_date["day"]), Session.data.run_id.right(6)]
	candidate["company_id"] = "foundation_co"
	candidate["job_id"] = "office_staff"
	var profile: CharacterProfile = CharacterProfile.new()
	if not profile.load_data(candidate, Session.data.story_date):
		# Reconstruct a draft for precise field feedback without mutating the run.
		profile.surname = str(candidate.get("surname", ""))
		profile.given_name = str(candidate.get("given_name", ""))
		profile.birth_date = candidate.get("birth_date", {})
		profile.appearance_preset = candidate.get("appearance_preset", {})
		profile.gender_id = StringName(str(candidate.get("gender_id", "")))
		profile.employee_id = candidate["employee_id"]
		profile.registered = true
		var error_key: StringName = profile.validate(Session.data.story_date)
		app.handheld.view.set_notice(tr(error_key if not error_key.is_empty() else &"PROFILE_ERR_APPEARANCE"))
		return false
	Session.data.profile = profile
	if profile.appearance.character_seed == 0:
		profile.appearance.character_seed = Session.data.run_id.hash()
	Session.data.prologue.stage = PrologueState.Stage.PREPARE
	Session.data.prologue.mark_tutorial("phone")
	PlayerAppearance.apply(app.player, profile)
	app.handheld.view.bind_state(Session.data.phone, find_item(&"phone").charge, profile)
	app.handheld.view.open_app(&"workspace")
	_update_objective()
	# The registration checkpoint is explicit; no pre-registration autosave.
	var saved: bool = SaveService.write_snapshot(app.capture_snapshot(), true)
	app.shell.set_save_available(SaveService.has_save())
	app.handheld.view.set_notice(tr(&"PRO_REGISTERED" if saved else &"ERR_SAVE"))
	return true


func buy_water() -> bool:
	var state: PrologueState = Session.data.prologue
	if state.stage != PrologueState.Stage.COMMUTE or SceneRouter.current_id != config.commute_route:
		return false
	var marker: Node3D = SceneRouter.current_room.find_child("WaterVending", true, false) as Node3D
	if marker == null:
		return false
	if state.bought_water:
		_hint(&"PRO_WATER_BOUGHT")
		return false
	if state.credits < config.water_price:
		return false
	var water: ItemInstance = Session.data.inventory.add_item(app.item_catalog.find(&"water"))
	if water == null:
		return false
	# Vend to a real world position; failed pickup does not lose the purchase.
	var drop_position := Vector3(marker.global_position.x, 0.15, marker.global_position.z + 0.35)
	WorldState.data.world_items[water.uid] = {"level_id": String(SceneRouter.current_id), "transform": Transform3D(Basis.IDENTITY, drop_position)}
	state.bought_water = true
	state.credits -= config.water_price
	app.world_items.pickup(water.uid)
	app.world_items.refresh()
	_hint(&"PRO_WATER_RECEIVED")
	return true


func _process(delta: float) -> void:
	_objective_elapsed += delta
	if app != null and Session.data.prologue.enabled and _objective_elapsed >= 0.2:
		_objective_elapsed = 0.0
		_update_objective()
	if app == null or not Session.data.prologue.enabled or GameState.mode != &"play" or _falling:
		return
	var state: PrologueState = Session.data.prologue
	if app.player.position.distance_to(_last_position) > 1.0:
		state.mark_tutorial("move")
	_hint_elapsed += delta
	if state.stage == PrologueState.Stage.PREPARE and _hint_elapsed > 14.0:
		_hint_elapsed = 0.0
		if not state.has_tutorial("inventory"):
			_hint(&"PRO_BAG_HINT")
		elif not state.has_tutorial("inspect_laptop"):
			_hint(&"PRO_LAPTOP_HINT")
		elif not state.has_tutorial("rotate"):
			_hint(&"PRO_ROTATE_HINT")
		elif not _has_essentials():
			_hint(&"PRO_ESSENTIALS_HINT")
		elif not state.has_tutorial("leave_hint"):
			state.mark_tutorial("leave_hint")
			_hint(&"PRO_READY_HINT")
	if state.stage == PrologueState.Stage.ARRIVED:
		_arrival_elapsed += delta
		if _arrival_elapsed > 60.0:
			WorldState.data.flags.erase("laptop_arrived")
			WorldState.data.flags["laptop_survived"] = true


func on_inventory_opened() -> void:
	Session.data.prologue.mark_tutorial("inventory")


func on_item_selected(uid: String) -> void:
	var item: ItemInstance = Session.data.inventory.get_item(uid)
	if item != null and item.definition.id == &"work_laptop":
		Session.data.prologue.mark_tutorial("inspect_laptop")


func on_item_placed(uid: String, _container: String, _cell: Vector2i, rotation: int) -> void:
	var placement: InventoryPlacement = Session.data.inventory.get_placement(uid)
	if placement != null and placement.rotation == rotation and rotation % 2 == 1:
		Session.data.prologue.mark_tutorial("rotate")


func on_pickup(uid: String) -> void:
	var item: ItemInstance = Session.data.inventory.get_item(uid)
	if item == null or not Session.data.inventory.is_owned(uid):
		return
	if item.definition.id in [&"keys", &"wallet"]:
		Session.data.prologue.mark_tutorial(String(item.definition.id))
	elif item.definition.id == &"commuter_bag":
		Session.data.prologue.mark_tutorial("equipment")
		_hint(&"PRO_BAG_PICKED_UP")


func find_item(id: StringName) -> ItemInstance:
	for item: ItemInstance in Session.data.inventory.items.values():
		if item.definition.id == id:
			return item
	return null


func _has_essentials() -> bool:
	for id: StringName in [&"phone", &"keys", &"wallet", &"work_laptop"]:
		var item: ItemInstance = find_item(id)
		if item == null or not Session.data.inventory.is_owned(item.uid):
			return false
	return not Session.data.inventory.get_back_container().is_empty()


func _open_apartment_door(instant: bool = false) -> void:
	var action_node: PrologueAction = SceneRouter.current_room.find_child("ApartmentDoor", true, false) as PrologueAction
	if action_node != null:
		action_node.enabled = false
		action_node.collision_layer = 1
	var door := SceneRouter.current_room.find_child("ApartmentDoorMotion", true, false) as HingedDoor
	if door != null:
		door.set_open(true, instant)


func _leave_building() -> bool:
	var room: FoundationRoom = SceneRouter.current_room
	var door := room.find_child("BuildingExitMotion", true, false) as HingedDoor
	var approach := room.find_child("ExitApproach", true, false) as Marker3D
	var crossing := room.find_child("ExitCrossing", true, false) as Marker3D
	var action_node := room.find_child("BuildingExit", true, false) as PrologueAction
	if door == null or approach == null or crossing == null:
		return false
	_leaving_building = true
	_sequence_id += 1
	var sequence: int = _sequence_id
	var run_id: String = Session.data.run_id
	var original: Transform3D = app.player.get_save_transform()
	GameState.set_mode(&"transition")
	app.loading_cover.visible = false
	app.shell.notify("")
	action_node.enabled = false
	action_node.collision_layer = 1
	_traversal.align_view()
	await _traversal.turn_towards(crossing.global_position)
	if not _sequence_valid(sequence, run_id):
		return false
	var walked: bool = await _traversal.walk_to(approach.global_position)
	if not _sequence_valid(sequence, run_id):
		return false
	if walked:
		app.player.play_interaction()
		door.set_open(true)
		while is_instance_valid(door) and door.is_moving() and _sequence_valid(sequence, run_id):
			await get_tree().process_frame
		if not _sequence_valid(sequence, run_id):
			return false
		app.fade.color = Color(0, 0, 0, 0)
		app.fade.visible = true
		var leave_fade: Tween = create_tween()
		_sequence_tweens.append(leave_fade)
		leave_fade.tween_interval(1.0)
		leave_fade.tween_property(app.fade, "color:a", 1.0, 0.45)
		walked = await _traversal.walk_to(crossing.global_position)
		if not _sequence_valid(sequence, run_id):
			return false
		if leave_fade.is_running():
			await leave_fade.finished
	_traversal.cancel()
	if not _sequence_valid(sequence, run_id):
		return false
	var success: bool = false
	if walked:
		Session.data.prologue.stage = PrologueState.Stage.COMMUTE
		success = await app.enter_session(config.commute_route, &"default", Session.data, WorldState.data)
	if not _sequence_valid(sequence, run_id):
		return false
	if not success:
		Session.data.prologue.stage = PrologueState.Stage.PREPARE
		door.set_open(false, true)
		app.player.restore_transform(original)
		action_node.enabled = true
		action_node.collision_layer = 5
		app.fade.visible = false
		GameState.set_mode(&"play")
		_leaving_building = false
		return false
	GameState.set_mode(&"transition")
	app.loading_cover.visible = false
	var reveal: Tween = create_tween()
	_sequence_tweens.append(reveal)
	reveal.tween_property(app.fade, "color:a", 0.0, 0.55)
	await reveal.finished
	if not _sequence_valid(sequence, run_id):
		return false
	app.fade.visible = false
	_leaving_building = false
	GameState.set_mode(&"play")
	return true


func _disable_alarm() -> void:
	var alarm: PrologueAction = SceneRouter.current_room.find_child("BedroomAlarm", true, false) as PrologueAction
	if alarm != null:
		alarm.enabled = false
		alarm.collision_layer = 0


func _install_vending(marker: Marker3D) -> void:
	var node: PrologueAction = PrologueAction.new()
	node.action_id = &"buy_water"
	node.prompt_key = &"PRO_BUY_WATER"
	node.collision_layer = 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.7, 1.8, 0.18)
	shape.shape = box
	node.add_child(shape)
	marker.add_child(node)
	node.activated.connect(action)


func _install_trigger(marker: Marker3D) -> void:
	var area: Area3D = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2.8, 3.0, 2.0)
	collision.shape = shape
	area.add_child(collision)
	marker.add_child(area)
	area.body_entered.connect(_trigger.bind(StringName(marker.get_meta("prologue_trigger"))))


func _trigger(body: Node3D, id: StringName) -> void:
	if body != app.player or GameState.mode not in [&"play", &"camera"] or not Session.data.prologue.enabled:
		return
	var flag: String = "prologue_cue_" + String(id)
	if bool(WorldState.data.flags.get(flag, false)):
		return
	if id == &"noclip":
		await fall_through()
		return
	WorldState.data.flags[flag] = true
	if id == &"quiet":
		app.audio.silence_for(0.5)
	elif id == &"hum":
		app.audio.hum_hint()


func fall_through() -> bool:
	if _falling or SceneRouter.busy or Session.data.prologue.stage != PrologueState.Stage.COMMUTE:
		return false
	_falling = true
	_sequence_id += 1
	var sequence: int = _sequence_id
	var run_id: String = Session.data.run_id
	var original_transform: Transform3D = app.player.get_save_transform()
	GameState.set_mode(&"transition")
	app.loading_cover.visible = false
	app.audio.begin_fall()
	# A short real-time stumble passes through the supporting surface. Held item
	# instances stay in their mounts; no portal and no inventory reconstruction.
	var camera: Camera3D = app.player.camera
	var motion: Tween = create_tween().set_parallel(true)
	_sequence_tweens.append(motion)
	motion.tween_property(camera, "rotation:z", -0.14, 0.38)
	motion.tween_property(app.player, "position:y", app.player.position.y - 2.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	app.fade.color = Color(0, 0, 0, 0)
	app.fade.visible = true
	motion.tween_property(app.fade, "color:a", 1.0, 0.18).set_delay(0.52)
	await motion.finished
	if not _sequence_valid(sequence, run_id):
		return false
	var success: bool = await app.enter_session(config.arrival_route, &"default", Session.data, WorldState.data)
	if not _sequence_valid(sequence, run_id):
		return false
	if not success:
		app.player.restore_transform(original_transform)
		app.audio.set_location(&"commute")
		app.fade.visible = false
		GameState.set_mode(&"play")
		_falling = false
		return false
	Session.data.prologue.stage = PrologueState.Stage.ARRIVED
	GameState.set_mode(&"transition")
	app.loading_cover.visible = false
	Session.data.phone.offline = true
	Session.data.phone.changed.emit()
	WorldState.data.flags.erase("laptop_frontrooms")
	WorldState.data.flags["laptop_arrived"] = true
	_update_objective()
	app.audio.arrive()
	app.player.stepped.emit(&"carpet")
	app.player.set_control_enabled(false)
	camera.position.y = -0.42
	var land: Tween = create_tween().set_parallel(true)
	_sequence_tweens.append(land)
	land.tween_property(app.fade, "color:a", 0.0, 1.3)
	land.tween_property(camera, "position:y", 0.0, 1.25).set_trans(Tween.TRANS_SINE)
	await land.finished
	if not _sequence_valid(sequence, run_id):
		return false
	app.fade.visible = false
	GameState.set_mode(&"play")
	_falling = false
	app.save_run(true)
	return true


func _update_objective() -> void:
	if app.shell is PrologueShell:
		var task: Dictionary = PrologueTasks.describe(Session.data)
		app.shell.set_task(task.id, task.title, task.entries)
		app.shell.set_prologue_active(Session.data.prologue.stage < PrologueState.Stage.ARRIVED)


func _hint(key: StringName) -> void:
	app.shell.notify(tr(key))
