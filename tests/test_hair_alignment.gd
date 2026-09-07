extends Node

const HAIR_IDS: Array[StringName] = [&"short", &"crop", &"bob", &"tied"]
var failures := 0
var checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend := GdHumanBackend.new()
	add_child(backend)
	await get_tree().process_frame
	await get_tree().process_frame
	var skeleton := backend.get_skeleton()
	_check(skeleton != null, "human skeleton loads")
	if skeleton == null:
		_finish()
		return
	var wardrobe: GdHumanWardrobe = backend._wardrobe
	var appearance := CharacterAppearance.new()
	for id: StringName in HAIR_IDS:
		appearance.hair = id
		appearance.face_morphs = {&"eye_distance": 0.0, &"cheek_size": 0.0, &"chin_length": 0.0}
		backend.apply_appearance(appearance)
		_check(wardrobe.hair.mesh != null, "%s mesh loads" % id)
		var model_bounds: AABB = wardrobe.get_hair_model_bounds()
		_check(model_bounds.position.y > (1.30 if id == &"tied" else 1.38), "%s stays above its intended lower edge" % id)
		_check(model_bounds.end.y > 1.62 and model_bounds.end.y < 1.82, "%s crown fits the head" % id)
		_check(model_bounds.position.z > -0.24 and model_bounds.end.z < 0.30, "%s forehead/back fit head depth" % id)
		_check(model_bounds.size.x > 0.12 and model_bounds.size.x < 0.30, "%s fits head width" % id)
		var contact: Dictionary = wardrobe.get_hair_contact_metrics()
		if id in [&"short", &"crop"]:
			_check(float(contact[&"occipital_min_z"]) < -0.115, "%s shell covers the measured occipital band" % id)
			_check(int(contact[&"crown_samples"]) > 80 and float(contact[&"crown_max_z"]) - float(contact[&"crown_min_z"]) > 0.11, "%s crown spans the scalp depth" % id)
			_check(model_bounds.end.y > 1.728, "%s crown clears the measured scalp crown" % id)
		elif id == &"tied":
			_check(float(contact[&"occipital_min_z"]) < -0.135, "tied shell reaches behind the ponytail root")

	appearance.hair = &"bob"
	appearance.face_morphs = {&"eye_distance": 1.0, &"cheek_size": 1.0, &"chin_length": 1.0}
	backend.apply_appearance(appearance)
	var wide: AABB = wardrobe.get_hair_model_bounds()
	appearance.face_morphs = {&"eye_distance": -1.0, &"cheek_size": -1.0, &"chin_length": -1.0}
	backend.apply_appearance(appearance)
	var narrow: AABB = wardrobe.get_hair_model_bounds()
	_check(wide.size.x > narrow.size.x, "face width expands the hair fit")
	_check(wide.size.z > narrow.size.z, "head depth expands the hair fit")

	if DisplayServer.get_name() != "headless":
		await _capture_views(backend, appearance)
	_finish()


func _capture_views(backend: GdHumanBackend, appearance: CharacterAppearance) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/character_visual/hair_alignment"))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("343b43")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cbd6e2")
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0dc")
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("c8dcff")
	fill.light_energy = 0.65
	fill.rotation_degrees = Vector3(-18.0, 142.0, 0.0)
	add_child(fill)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 30.0
	camera.near = 0.05
	var skeleton: Skeleton3D = backend.get_skeleton()
	var head_index: int = skeleton.find_bone("head")
	var head_center: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(head_index).origin) + Vector3(0.0, 0.075, 0.0)
	# The source human faces +Z. GdHumanBackend rotates its model PI, so transform
	# that source direction instead of assuming the enclosing test's world axes.
	var face_direction: Vector3 = (skeleton.global_transform.basis * Vector3.BACK).normalized()
	var side_direction: Vector3 = (skeleton.global_transform.basis * Vector3.RIGHT).normalized()
	appearance.face_morphs = {&"eye_distance": 0.0, &"cheek_size": 0.0, &"chin_length": 0.0}
	for id: StringName in HAIR_IDS:
		appearance.hair = id
		backend.apply_appearance(appearance)
		for view: String in ["front", "side"]:
			camera.global_position = head_center + (face_direction if view == "front" else side_direction) * 0.82
			camera.look_at(head_center, Vector3.UP)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/hair_alignment/%s_%s.webp" % [id, view], false, 0.9)
	appearance.hair = &"bob"
	for variant: String in ["widest", "narrowest"]:
		var extreme: float = 1.0 if variant == "widest" else -1.0
		appearance.face_morphs = {&"eye_distance": extreme, &"cheek_size": extreme, &"chin_length": extreme}
		backend.apply_appearance(appearance)
		camera.global_position = head_center + face_direction * 0.82
		camera.look_at(head_center, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/hair_alignment/bob_%s.webp" % variant, false, 0.9)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	print("Hair alignment checks: ", checks - failures, "/", checks)
	get_tree().quit(1 if failures > 0 else 0)
