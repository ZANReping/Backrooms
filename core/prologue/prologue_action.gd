class_name PrologueAction
extends Interactable

signal activated(action_id: StringName)
@export var action_id: StringName


func interact(_context: InteractionContext) -> void:
	if enabled:
		activated.emit(action_id)
