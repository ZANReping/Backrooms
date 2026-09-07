class_name StarterLoadout
extends Resource

@export var backpack: ItemDefinition
@export var items: Array[StarterItem] = []


func populate(inventory: InventoryModel) -> bool:
	var bag: ItemInstance = inventory.add_item(backpack)
	if bag == null or not inventory.equip(bag.uid, &"back"):
		return false
	for entry: StarterItem in items:
		var item: ItemInstance = inventory.add_item(entry.definition)
		if item == null:
			return false
		if entry.slot != &"":
			if not inventory.equip(item.uid, entry.slot):
				return false
		elif not inventory.try_place(item.uid, bag.uid, entry.cell, entry.rotation):
			return false
	return true
