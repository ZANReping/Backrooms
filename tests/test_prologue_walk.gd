extends Node

var app: PrologueApplication
var failed: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveService.save_path = "res://artifacts/prologue_runtime/walk.save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/prologue_runtime"))
	app = (load("res://core/prologue/main.tscn") as PackedScene).instantiate() as PrologueApplication
	add_child(app)
	app.photos.base_path = "res://artifacts/prologue_runtime/walk_photos"
	while SceneRouter.busy or SceneRouter.current_room == null:
		await get_tree().process_frame
	if not await app.new_game(0):
		_fail("new run")
		return
	for id: StringName in [&"commuter_bag", &"phone", &"keys", &"wallet"]:
		app.world_items.pickup(app.director.find_item(id).uid)
	app.director.stop_alarm()
	var profile: Dictionary = {"surname": "林", "given_name": "安", "birth_date": {"year": 1988, "month": 6, "day": 15}, "gender_id": "unspecified", "appearance_preset": CharacterProfile.DEFAULT_APPEARANCE.duplicate()}
	app.director.register_profile(profile)
	GameState.set_mode(&"play")
	app.director.action(&"leave_apartment")
	for waypoint: Vector3 in [Vector3(-1.2, 0, 1.6), Vector3(2.6, 0, 2.17), Vector3(5.2, 0, 2.17), Vector3(5.2, 0, -2.8)]:
		if not await _walk_to(waypoint):
			_fail("apartment/corridor waypoint " + str(waypoint) + " stopped at " + str(app.player.position))
			return
	app.player.camera.look_at(Vector3(5.32, 1.02, -4.72), Vector3.UP)
	await get_tree().physics_frame
	app.interactor.interact_focused()
	while SceneRouter.busy or app.director.sequence_busy():
		await get_tree().process_frame
	for index: int in 5:
		await get_tree().physics_frame
	if SceneRouter.current_id != &"prologue_commute":
		_fail("building exit after walking")
		return
	for waypoint: Vector3 in [Vector3(0, 0, -8), Vector3(0, 0, -16), Vector3(0, 0, -20), Vector3(8, 0, -20)]:
		if waypoint.x > 0.0:
			app.show_phone(app.director.find_item(&"phone").uid)
			app.handheld.view.open_app(&"camera")
			app.handheld.view._camera_capture.pressed.emit()
			if GameState.mode != &"camera" or not app.player.input_enabled:
				_fail("camera framing must permit walking to the real threshold")
				return
		if not await _walk_to(waypoint):
			_fail("commute waypoint " + str(waypoint) + " stopped at " + str(app.player.position))
			return
	while app.director.sequence_busy():
		await get_tree().process_frame
	if SceneRouter.current_id != &"level0_arrival":
		_fail("walking into noclip area must trigger arrival")
		return
	if not bool(WorldState.data.flags.get("prologue_cue_quiet", false)) or not bool(WorldState.data.flags.get("prologue_cue_hum", false)):
		_fail("both and only designed precursor areas were crossed")
		return
	print("PASS: physical walk from bedside through animated doors / corridor / commute / camera-mode noclip")
	app.queue_free()
	# Allow queued deletion and the AudioServer playback release to complete.
	for index: int in 3:
		await get_tree().process_frame
	# Audio playback releases on the mixer thread, independently of --fixed-fps.
	var audio_deadline: int = Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < audio_deadline:
		await get_tree().process_frame
	get_tree().quit()


func _walk_to(target: Vector3) -> bool:
	var elapsed: float = 0.0
	while elapsed < 10.0:
		if app.director.sequence_busy() or SceneRouter.current_id == &"level0_arrival":
			Input.action_release(&"move_forward")
			return true
		var direction: Vector3 = target - app.player.global_position
		direction.y = 0.0
		if direction.length() < 0.18:
			Input.action_release(&"move_forward")
			await get_tree().physics_frame
			return true
		var yaw: float = atan2(-direction.x, -direction.z)
		var difference: float = wrapf(yaw - app.player.rotation.y, -PI, PI)
		app.player.apply_look(Vector2(-difference / app.player.config.mouse_sensitivity, 0))
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
	Input.action_release(&"move_forward")
	return false


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	Input.action_release(&"move_forward")
	get_tree().quit(1)
