class_name CharacterBackend
extends Node3D

## A backend owns meshes, shared skeleton, morph propagation and visual sockets.
## Gameplay, saved state and random appearance rules remain outside the backend.
func apply_appearance(_appearance: CharacterAppearance) -> void:
	pass

func get_skeleton() -> Skeleton3D:
	return null

func get_socket(_id: StringName) -> Node3D:
	return null

func set_first_person(_enabled: bool) -> void:
	pass

func set_locomotion(_speed: float, _crouched: bool, _delta: float) -> void:
	pass

func play_interaction() -> void:
	pass
