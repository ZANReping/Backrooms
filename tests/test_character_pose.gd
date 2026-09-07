extends Node3D

var human: HumanCharacter
var camera: Camera3D
var checks: int = 0
var failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("343a3d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e0e5")
	environment.ambient_light_energy = 0.65
	world_environment.environment = environment
	add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.1
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.1, -3.3)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.fov = 38
	human = HumanCharacter.new()
	add_child(human)
	await get_tree().process_frame
	human.set_locomotion(0, false, 0)
	var skeleton: Skeleton3D = human.backend.get_skeleton()
	for side: String in ["L", "R"]:
		var shoulder: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm." + side)).origin
		var elbow: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("forearm." + side)).origin
		var wrist: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("hand." + side)).origin
		_check(elbow.y < shoulder.y - 0.2 and wrist.y < elbow.y - 0.2, "relaxed arm drops anatomically from shoulder to wrist " + side)
		_check(absf(wrist.x) < 0.28 and wrist.z < 0.11, "resting hand stays near hip rather than floating forward " + side)
	await _shot("standing_front")
	camera.position = Vector3(2.5, 1.1, -2.5)
	camera.look_at(Vector3(0, 0.95, 0))
	await _shot("standing_side")
	var foot_poses: Array[Vector3] = []
	for frame: int in 120:
		human.set_locomotion(1.0, false, 1.0 / 60.0)
		foot_poses.append(skeleton.get_bone_global_pose(skeleton.find_bone(&"foot.L")).origin)
		if frame in [25, 45, 70]:
			await _shot("walking_%d" % frame)
	_check(foot_poses[20].distance_to(foot_poses[40]) > 0.05, "walking changes actual ankle pose with contact/swing phases")
	for frame: int in 30:
		human.set_locomotion(0, false, 1.0 / 60.0)
	var hand_id: int = skeleton.find_bone(&"hand.R")
	var resting_hand: Vector3 = skeleton.get_bone_global_pose(hand_id).origin
	human.play_interaction()
	for frame: int in 22:
		human.set_locomotion(0, false, 1.0 / 60.0)
	_check(skeleton.get_bone_global_pose(hand_id).origin.distance_to(resting_hand) > 0.25, "interaction animates the actual character arm")
	await _shot("interaction_reach")
	for frame: int in 26:
		human.set_locomotion(0, false, 1.0 / 60.0)
	_check(skeleton.get_bone_global_pose(hand_id).origin.distance_to(resting_hand) < 0.001, "interaction blends back to the relaxed arm pose")
	var foot_index: int = skeleton.find_bone(&"foot.L")
	var standing_foot_y: float = (skeleton.global_transform * skeleton.get_bone_global_pose(foot_index).origin).y
	human.set_locomotion(0, true, 1.0 / 60.0)
	var crouched_foot_y: float = (skeleton.global_transform * skeleton.get_bone_global_pose(foot_index).origin).y
	_check(absf(standing_foot_y - crouched_foot_y) < 0.005, "crouching bends the legs while preserving foot contact height")
	await _shot("crouching")
	human.set_locomotion(0, false, 0)
	human.hide()
	camera.position = Vector3(0, 1.65, 0)
	camera.rotation = Vector3.ZERO
	var phone := HandheldPhone.new()
	add_child(phone)
	phone.configure(camera)
	var charge := ChargeState.new()
	charge.current = 80
	charge.maximum = 100
	phone.show_phone(PhoneState.new(), charge, CharacterProfile.new())
	await get_tree().create_timer(0.35).timeout
	var hand := phone.get_node("HoldingHand") as SkinnedPhoneHand
	_check(hand != null and hand.skeleton.get_bone_count() == 66, "phone uses the actual skinned hand and finger skeleton")
	var hand_mesh := hand.find_child("body", true, false) as MeshInstance3D
	_check(hand_mesh != null and hand_mesh.skin != null and hand_mesh.mesh is ArrayMesh, "phone grip is a connected mesh bound to a Skin resource")
	await _shot("phone_grip")
	phone.hide_phone()
	await get_tree().create_timer(0.3).timeout
	print("CHARACTER_POSE: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/character_pose")
	get_viewport().get_texture().get_image().save_webp("res://artifacts/character_pose/%s.webp" % label)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
