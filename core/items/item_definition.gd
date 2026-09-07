class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var description_key: StringName
@export var description_rules: Array[ItemDescriptionRule] = []
@export var icon: Texture2D
@export var world_scene: PackedScene
@export_range(0.0, 100.0) var weight_kg: float = 0.1
@export var inventory_shape: Array[Vector2i] = [Vector2i.ZERO]
@export var can_rotate: bool = true
@export var max_stack: int = 1
@export var tags: Array[StringName] = []
@export var use_action: StringName
@export var equip_slot: StringName
@export var equip_slots: Array[StringName] = [&"primary_hand", &"secondary_hand"]
@export var frontrooms_keepsake: bool = false
@export var world_visual_fallback: StringName = &"generic_lowpoly"
@export var color: Color = Color(0.65, 0.62, 0.48)
@export var container_definition: ContainerDefinition
@export var empty_inventory_shape: Array[Vector2i] = []
@export var packed_inventory_shape: Array[Vector2i] = []
@export var liquid_capacity: float = 0.0
@export var initial_liquid: float = 0.0
@export var charge_capacity: float = 0.0
@export var initial_charge: float = 0.0
@export var world_size: Vector3 = Vector3(0.18, 0.18, 0.18)


func is_valid() -> bool:
	if id == &"" or max_stack != 1 or not DataValidation.bounded_number(weight_kg, 0.0, 100.0):
		return false
	if not _valid_shape(inventory_shape):
		return false
	if not DataValidation.bounded_number(liquid_capacity, 0.0, 100000.0) or not DataValidation.bounded_number(initial_liquid, 0.0, liquid_capacity):
		return false
	if not DataValidation.bounded_number(charge_capacity, 0.0, 100000.0) or not DataValidation.bounded_number(initial_charge, 0.0, charge_capacity):
		return false
	if not world_size.is_finite() or world_size.x <= 0.0 or world_size.y <= 0.0 or world_size.z <= 0.0:
		return false
	if container_definition != null:
		if not container_definition.is_valid():
			return false
		if not _valid_shape(empty_inventory_shape) or not _valid_shape(packed_inventory_shape):
			return false
		var capacity: int = container_definition.grid_width * container_definition.grid_height - container_definition.blocked_cells.size()
		if capacity < 1 or capacity > 1024 or packed_inventory_shape.size() < capacity:
			return false
	return true


func _valid_shape(shape: Array[Vector2i]) -> bool:
	if shape.is_empty() or shape.size() > 1024:
		return false
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in shape:
		if cell.x < 0 or cell.y < 0 or cell.x >= 32 or cell.y >= 32 or seen.has(cell):
			return false
		seen[cell] = true
	return true
