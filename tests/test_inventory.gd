extends SceneTree

const CATALOG_PATH := "res://resources/items/catalog.tres"
var _failed: bool = false

func _initialize() -> void:
	var catalog := load(CATALOG_PATH) as ItemCatalog
	_check(catalog != null and catalog.definitions.size() == 7, "catalog loads seven definitions")
	if catalog == null:
		_finish()
		return
	for definition: ItemDefinition in catalog.definitions:
		_check(definition.is_valid(), "%s is valid" % definition.id)
	_test_shapes_and_transactions(catalog)
	_test_nesting_and_weight(catalog)
	_test_round_trip_and_rejection(catalog)
	_finish()

func _test_shapes_and_transactions(catalog: ItemCatalog) -> void:
	var inventory := InventoryModel.new()
	var bag := inventory.add_item(catalog.find(&"commuter_bag"), "bag")
	var tool := inventory.add_item(catalog.find(&"l_tool"), "tool")
	var phone := inventory.add_item(catalog.find(&"phone"), "phone")
	var block := inventory.add_item(catalog.find(&"weight_block"), "block")
	_check(bag != null and tool != null and phone != null and block != null, "sample instances are created")
	_check(inventory.equip("bag", &"back"), "bag equips to back")
	_check(inventory.try_place("tool", "bag", Vector2i(0, 0), 1), "irregular item rotates and places")
	_check(inventory.get_cells("tool", 1) == [Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1)], "L footprint rotation is normalized")
	var prior_cell: Vector2i = inventory.get_placement("tool").cell
	var prior_rotation: int = inventory.get_placement("tool").rotation
	_check(not inventory.try_place("tool", "bag", Vector2i(5, 3), 0), "blocked/out-of-bounds placement is rejected")
	_check(inventory.get_placement("tool").cell == prior_cell and inventory.get_placement("tool").rotation == prior_rotation, "rejected placement rolls back")
	_check(not inventory.can_place("phone", "bag", Vector2i(0, 0), 0), "preview detects collision")
	_check(inventory.get_parent_container("phone").is_empty(), "preview leaves unowned item unchanged")
	_check(not inventory.try_place("phone", "bag", Vector2i(5, 3), 0), "blocked lower-right cell rejects footprint")
	_check(not inventory.try_place("block", "bag", Vector2i(0, 0), 1), "non-rotatable item rejects rotation")
	_check(inventory.equip("phone", &"primary_hand"), "phone equips in first hand")
	_check(inventory.equip("phone", &"secondary_hand"), "same instance moves to second hand")
	_check(inventory.equipment.get(&"primary_hand", "").is_empty() and inventory.equipment[&"secondary_hand"] == "phone", "equipment has one real reference per UID")
	var duplicate := InventoryPlacement.new()
	duplicate.item_id = "phone"
	duplicate.cell = Vector2i(4, 0)
	bag.container_inventory.placements.append(duplicate)
	_check(not inventory.validate(), "duplicate ownership is rejected")
	bag.container_inventory.placements.pop_back()
	_check(inventory.validate(), "removing duplicate restores valid inventory")

func _test_nesting_and_weight(catalog: ItemCatalog) -> void:
	var inventory := InventoryModel.new()
	var bag := inventory.add_item(catalog.find(&"commuter_bag"), "bag")
	var pouch := inventory.add_item(catalog.find(&"pouch"), "pouch")
	inventory.add_item(catalog.find(&"phone"), "phone")
	inventory.add_item(catalog.find(&"flashlight"), "light")
	var water := inventory.add_item(catalog.find(&"water"), "water")
	var block := inventory.add_item(catalog.find(&"weight_block"), "block")
	_check(inventory.equip(bag.uid, &"back"), "nested test bag equips")
	_check(inventory.try_place(pouch.uid, bag.uid, Vector2i(0, 0), 0), "empty pouch uses one cell")
	_check(inventory.try_place("phone", bag.uid, Vector2i(1, 0), 0), "neighbor occupies future pouch footprint")
	_check(not inventory.try_place("light", pouch.uid, Vector2i.ZERO, 0), "filling pouch rejects parent footprint expansion collision")
	_check(inventory.get_parent_container("light").is_empty() and pouch.container_inventory.placements.is_empty(), "nested rejection rolls back both layouts")
	_check(not inventory.try_place(bag.uid, pouch.uid, Vector2i.ZERO, 0), "nested container cycle is rejected")
	_check(inventory.try_place(block.uid, bag.uid, Vector2i(3, 1), 0), "overweight item can still be stored")
	_check(inventory.try_place(water.uid, bag.uid, Vector2i(2, 0), 0), "liquid can be stored")
	var expected := 0.9 + 0.2 + 0.2 + 25.0 + 0.05 + 0.5
	_check(is_equal_approx(inventory.get_total_weight(), expected), "equipped root recursively counts dry and liquid weight")
	var loose := inventory.add_item(catalog.find(&"l_tool"), "loose")
	_check(loose != null and is_equal_approx(inventory.get_total_weight(), expected), "unowned world item is excluded from carried weight")

func _test_round_trip_and_rejection(catalog: ItemCatalog) -> void:
	var source := InventoryModel.new()
	var bag := source.add_item(catalog.find(&"commuter_bag"), "save_bag")
	var phone := source.add_item(catalog.find(&"phone"), "save_phone")
	var water := source.add_item(catalog.find(&"water"), "save_water")
	_check(source.equip(bag.uid, &"back"), "save bag equips")
	_check(source.try_place(phone.uid, bag.uid, Vector2i(2, 1), 1), "phone placement saves rotation")
	_check(source.try_place(water.uid, bag.uid, Vector2i(4, 1), 0), "water placement saves position")
	phone.charge.consume(37.0)
	water.contents.consume(125.0)
	var data := source.to_data()
	var restored := InventoryModel.new()
	_check(restored.load_data(data, catalog), "valid inventory snapshot loads")
	_check(restored.get_item("save_phone").uid == "save_phone", "instance UID round-trips")
	_check(restored.get_placement("save_phone").cell == Vector2i(2, 1) and restored.get_placement("save_phone").rotation == 1, "placement and rotation round-trip")
	_check(is_equal_approx(restored.get_item("save_phone").charge.current, 63.0), "charge round-trips")
	_check(is_equal_approx(restored.get_item("save_water").contents.current, 375.0), "liquid contents round-trip")
	var baseline := restored.to_data()
	var bad_uid := data.duplicate(true)
	bad_uid["items"][0]["placements"][0]["item_id"] = "missing_uid"
	_check(not restored.load_data(bad_uid, catalog) and restored.to_data() == baseline, "invalid child UID is rejected transactionally")
	var duplicate := data.duplicate(true)
	duplicate["items"].append(duplicate["items"][1].duplicate(true))
	_check(not restored.load_data(duplicate, catalog) and restored.to_data() == baseline, "duplicate UID is rejected transactionally")
	var malformed := data.duplicate(true)
	malformed["items"][0]["condition"] = "broken"
	_check(not restored.load_data(malformed, catalog) and restored.to_data() == baseline, "malformed record is rejected transactionally")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _finish() -> void:
	if _failed:
		quit(1)
	else:
		print("PASS: inventory resources and model")
		quit(0)
