extends Node

var checks: int = 0
var failures: int = 0
var model: InventoryModel
var view: InventoryView
var grid: InventoryGridView


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_fixture()
	view = (load("res://ui/inventory/inventory_view.tscn") as PackedScene).instantiate() as InventoryView
	add_child(view)
	view.placement_requested.connect(_on_placement_requested)
	view.equip_requested.connect(_on_equip_requested)
	view.drop_requested.connect(_on_drop_requested)
	view.bind_model(model, 18.0)
	await _frames(3)
	grid = view.get_node("Margin/Root/Body/Left/GridLayer/InventoryGrid") as InventoryGridView
	_check(grid != null and grid.visible and grid.size.x > 0.0 and grid.size.y > 0.0, "inventory grid settles inside the live viewport")

	# Start on the occupied cell, drag while held, rotate through a real key event,
	# then release over a legal destination. No private GUI handler is invoked.
	var source: Vector2 = _cell_center(Vector2i(0, 0))
	var destination: Vector2 = _cell_center(Vector2i(2, 1))
	await _mouse_motion(source)
	await _mouse_button(source, true)
	await get_tree().create_timer(InventoryGridView.HOLD_SECONDS + 0.05).timeout
	await _mouse_motion(destination, MOUSE_BUTTON_MASK_LEFT)
	await _key_r()
	await _mouse_button(destination, false)
	await _frames(2)
	var moved: InventoryPlacement = model.get_placement("shape")
	_check(moved != null and moved.cell == Vector2i(2, 1) and moved.rotation == 1, "mouse drag plus physical R rotates and commits the 1x2 item")

	# A second long drag to the blocked destination must be rejected by the model.
	var prior_cell: Vector2i = moved.cell
	var prior_rotation: int = moved.rotation
	await _mouse_button(_cell_center(Vector2i(2, 1)), true)
	await get_tree().create_timer(InventoryGridView.HOLD_SECONDS + 0.05).timeout
	await _mouse_motion(_cell_center(Vector2i(5, 4)), MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(_cell_center(Vector2i(5, 4)), false)
	await _frames(2)
	var after_rejection: InventoryPlacement = model.get_placement("shape")
	_check(after_rejection != null and after_rejection.cell == prior_cell and after_rejection.rotation == prior_rotation, "blocked-cell UI placement leaves the source placement unchanged")

	# Select the real primary-hand equipment button and place that UID into the
	# bag through the grid. This proves the UI path unloads rather than cloning.
	var primary_button: Button = _equipment_button(&"primary_hand")
	_check(primary_button != null, "primary-hand equipment button exists")
	if primary_button != null:
		await _mouse_button(primary_button.get_global_rect().get_center(), true)
		await get_tree().create_timer(InventoryView.EQUIPMENT_HOLD_SECONDS + 0.05).timeout
		await _mouse_motion(_cell_center(Vector2i(0, 3)), MOUSE_BUTTON_MASK_LEFT)
		await _mouse_button(_cell_center(Vector2i(0, 3)), false)
		await _frames(2)
	var stowed: InventoryPlacement = model.get_placement("hand_item")
	_check(stowed != null and stowed.cell == Vector2i(0, 3) and model.equipment.get(&"primary_hand", "").is_empty(), "equipment long press drag stows the same UID")

	# Select the equipped backpack and activate the visible Drop button. The item
	# remains registered as a world candidate, but its UI projection must vanish.
	var back_button: Button = _equipment_button(&"back")
	_check(back_button != null, "back equipment button exists")
	if back_button != null:
		await _mouse_click(back_button.get_global_rect().get_center())
		var drop_button: Button = view.get_node("Margin/Root/Body/Details/Actions/DropButton") as Button
		await _mouse_click(drop_button.get_global_rect().get_center())
		await _frames(3)
	_check(model.get_back_container().is_empty() and String(view.get("_current_container_uid")).is_empty() and not grid.visible, "dropping Back clears the active container projection")
	var shape_before_remote_attempt: InventoryPlacement = model.get_placement("shape")
	var remote_cell: Vector2i = shape_before_remote_attempt.cell
	var remote_rotation: int = shape_before_remote_attempt.rotation
	await _mouse_click(destination)
	await _key_r()
	await _mouse_click(_cell_center(Vector2i(3, 3)))
	await _frames(2)
	var shape_after_remote_attempt: InventoryPlacement = model.get_placement("shape")
	_check(shape_after_remote_attempt != null and shape_after_remote_attempt.cell == remote_cell and shape_after_remote_attempt.rotation == remote_rotation, "hidden dropped backpack rejects remote grid editing")

	print("INV_UI_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _build_fixture() -> void:
	model = InventoryModel.new()
	var container_definition := ContainerDefinition.new()
	container_definition.id = &"ui_test_grid"
	container_definition.display_name = "INVENTORY_ROOT"
	container_definition.grid_width = 6
	container_definition.grid_height = 5
	container_definition.blocked_cells = [Vector2i(5, 4)]

	var bag_definition := ItemDefinition.new()
	bag_definition.id = &"ui_test_bag"
	bag_definition.display_name = "INVENTORY_ROOT"
	bag_definition.description_key = &"INVENTORY_SELECT_HINT"
	bag_definition.equip_slots = [&"back"]
	bag_definition.container_definition = container_definition
	bag_definition.empty_inventory_shape = [Vector2i.ZERO]
	bag_definition.packed_inventory_shape = _rectangle_cells(6, 5)

	var shape_definition := ItemDefinition.new()
	shape_definition.id = &"ui_test_shape"
	shape_definition.display_name = "INVENTORY_NO_SELECTION"
	shape_definition.description_key = &"INVENTORY_SELECT_HINT"
	shape_definition.inventory_shape = [Vector2i.ZERO, Vector2i(0, 1)]
	shape_definition.can_rotate = true

	var hand_definition := ItemDefinition.new()
	hand_definition.id = &"ui_test_hand"
	hand_definition.display_name = "INVENTORY_NO_SELECTION"
	hand_definition.description_key = &"INVENTORY_SELECT_HINT"
	hand_definition.inventory_shape = [Vector2i.ZERO]
	hand_definition.equip_slots = [&"primary_hand"]

	var bag: ItemInstance = model.add_item(bag_definition, "bag")
	var shape: ItemInstance = model.add_item(shape_definition, "shape")
	var hand_item: ItemInstance = model.add_item(hand_definition, "hand_item")
	_check(bag != null and shape != null and hand_item != null, "UI fixture creates valid item instances")
	_check(model.equip("bag", &"back"), "UI fixture equips the backpack")
	_check(model.try_place("shape", "bag", Vector2i.ZERO, 0), "UI fixture places the 1x2 item")
	_check(model.equip("hand_item", &"primary_hand"), "UI fixture equips a hand item")


func _rectangle_cells(width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			result.append(Vector2i(x, y))
	return result


func _cell_center(cell: Vector2i) -> Vector2:
	var dimensions := Vector2i(6, 5)
	var cell_size: float = maxf(18.0, minf(grid.size.x / float(dimensions.x), grid.size.y / float(dimensions.y)))
	var origin: Vector2 = grid.global_position + (grid.size - Vector2(dimensions) * cell_size) * 0.5
	return origin + Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5


func _equipment_button(slot: StringName) -> Button:
	var equipment_grid: GridContainer = view.get_node("Margin/Root/Body/Left/EquipmentGrid") as GridContainer
	var index: int = InventoryView.EQUIPMENT_SLOTS.find(slot)
	if index < 0 or index >= equipment_grid.get_child_count():
		return null
	return equipment_grid.get_child(index) as Button


func _mouse_click(position: Vector2) -> void:
	await _mouse_button(position, true)
	await _mouse_button(position, false)


func _mouse_button(position: Vector2, pressed: bool) -> void:
	# Viewport GUI hit testing uses its tracked mouse position. A motion event must
	# precede a synthetic press just as it does for a physical mouse.
	if pressed:
		await _mouse_motion(position)
	var event := InputEventMouseButton.new()
	var input_position: Vector2 = _window_position(position)
	event.position = input_position
	event.global_position = input_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.window_id = get_window().get_window_id()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frames(1)


func _mouse_motion(position: Vector2, button_mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	var input_position: Vector2 = _window_position(position)
	event.position = input_position
	event.global_position = input_position
	event.button_mask = button_mask
	event.window_id = get_window().get_window_id()
	Input.parse_input_event(event)
	await _frames(1)


func _window_position(viewport_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	return viewport_position * window_size / viewport_size


func _key_r() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event = InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame


func _on_placement_requested(uid: String, container_uid: String, cell: Vector2i, rotation: int) -> void:
	model.try_place(uid, container_uid, cell, rotation)


func _on_equip_requested(uid: String, slot: StringName) -> void:
	model.equip(uid, slot)


func _on_drop_requested(uid: String) -> void:
	model.drop(uid)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
