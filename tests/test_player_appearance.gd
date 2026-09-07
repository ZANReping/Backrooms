extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var player := load("res://player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	var profile := CharacterProfile.new()
	profile.appearance.skin_tone = Color("79503b")
	profile.appearance.face_morphs[&"nose_width"] = 0.6
	profile.appearance.body_morphs[&"weight"] = 0.4
	PlayerAppearance.apply(player, profile)
	var human: HumanCharacter = player.human_visual
	_assert(human != null and human.backend.get_skeleton().get_bone_count() == 66, "player has actual shared skinned skeleton")
	var count: int = player.get_node("BodyVisual").get_child_count()
	PlayerAppearance.apply(player, profile)
	_assert(player.get_node("BodyVisual").get_child_count() == count, "repeated apply reuses visual")
	_assert(not player.get_node("BodyVisual/Torso").visible, "legacy block torso is hidden")
	_assert(player.primary_hand_mount is Marker3D and player.back_mount is Marker3D, "existing inventory mount references remain valid")
	for id: StringName in GdHumanBackend.SOCKET_BONES:
		_assert(human.get_socket(id) is BoneAttachment3D, "socket attached to bone: " + String(id))
	var body := human.backend.find_child("body", true, false) as MeshInstance3D
	var shirt := human.backend.find_child("male_shirt_01", true, false) as MeshInstance3D
	_assert(body.skin != null and shirt.skin != null, "body and shirt have real Skin bindings")
	_assert(is_equal_approx(body.get_blend_shape_value(body.find_blend_shape_by_name(&"nose_scale_X")), 0.21), "face customization reaches mesh BlendShape")
	_assert(is_equal_approx(shirt.get_blend_shape_value(shirt.find_blend_shape_by_name(&"fat")), 0.14), "supported body morph propagates to clothing")
	var npc := HumanCharacter.new()
	root.add_child(npc)
	npc.apply_appearance(CharacterAppearance.new())
	_assert(npc.backend.get_skeleton() != human.backend.get_skeleton(), "characters have independent skeleton poses")
	var npc_body := npc.backend.find_child("body", true, false) as MeshInstance3D
	_assert(npc_body.material_override != body.material_override, "characters own independent material parameters")
	player.queue_free()
	npc.queue_free()
	await process_frame
	print("PASS: player appearance" if not _failed else "FAIL: player appearance")
	quit(1 if _failed else 0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_failed = true
