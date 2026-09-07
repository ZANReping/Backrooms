class_name PlayerAppearance
extends RefCounted

## Installs a shared human visual without replacing controller/collision or
## invalidating the inventory's existing equipment mount references.
static func apply(player: PlayerController, profile: CharacterProfile) -> void:
	if player == null or profile == null:
		return
	var body := player.get_node_or_null("BodyVisual") as Node3D
	if body == null:
		return
	if player.human_visual == null:
		for mesh_name: String in ["Torso", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "RightArm/Mesh", "LeftArm/Mesh"]:
			var mesh := body.get_node_or_null(mesh_name) as MeshInstance3D
			if mesh != null:
				mesh.hide()
		player.human_visual = HumanCharacter.new()
		player.human_visual.name = "HumanCharacter"
		player.human_visual.first_person = true
		body.add_child(player.human_visual)
	player.human_visual.apply_appearance(profile.appearance)
