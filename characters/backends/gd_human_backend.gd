class_name GdHumanBackend
extends CharacterBackend

## Minimal adapter for the pinned GD-Human native skinned asset. No upstream
## global singleton, editor plugin or third-party save data is installed.
const MODEL_PATH := "res://characters/generated/human.glb"
const SUPPORTED_MORPHS: Array[StringName] = [&"nose_width", &"nose_height", &"nose_length", &"eye_distance", &"eye_height", &"jaw_height", &"chin_length", &"chin_width", &"cheek_size", &"brow_height", &"mouth_width", &"mouth_height", &"weight", &"muscle", &"waist_size", &"arm_size", &"leg_size"]
const MORPH_TARGETS: Dictionary = {
	&"nose_width": ["nose_scale_X", ""], &"nose_height": ["nose_scale_Y", ""], &"nose_length": ["nose_scale_Z", ""],
	&"mouth_width": ["lips_scale_X_+", "lips_scale_X_-"], &"mouth_height": ["lips_scale_Y_+", "lips_scale_Y_-"],
	&"eye_distance": ["eye_pam11_+", "eye_pam11_-"], &"eye_height": ["eye_pam12_+", "eye_pam12_-"],
	&"jaw_height": ["jaw_pam5_+", "jaw_pam5_-"], &"chin_length": ["jaw_pam3_+", "jaw_pam3_-"],
	&"chin_width": ["jaw_pam4_+", "jaw_pam4_-"], &"cheek_size": ["cheek_pam1_+", "cheek_pam1_-"],
	&"brow_height": ["head_pam_5_+", "head_pam_5_-"],
	&"weight": ["fat", "skinny"], &"muscle": ["muscle", ""], &"waist_size": ["stomach+", "stomach-"],
	&"arm_size": ["armfat", ""], &"leg_size": ["legfat", ""],
}
const SOCKET_BONES: Dictionary[StringName, StringName] = {&"head": &"head", &"face": &"head", &"chest": &"chest", &"back": &"chest", &"hip_left": &"hips", &"hip_right": &"hips", &"hand_left": &"hand.L", &"hand_right": &"hand.R"}
const SOCKET_NAMES: Dictionary[StringName, StringName] = {&"head": &"HeadSocket", &"face": &"FaceSocket", &"chest": &"ChestSocket", &"back": &"BackSocket", &"hip_left": &"HipLeftSocket", &"hip_right": &"HipRightSocket", &"hand_left": &"HandLeftSocket", &"hand_right": &"HandRightSocket"}

var _model: Node3D
var _skeleton: Skeleton3D
var _meshes: Dictionary[StringName, MeshInstance3D] = {}
var _sockets: Dictionary[StringName, BoneAttachment3D] = {}
var _skin: ShaderMaterial
var _first_person: bool = false
var _appearance: CharacterAppearance
var _wardrobe := GdHumanWardrobe.new()
var _pose_driver := HumanPoseDriver.new()


func _ready() -> void:
	_model = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI # Source faces +Z; the gameplay convention is -Z.
	add_child(_model)
	for node: Node in _model.find_children("*", "Skeleton3D", true, false):
		_skeleton = node as Skeleton3D
		break
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if String(mesh.name).contains("Dress") or String(mesh.name).contains("dress"):
			mesh.hide()
			continue
		_meshes[mesh.name] = mesh
		mesh.visibility_range_end = 65.0
		mesh.visibility_range_end_margin = 5.0
	_skin = ShaderMaterial.new()
	_skin.shader = preload("res://characters/backends/human_skin.gdshader")
	_skin.set_shader_parameter(&"skin_texture", preload("res://assets/third_party/characters/makehuman_system_cc0/skin/young_lightskinned_male_diffuse.png"))
	_skin.set_shader_parameter(&"has_skin_texture", true)
	if _meshes.has(&"body"):
		_meshes[&"body"].material_override = _skin
	for id: StringName in [&"male_shirt_01", &"male_jeans_01"]:
		if _meshes.has(id):
			_meshes[id].material_override = _cloth_material()
	for id: StringName in [&"teeth", &"eyes", &"tongue"]:
		if _meshes.has(id):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("dbd4bd") if id != &"tongue" else Color("914f53")
			material.roughness = 0.4
			if id == &"eyes":
				material.albedo_color = Color.WHITE
				material.albedo_texture = preload("res://assets/third_party/characters/makehuman_system_cc0/eyes/brown_eye.png")
			_meshes[id].material_override = material
	if _skeleton != null:
		for id: StringName in SOCKET_BONES:
			var socket := BoneAttachment3D.new()
			socket.name = SOCKET_NAMES[id]
			socket.bone_name = SOCKET_BONES[id]
			_skeleton.add_child(socket)
			_sockets[id] = socket
		_wardrobe.configure(_skeleton)
	set_locomotion(0.0, false, 0.0)
	set_first_person(_first_person)
	if _appearance != null:
		apply_appearance(_appearance)


func apply_appearance(value: CharacterAppearance) -> void:
	_appearance = value.copy()
	if not is_node_ready():
		return
	for mesh: MeshInstance3D in _meshes.values():
		for key: StringName in MORPH_TARGETS:
			var amount: float = value.face_morphs.get(key, value.body_morphs.get(key, 0.0)) * 0.35
			var targets: Array = MORPH_TARGETS[key]
			_set_shape(mesh, StringName(targets[0]), maxf(amount, 0.0) if not String(targets[1]).is_empty() else amount)
			if not String(targets[1]).is_empty():
				_set_shape(mesh, StringName(targets[1]), maxf(-amount, 0.0))
		_set_shape(mesh, &"man", 0.35 if value.body_type == &"male" else 0.0)
		_set_shape(mesh, &"woman1", 0.35 if value.body_type == &"female" else 0.0)
	_skin.set_shader_parameter(&"skin_color", value.skin_tone)
	_wardrobe.apply_appearance(value)
	for pair: Array in [[&"male_shirt_01", &"top"], [&"male_jeans_01", &"bottom"]]:
		if _meshes.has(pair[0]):
			var material := _meshes[pair[0]].material_override as StandardMaterial3D
			material.albedo_color = value.clothing_colors.get(pair[1], Color("535d62"))


func _set_shape(mesh: MeshInstance3D, id: StringName, value: float) -> void:
	var index: int = mesh.find_blend_shape_by_name(id)
	if index >= 0:
		mesh.set_blend_shape_value(index, value)


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_socket(id: StringName) -> Node3D:
	return _sockets.get(id)


func set_first_person(enabled: bool) -> void:
	_first_person = enabled
	_wardrobe.set_first_person(enabled)
	if _skin != null:
		_skin.set_shader_parameter(&"first_person", enabled)
	for id: StringName in [&"eyes", &"teeth", &"tongue"]:
		if _meshes.has(id):
			_meshes[id].visible = not enabled


func set_locomotion(speed: float, crouched: bool, delta: float) -> void:
	if _skeleton == null:
		return
	if _pose_driver.skeleton == null:
		_pose_driver.configure(_skeleton)
	_pose_driver.update(speed, crouched, delta)
	_model.position = _pose_driver.body_offset(crouched)


func play_interaction() -> void:
	_pose_driver.play_interaction()


func _cloth_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.88
	material.normal_enabled = true
	material.normal_texture = preload("res://assets/third_party/polyhaven/textures/fabric_pattern_07/fabric_pattern_07_nor_gl_1k.jpg")
	material.normal_scale = 0.18
	material.uv1_scale = Vector3(4.0, 4.0, 4.0)
	return material
