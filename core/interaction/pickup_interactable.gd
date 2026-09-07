class_name PickupInteractable
extends Interactable

var item: ItemInstance


func get_interaction_text() -> String:
	return tr(&"INTERACT_PICKUP") % tr(item.definition.display_name) if item != null else ""


func can_interact(context: InteractionContext) -> bool:
	return enabled and item != null and context.inventory != null and not context.inventory.is_owned(item.uid)


func interact(context: InteractionContext) -> void:
	if can_interact(context):
		context.pickup_requested.emit(item.uid)
