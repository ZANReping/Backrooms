class_name Interactable
extends StaticBody3D

@export var prompt_key: StringName = &"INTERACT_EXAMINE"
@export var enabled: bool = true


func get_interaction_text() -> String:
	return tr(prompt_key)


func can_interact(_context: InteractionContext) -> bool:
	return enabled


func interact(context: InteractionContext) -> void:
	context.notice_requested.emit(&"NOTICE_EXAMINED")
