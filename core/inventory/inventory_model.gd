class_name InventoryModel
extends RefCounted

signal changed()

const SLOTS: Array[StringName] = [&"head", &"face", &"torso", &"legs", &"feet", &"back", &"primary_hand", &"secondary_hand", &"accessory_1", &"accessory_2"]
const MAX_ITEMS: int = 256
const MAX_DEPTH: int = 8

var items: Dictionary[String, ItemInstance] = {}
var equipment: Dictionary[StringName, String] = {}
var last_error: StringName = &""


func add_item(definition: ItemDefinition, uid: String = "") -> ItemInstance:
	if definition == null or not definition.is_valid() or items.size() >= MAX_ITEMS:
		last_error = &"ERR_ITEM"
		return null
	if uid.is_empty():
		uid = Crypto.new().generate_random_bytes(16).hex_encode()
	if items.has(uid):
		return null
	var item: ItemInstance = ItemInstance.new()
	item.configure(definition, uid)
	items[uid] = item
	return item


func get_item(uid: String) -> ItemInstance:
	return items.get(uid) as ItemInstance


func get_container(uid: String) -> ContainerInstance:
	var item: ItemInstance = get_item(uid)
	return item.container_inventory if item != null else null


func get_back_container() -> String:
	return equipment.get(&"back", "")


func get_container_items(uid: String) -> Array[String]:
	var result: Array[String] = []
	var container: ContainerInstance = get_container(uid)
	if container != null:
		for placement: InventoryPlacement in container.placements:
			result.append(placement.item_id)
	return result


func get_placement(uid: String) -> InventoryPlacement:
	for item: ItemInstance in items.values():
		if item.container_inventory != null:
			for placement: InventoryPlacement in item.container_inventory.placements:
				if placement.item_id == uid:
					return placement
	return null


func get_parent_container(uid: String) -> String:
	for item: ItemInstance in items.values():
		if uid in get_container_items(item.uid):
			return item.uid
	return ""


func is_owned(uid: String) -> bool:
	var cursor: String = uid
	for depth: int in range(MAX_DEPTH + 1):
		if cursor in equipment.values():
			return true
		cursor = get_parent_container(cursor)
		if cursor.is_empty():
			return false
	return false


func get_cells(uid: String, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var item: ItemInstance = get_item(uid)
	if item == null:
		return result
	var minimum: Vector2i = Vector2i(10000, 10000)
	for source: Vector2i in item.get_shape():
		var cell: Vector2i = source
		for step: int in range(posmod(rotation, 4)):
			cell = Vector2i(-cell.y, cell.x)
		minimum = minimum.min(cell)
		result.append(cell)
	for index: int in range(result.size()):
		result[index] -= minimum
	return result


func try_place(uid: String, container_uid: String, cell: Vector2i, rotation: int) -> bool:
	return _move(uid, container_uid, &"", cell, rotation, true)


func can_place(uid: String, container_uid: String, cell: Vector2i, rotation: int) -> bool:
	var previous_error: StringName = last_error
	var result: bool = _move(uid, container_uid, &"", cell, rotation, false)
	last_error = previous_error
	return result


func auto_place(uid: String, container_uid: String) -> bool:
	var container: ContainerInstance = get_container(container_uid)
	if container == null or not items.has(uid):
		last_error = &"ERR_NO_CONTAINER"
		return false
	var turns: int = 4 if items[uid].definition.can_rotate else 1
	for rotation: int in range(turns):
		for y: int in range(container.definition.grid_height):
			for x: int in range(container.definition.grid_width):
				if can_place(uid, container_uid, Vector2i(x, y), rotation):
					return try_place(uid, container_uid, Vector2i(x, y), rotation)
	last_error = &"ERR_NO_SPACE"
	return false


func equip(uid: String, slot: StringName) -> bool:
	if not SLOTS.has(slot) or not items.has(uid):
		last_error = &"ERR_SLOT"
		return false
	if equipment.get(slot, "") == uid:
		return true
	if not equipment.get(slot, "").is_empty():
		last_error = &"ERR_SLOT_OCCUPIED"
		return false
	return _move(uid, "", slot, Vector2i.ZERO, 0, true)


func drop(uid: String) -> bool:
	return _move(uid, "", &"", Vector2i.ZERO, 0, true)


func _move(uid: String, container_uid: String, slot: StringName, cell: Vector2i, rotation: int, commit: bool) -> bool:
	last_error = &""
	if not items.has(uid) or rotation < 0 or rotation > 3:
		last_error = &"ERR_ITEM"
		return false
	if rotation != 0 and not items[uid].definition.can_rotate:
		last_error = &"ERR_ROTATION"
		return false
	if not container_uid.is_empty() and get_container(container_uid) == null:
		last_error = &"ERR_NO_CONTAINER"
		return false
	# Preview is a reversible transaction; validate ancestor footprints before publishing.
	var old_equipment: Dictionary[StringName, String] = equipment.duplicate()
	var old_layouts: Dictionary[String, Array] = {}
	for item: ItemInstance in items.values():
		if item.container_inventory != null:
			old_layouts[item.uid] = item.container_inventory.placements.duplicate()
	_detach(uid)
	if not container_uid.is_empty():
		var placement: InventoryPlacement = InventoryPlacement.new()
		placement.item_id = uid
		placement.cell = cell
		placement.rotation = rotation
		get_container(container_uid).placements.append(placement)
	elif slot != &"":
		equipment[slot] = uid
	var valid: bool = validate()
	if not valid or not commit:
		equipment = old_equipment
		for owner_id: String in old_layouts:
			get_container(owner_id).placements.assign(old_layouts[owner_id])
	else:
		changed.emit()
	return valid


func _detach(uid: String) -> void:
	for slot: StringName in equipment.keys():
		if equipment[slot] == uid:
			equipment.erase(slot)
	for item: ItemInstance in items.values():
		if item.container_inventory != null:
			for index: int in range(item.container_inventory.placements.size() - 1, -1, -1):
				if item.container_inventory.placements[index].item_id == uid:
					item.container_inventory.placements.remove_at(index)


func validate() -> bool:
	var parents: Dictionary[String, String] = {}
	for slot: StringName in equipment:
		var uid: String = equipment[slot]
		if not SLOTS.has(slot) or not items.has(uid) or parents.has(uid):
			return _fail(&"ERR_SLOT")
		if not items[uid].definition.equip_slots.has(slot):
			return _fail(&"ERR_SLOT")
		if slot == &"back" and get_container(uid) == null:
			return _fail(&"ERR_SLOT")
		parents[uid] = ""
	for item: ItemInstance in items.values():
		if item.container_inventory == null:
			continue
		for placement: InventoryPlacement in item.container_inventory.placements:
			if not items.has(placement.item_id) or parents.has(placement.item_id):
				return _fail(&"ERR_DUPLICATE")
			parents[placement.item_id] = item.uid
	for uid: String in items:
		var seen: Array[String] = [uid]
		var cursor: String = parents.get(uid, "")
		while not cursor.is_empty():
			if seen.has(cursor) or seen.size() > MAX_DEPTH:
				return _fail(&"ERR_CYCLE")
			seen.append(cursor)
			cursor = parents.get(cursor, "")
	for item: ItemInstance in items.values():
		var container: ContainerInstance = item.container_inventory
		if container == null:
			continue
		var occupied: Dictionary[Vector2i, bool] = {}
		for placement: InventoryPlacement in container.placements:
			var child: ItemInstance = items[placement.item_id]
			if placement.rotation < 0 or placement.rotation > 3 or (placement.rotation != 0 and not child.definition.can_rotate):
				return _fail(&"ERR_ROTATION")
			if not container.definition.allowed_tags.is_empty():
				var allowed: bool = false
				for tag: StringName in child.definition.tags:
					allowed = allowed or container.definition.allowed_tags.has(tag)
				if not allowed:
					return _fail(&"ERR_TAG")
			for offset: Vector2i in get_cells(child.uid, placement.rotation):
				var cell: Vector2i = placement.cell + offset
				if not container.definition.contains_cell(cell) or occupied.has(cell):
					return _fail(&"ERR_NO_SPACE")
				occupied[cell] = true
	return true


func _fail(key: StringName) -> bool:
	last_error = key
	return false


func get_item_weight(uid: String, depth: int = 0) -> float:
	if not items.has(uid) or depth > MAX_DEPTH:
		return 0.0
	var item: ItemInstance = items[uid]
	var weight: float = item.definition.weight_kg + item.contents.current / 1000.0
	for child_id: String in get_container_items(uid):
		weight += get_item_weight(child_id, depth + 1)
	return weight


func get_total_weight() -> float:
	var result: float = 0.0
	for uid: String in equipment.values():
		result += get_item_weight(uid)
	return result


func to_data() -> Dictionary:
	var records: Array[Dictionary] = []
	var slots: Dictionary = {}
	for item: ItemInstance in items.values():
		records.append(item.to_data())
	for slot: StringName in equipment:
		slots[String(slot)] = equipment[slot]
	return {"items": records, "equipment": slots}


func load_data(data: Dictionary, catalog: ItemCatalog) -> bool:
	if not data.get("items") is Array or not data.get("equipment") is Dictionary:
		return false
	var records: Array = data["items"]
	if records.size() > MAX_ITEMS:
		return false
	var candidate: InventoryModel = InventoryModel.new()
	for record_value: Variant in records:
		if not record_value is Dictionary:
			return false
		var record: Dictionary = record_value
		if not record.get("uid") is String or String(record["uid"]).is_empty() or String(record["uid"]).length() > 128 or not record.get("definition") is String:
			return false
		var definition: ItemDefinition = catalog.find(StringName(record["definition"]))
		var item: ItemInstance = candidate.add_item(definition, record["uid"])
		if item == null or not DataValidation.bounded_number(record.get("condition"), 0.0, 1.0):
			return false
		if not record.get("charge") is Dictionary or not record.get("contents") is Dictionary or not record.get("custom_flags") is Dictionary or not record.get("placements") is Array:
			return false
		if not item.charge.load_data(record["charge"]) or not item.contents.load_data(record["contents"]) or not DataValidation.flags_valid(record["custom_flags"]):
			return false
		if item.charge.maximum != definition.charge_capacity or item.contents.maximum != definition.liquid_capacity:
			return false
		item.condition = float(record["condition"])
		item.custom_flags = record["custom_flags"].duplicate(true)
		var placements: Array = record["placements"]
		if placements.size() > MAX_ITEMS or (item.container_inventory == null and not placements.is_empty()):
			return false
		for placement_value: Variant in placements:
			if not placement_value is Dictionary:
				return false
			var row: Dictionary = placement_value
			if not row.get("item_id") is String or not row.get("cell") is Vector2i or not row.get("rotation") is int:
				return false
			var placement: InventoryPlacement = InventoryPlacement.new()
			placement.item_id = row["item_id"]
			placement.cell = row["cell"]
			placement.rotation = row["rotation"]
			item.container_inventory.placements.append(placement)
	var raw_slots: Dictionary = data["equipment"]
	for slot_value: Variant in raw_slots:
		if not slot_value is String or not raw_slots[slot_value] is String:
			return false
		candidate.equipment[StringName(slot_value)] = raw_slots[slot_value]
	if not candidate.validate():
		return false
	items = candidate.items
	equipment = candidate.equipment
	changed.emit()
	return true
