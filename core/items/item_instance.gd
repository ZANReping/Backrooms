class_name ItemInstance
extends RefCounted

var uid: String
var definition: ItemDefinition
var condition: float = 1.0
var charge: ChargeState = ChargeState.new()
var contents: CapacityState = CapacityState.new()
var custom_flags: Dictionary = {}
var container_inventory: ContainerInstance


func configure(item_definition: ItemDefinition, instance_id: String) -> void:
	definition = item_definition
	uid = instance_id
	charge.maximum = definition.charge_capacity
	charge.current = definition.initial_charge
	contents.maximum = definition.liquid_capacity
	contents.current = definition.initial_liquid
	if definition.container_definition != null:
		container_inventory = ContainerInstance.new()
		container_inventory.definition = definition.container_definition


func get_shape() -> Array[Vector2i]:
	if container_inventory == null:
		return definition.inventory_shape
	if container_inventory.placements.is_empty():
		return definition.empty_inventory_shape
	return definition.packed_inventory_shape


func to_data() -> Dictionary:
	var placements: Array[Dictionary] = []
	if container_inventory != null:
		for placement: InventoryPlacement in container_inventory.placements:
			placements.append(placement.to_data())
	return {"uid": uid, "definition": String(definition.id), "condition": condition, "charge": charge.to_data(), "contents": contents.to_data(), "custom_flags": custom_flags.duplicate(true), "placements": placements}
