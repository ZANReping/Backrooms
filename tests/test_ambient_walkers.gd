extends Node

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	await _run()
	print("AMBIENT_WALKERS_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _run() -> void:
	GameState.set_mode(&"play")
	var walker := _make_walker(Vector3.ZERO, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -1.2)]), 0.95, 0.0)
	await _physics_frames(3)
	var start := walker.global_position
	var max_step := 0.0
	for frame in range(180):
		var before := walker.global_position
		await get_tree().physics_frame
		max_step = maxf(max_step, walker.global_position.distance_to(before))
	_check(walker.global_position.distance_to(start) > 0.8, "walker follows its local route")
	_check(max_step < 0.08, "walker accelerates without teleporting")
	_check(walker.walk_speed >= 0.75 and walker.walk_speed <= 1.1, "walking speed stays in the authored civilian range")
	_check(absf(walker.global_position.y - start.y) < 0.08, "walker remains on the floor")

	var saw_reverse := false
	var previous_z := walker.global_position.z
	for frame in range(240):
		await get_tree().physics_frame
		if walker.global_position.z > previous_z + 0.0005:
			saw_reverse = true
			break
		previous_z = walker.global_position.z
	_check(saw_reverse and walker.route_direction == -1, "walker waits and reverses at the endpoint")
	_check(absf(wrapf(walker.rotation.y - PI, -PI, PI)) < 0.65, "walker turns to face the return direction")

	GameState.set_mode(&"camera")
	var camera_position := walker.global_position
	await _physics_frames(12)
	_check(walker.global_position.distance_to(camera_position) > 0.01, "camera mode keeps ambient walkers moving")

	for live_mode: StringName in [&"phone", &"inventory"]:
		GameState.set_mode(live_mode)
		var live_position: Vector3 = walker.global_position
		await _physics_frames(12)
		_check(walker.global_position.distance_to(live_position) > 0.01, "%s keeps the world moving" % live_mode)
	var paused_position := walker.global_position
	for paused_mode: StringName in [&"pause", &"appearance", &"transition"]:
		GameState.set_mode(paused_mode)
		await _physics_frames(8)
		_check(walker.global_position.distance_to(paused_position) < 0.001 and walker.actual_speed == 0.0, "%s mode freezes walker motion" % paused_mode)
	GameState.set_mode(&"play")
	await _physics_frames(20)
	_check(walker.global_position.distance_to(paused_position) > 0.03, "walker resumes from the same position")

	var blocked := _make_walker(Vector3(2.0, 0, 0), PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -2.0)]), 1.0, 0.0)
	_add_wall(Vector3(2.0, 0.9, -0.85), Vector3(1.2, 1.8, 0.16))
	await _physics_frames(150)
	_check(blocked.global_position.z > -0.72, "body collision prevents a route from crossing a wall")
	_check(blocked.global_position.y > -0.08, "blocked walker does not fall out of the scene")

	var npc_blocker := _make_walker(Vector3(4.0, 0, -1.1), PackedVector3Array(), 0.9, 0.0)
	npc_blocker.active = false
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as PlayerController
	player.position = Vector3(4.0, 0, 0.4)
	player.collision_layer = 2
	player.collision_mask = 13
	add_child(player)
	player.set_physics_process(false)
	await _physics_frames(3)
	for frame in range(90):
		player.velocity = Vector3(0, 0, -1.8)
		player.move_and_slide()
		await get_tree().physics_frame
	var player_gap := Vector2(player.global_position.x - npc_blocker.global_position.x, player.global_position.z - npc_blocker.global_position.z).length()
	_check(player_gap >= 0.60, "player moving toward an NPC keeps both capsule volumes separated")
	_check(player.global_position.z > npc_blocker.global_position.z, "player cannot walk through the NPC")

	var moving_npc := _make_walker(Vector3(-4.0, 0, 0.2), PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -2.0)]), 1.0, 0.0)
	var standing_npc := _make_walker(Vector3(-4.0, 0, -0.9), PackedVector3Array(), 0.9, 0.0)
	standing_npc.active = false
	await _physics_frames(150)
	var npc_gap := Vector2(moving_npc.global_position.x - standing_npc.global_position.x, moving_npc.global_position.z - standing_npc.global_position.z).length()
	_check(npc_gap >= 0.52, "NPC bodies do not pass through one another")

	var commute := (load("res://levels/prologue/commute.tscn") as PackedScene).instantiate()
	add_child(commute)
	var a := commute.get_node("EnvironmentGeometry/DistantCommuterA") as AmbientWalker
	var b := commute.get_node("EnvironmentGeometry/DistantCommuterB") as AmbientWalker
	_check(a != null and b != null and a.local_waypoints.size() >= 2 and b.local_waypoints.size() >= 2, "commute scene contains two authored walker routes")
	_check(not is_equal_approx(a.walk_speed, b.walk_speed) and not is_equal_approx(a.initial_wait_seconds, b.initial_wait_seconds), "commuters use different pace and phase")
	_check(a.collision_layer == 8 and b.collision_layer == 8 and a.collision_mask == 11 and b.collision_mask == 11, "commute walkers use the shared human collision layer and mask")
	_check(ProjectSettings.get_setting("layer_names/3d_physics/layer_4") == "Human NPC", "physics layer 8 is named for human NPCs")


func _make_walker(pos: Vector3, points: PackedVector3Array, speed: float, wait: float) -> AmbientWalker:
	var walker := AmbientWalker.new()
	walker.position = pos
	walker.local_waypoints = points
	walker.start_waypoint = 1
	walker.walk_speed = speed
	walker.initial_wait_seconds = wait
	walker.waypoint_wait_seconds = 0.15
	walker.collision_layer = 8
	walker.collision_mask = 11
	walker.floor_snap_length = 0.2
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.72
	shape_node.shape = capsule
	shape_node.position.y = 0.86
	walker.add_child(shape_node)
	var human := HumanCharacter.new()
	walker.add_child(human)
	add_child(walker)
	return walker


func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	add_child(body)


func _physics_frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
