extends Node

var failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_apartment()
	await _test_commute()
	_test_arrival_enclosure()
	if failed:
		get_tree().quit(1)
	else:
		print("PASS: prologue physical boundaries and Label3D facing")
		get_tree().quit()


func _test_apartment() -> void:
	var scene := (load("res://levels/prologue/apartment.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().physics_frame
	_expect_box_boundary(scene, "BoundaryApartmentWindow", Vector3(2.52, 1.74, 0.12))
	var body := _make_body(Vector3(-1.49, 1.55, -3.0))
	scene.add_child(body)
	await _drive(body, Vector3(0, 0, -1), 45)
	_check(body.position.z > -3.47, "apartment window boundary allowed escape: %s" % body.position)
	var calendar: Label3D = scene.get_node_or_null("CalendarPrint")
	_check(calendar != null and calendar.text == "2026\n10 / 18   SUN", "calendar date is not 2026-10-18 Sunday")
	if calendar != null:
		_expect_label_faces(calendar, Vector3(-1.86, 1.2, -2.3), "CalendarPrint")
	body.queue_free()
	scene.queue_free()
	await get_tree().physics_frame


func _test_commute() -> void:
	var scene := (load("res://levels/prologue/commute.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().physics_frame
	var expected := {
		"BoundaryStreetLeft": Vector3(0.18, 4.0, 31.5),
		"BoundaryStreetRightNorth": Vector3(0.18, 4.0, 21.0),
		"BoundaryStreetRightSouth": Vector3(0.18, 4.0, 6.5),
		"BoundaryStreetNorth": Vector3(6.2, 4.0, 0.18),
		"BoundaryStreetSouth": Vector3(9.72, 4.0, 0.18),
	}
	for boundary_name: String in expected:
		_expect_box_boundary(scene, boundary_name, expected[boundary_name])
	await _assert_blocked(scene, Vector3(-4.2, 1.1, -12), Vector3(-1, 0, 0), func(body: CharacterBody3D) -> bool: return body.position.x > -4.65, "left railing")
	await _assert_blocked(scene, Vector3(4.2, 1.1, -8), Vector3(1, 0, 0), func(body: CharacterBody3D) -> bool: return body.position.x < 4.65, "right railing")
	await _assert_blocked(scene, Vector3(0, 1.1, -27.8), Vector3(0, 0, -1), func(body: CharacterBody3D) -> bool: return body.position.z > -28.37, "south street end")
	# The authored turn must remain open for a real player-sized body.
	var turn_body := _make_body(Vector3(4.15, 1.1, -20.0))
	scene.add_child(turn_body)
	await _drive(turn_body, Vector3(1, 0, 0), 35)
	_check(turn_body.position.x > 5.15, "normal right turn was blocked: %s" % turn_body.position)
	turn_body.queue_free()
	var geo := scene.get_node("EnvironmentGeometry")
	_expect_label_faces(geo.get_node("ShopSign"), Vector3(0, 1.6, -12), "ShopSign")
	_expect_label_faces(geo.get_node("WaterText"), Vector3(0, 1.5, -11), "WaterText")
	_expect_label_faces(geo.get_node("BusStopText"), Vector3(0, 1.4, -17), "BusStopText")
	scene.queue_free()
	await get_tree().physics_frame


func _test_arrival_enclosure() -> void:
	var scene := (load("res://levels/prologue/arrival.tscn") as PackedScene).instantiate()
	var outer_walls := scene.find_children("OuterWall*", "MeshInstance3D", true, false)
	_check(outer_walls.size() == 4, "arrival must retain four enclosing outer walls")
	for wall: MeshInstance3D in outer_walls:
		var mesh := wall.mesh as BoxMesh
		_check(mesh != null and is_equal_approx(mesh.size.y, 2.85), "arrival wall does not reach the 2.85m ceiling")
		_check(wall.find_child("Solid", false, false) != null, "arrival outer wall lacks collision")
	scene.free()


func _assert_blocked(scene: Node, start: Vector3, direction: Vector3, predicate: Callable, label: String) -> void:
	var body := _make_body(start)
	scene.add_child(body)
	await _drive(body, direction, 45)
	_check(predicate.call(body), "%s boundary allowed escape: %s" % [label, body.position])
	body.queue_free()
	await get_tree().physics_frame


func _make_body(pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.62
	collider.shape = capsule
	body.add_child(collider)
	return body


func _drive(body: CharacterBody3D, direction: Vector3, frames: int) -> void:
	for index: int in frames:
		body.velocity = direction.normalized() * 4.0 + Vector3(0, -1.0, 0)
		body.move_and_slide()
		await get_tree().physics_frame


func _expect_box_boundary(scene: Node, node_name: String, expected_size: Vector3) -> void:
	var body: StaticBody3D = scene.find_child(node_name, true, false)
	_check(body != null, "missing " + node_name)
	if body == null:
		return
	_check(body.collision_layer == 1, node_name + " must use collision layer 1")
	var collider := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var box := collider.shape as BoxShape3D if collider != null else null
	_check(box != null and box.size.is_equal_approx(expected_size), node_name + " has wrong BoxShape3D size")


func _expect_label_faces(label: Label3D, player_side: Vector3, label_name: String) -> void:
	var toward_player := label.global_position.direction_to(player_side)
	_check(label.global_basis.z.dot(toward_player) > 0.9, label_name + " faces away from the player's walking side")
	_check(not label.double_sided, label_name + " must render only its correctly oriented front face")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL: " + message)
