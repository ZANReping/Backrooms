class_name TravelInteractable
extends Interactable

@export var destination_id: StringName
@export var entrance_id: StringName = &"default"


func interact(context: InteractionContext) -> void:
	context.travel_requested.emit(destination_id, entrance_id)
