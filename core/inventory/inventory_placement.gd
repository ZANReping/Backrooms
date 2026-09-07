class_name InventoryPlacement
extends RefCounted

var item_id: String
var cell: Vector2i
var rotation: int = 0


func to_data() -> Dictionary:
	return {"item_id": item_id, "cell": cell, "rotation": rotation}
