class_name SkinnedPhoneHand
extends Node3D

## Close-up right hand reuses the actual character skin, UVs and finger bones.
## It is a presentation rig on the held-prop layer, never a saved character.
var skeleton: Skeleton3D
var _model: Node3D
var _body: MeshInstance3D
var _skin: ShaderMaterial
var _pose := HumanPoseDriver.new()


func _ready() -> void:
	_model = (load(GdHumanBackend.MODEL_PATH) as PackedScene).instantiate() as Node3D
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.layers = HandheldPhone.PHONE_LAYER
		mesh.visible = mesh.name == &"body"
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.visible:
			_body = mesh
	_skin = ShaderMaterial.new()
	_skin.shader = preload("res://characters/backends/human_skin.gdshader")
	_skin.set_shader_parameter(&"skin_texture", preload("res://assets/third_party/characters/makehuman_system_cc0/skin/young_lightskinned_male_diffuse.png"))
	_skin.set_shader_parameter(&"has_skin_texture", true)
	_skin.set_shader_parameter(&"right_hand_only", true)
	_skin.set_shader_parameter(&"covered_torso", false)
	_skin.set_shader_parameter(&"covered_legs", false)
	_body.material_override = _skin
	_pose.configure(skeleton)
	_pose_grip()


func apply_appearance(value: CharacterAppearance) -> void:
	if value == null or _skin == null:
		return
	_skin.set_shader_parameter(&"skin_color", value.skin_tone)
	for id: StringName in [&"arm_size", &"weight"]:
		var targets: Array = GdHumanBackend.MORPH_TARGETS[id]
		var amount: float = float(value.body_morphs.get(id, 0.0)) * 0.35
		for target_index: int in targets.size():
			var shape_index: int = _body.find_blend_shape_by_name(StringName(targets[target_index]))
			if shape_index >= 0:
				_body.set_blend_shape_value(shape_index, maxf(amount if target_index == 0 else -amount, 0.0))


func _pose_grip() -> void:
	var wrist_index: int = skeleton.find_bone(&"hand.R")
	var wrist: Transform3D = skeleton.get_bone_global_pose(wrist_index)
	for finger: String in ["index", "middle", "ring", "pinky"]:
		for segment: int in [1, 2, 3]:
			var id := StringName("f_%s.0%d.R" % [finger, segment])
			var index: int = skeleton.find_bone(id)
			var at: Transform3D = skeleton.get_bone_global_pose(index)
			_pose.set_model_basis(id, at.basis.rotated(wrist.basis.x, 0.25 if segment == 1 else 0.42))
	# Wrist below the device; palm and four fingers support its back while the
	# thumb follows the lower edge. The forearm continues below the framing.
	var grip := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.65)), Vector3(0.06, -0.085, -0.085))
	_model.transform = grip * (skeleton.transform * wrist).affine_inverse()
	# Keep the thumb along the right bezel rather than intersecting the glass.
	var to_model: Transform3D = (_model.transform * skeleton.transform).affine_inverse()
	_pose.solve_limb(&"thumb.01.R", &"thumb.02.R", &"thumb.03.R", to_model * Vector3(0.044, -0.025, -0.009), to_model.basis * Vector3.RIGHT)
	var thumb: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone(&"thumb.03.R"))
	var thumb_direction: Vector3 = (to_model.basis * Vector3(0.05, 1.0, -0.15)).normalized()
	_pose.set_model_basis(&"thumb.03.R", Basis(Quaternion(thumb.basis.y.normalized(), thumb_direction)) * thumb.basis)
