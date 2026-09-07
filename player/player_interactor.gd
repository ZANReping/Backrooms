class_name PlayerInteractor
extends Node

signal focus_changed(text: String)
signal interaction_performed()

@export_range(0.5, 5.0) var reach: float = 2.6
@export_flags_3d_physics var ray_mask: int = 5

var camera: Camera3D
var context: InteractionContext
var enabled: bool = false
var target: Interactable
var exclude: Array[RID] = []
var _last_text: String = ""


func _physics_process(_delta: float) -> void:
	refresh_focus()


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed(&"interact") and not event.is_echo():
		interact_focused()
		get_viewport().set_input_as_handled()


func refresh_focus() -> void:
	target = null
	if enabled and camera != null and context != null:
		var start: Vector3 = camera.global_position
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * reach, ray_mask, exclude)
		var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var candidate: Interactable = hit["collider"] as Interactable
			if candidate != null and candidate.can_interact(context):
				target = candidate
	var text: String = target.get_interaction_text() if target != null else ""
	if text != _last_text:
		_last_text = text
		focus_changed.emit(text)


func interact_focused() -> bool:
	# Re-query when the key arrives so stale focus cannot interact through a wall.
	refresh_focus()
	if not enabled or not is_instance_valid(target):
		return false
	target.interact(context)
	interaction_performed.emit()
	return true
