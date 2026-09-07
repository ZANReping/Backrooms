extends Node3D

const HingedDoorScript := preload("res://core/presentation/hinged_door.gd")

var checks := 0
var failures := 0
var finished_states: Array[bool] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var door := _make_door()
	add_child(door)
	await get_tree().process_frame
	var pivot := door.get_node("Pivot") as Node3D
	var handle := door.get_node("Pivot/Handle") as Node3D
	var leaf := door.get_node("Pivot/Leaf") as MeshInstance3D
	var collider := door.get_node("Pivot/DoorCollision/CollisionShape3D") as CollisionShape3D
	var closed_collision_position := collider.global_position
	door.motion_finished.connect(func(open: bool) -> void: finished_states.append(open))

	door.set_open(true)
	for index: int in 3:
		await get_tree().process_frame
	_check(door.is_open() and door.is_moving(), "opening state is observable")
	_check(absf(handle.rotation.x) > 0.01 and absf(pivot.rotation.y) < 0.01, "handle presses before the leaf starts moving (handle=%.4f pivot=%.4f)" % [handle.rotation.x, pivot.rotation.y])
	await get_tree().create_timer(0.23).timeout
	_check(absf(pivot.rotation.y) > 0.05 and absf(pivot.rotation.y) < deg_to_rad(89.0), "leaf reaches an intermediate rotation")
	_check(collider.global_position.distance_to(closed_collision_position) > 0.05, "layer-1 collision follows the rotating leaf")
	await get_tree().create_timer(0.42).timeout
	_check(not door.is_moving() and door.is_open(), "opening reaches a stable final state")
	_check(is_instance_valid(leaf) and leaf.visible and leaf.is_inside_tree(), "door leaf remains present and visible after opening")
	_check(is_equal_approx(rad_to_deg(pivot.rotation.y), 90.0), "opening reaches the configured angle")
	_check(finished_states == [true], "opening emits exactly one completion signal")

	door.set_open(false, true)
	_check(not door.is_open() and not door.is_moving(), "instant close restores state")
	_check(pivot.rotation.is_equal_approx(Vector3.ZERO) and handle.rotation.is_equal_approx(Vector3.ZERO), "instant close restores pivot and handle rotations")
	_check(collider.global_position.distance_to(closed_collision_position) < 0.001, "instant close restores collision position")

	var before_repeat := finished_states.size()
	door.set_open(true)
	door.set_open(true)
	await get_tree().create_timer(0.7).timeout
	_check(finished_states.size() == before_repeat + 1 and finished_states.back(), "repeated same-state calls do not restart or duplicate motion")
	door.set_open(false)
	await get_tree().create_timer(0.2).timeout
	door.set_open(true)
	await get_tree().create_timer(0.7).timeout
	_check(door.is_open() and not door.is_moving() and finished_states.back(), "reversing an active motion finishes safely at the latest target")

	print("HINGED_DOOR_RESULT: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _make_door() -> Node3D:
	var door: Node3D = HingedDoorScript.new()
	door.pivot_path = ^"Pivot"
	door.handle_path = ^"Pivot/Handle"
	door.open_angle = 90.0
	door.duration = 0.60
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	door.add_child(pivot)
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(0.75, 1.0, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 2.0, 0.06)
	leaf.mesh = mesh
	pivot.add_child(leaf)
	var body := StaticBody3D.new()
	body.name = "DoorCollision"
	body.position = leaf.position
	body.collision_layer = 1
	pivot.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	var handle := Node3D.new()
	handle.name = "Handle"
	handle.position = Vector3(1.25, 1.0, 0.05)
	pivot.add_child(handle)
	return door


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
		return
	failures += 1
	push_error("FAIL: " + message)
