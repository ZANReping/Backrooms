extends Node

var checks: int = 0
var failures: int = 0
var model: InventoryModel
var view: FieldInventoryView
var grid: FieldInventoryGrid
var close_received: bool = false
var placement_requests: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_fixture()
	view = (load("res://ui/inventory/field_inventory_view.tscn") as PackedScene).instantiate() as FieldInventoryView
	add_child(view)
	view.placement_requested.connect(_on_placement_requested)
	view.bind_model(model, 18.0)
	await _frames(3)
	grid = view.get_node("%InventoryGrid") as FieldInventoryGrid
	_check(grid != null and grid.size.x > 0.0 and grid.size.y > 0.0, "field grid has usable live geometry")
	_check((view.get_node("%EquipmentPane") as Control).visible and not (view.get_node("%Details") as Control).visible, "equipment sidebar is the default pane")
	var equipment_grid: GridContainer = view.get_node("%EquipmentGrid") as GridContainer
	_check(equipment_grid.columns == 1 and equipment_grid.get_child_count() == 10, "ten equipment slots form one vertical column")
	var first_slot: Button = equipment_grid.get_child(0) as Button
	var first_row := first_slot.get_child(0) as HBoxContainer
	_check(first_slot.get_child_count() == 1 and first_row.get_child_count() == 2 and first_row.get_child(0) is VBoxContainer, "equipment row uses restrained text and actual item thumbnail without a body icon")
	_check(String(view.get("_selected_uid")).is_empty() and grid.held_uid.is_empty(), "opening inventory starts without selection or held item")
	await _capture_view("equipment")
	var initial_cell := _cell_center(Vector2i.ZERO)
	await _mouse_click(initial_cell)
	await _frames(2)
	_check(String(view.get("_selected_uid")) == "shape" and grid.held_uid.is_empty() and model.get_placement("shape").cell == Vector2i.ZERO, "short click selects without holding or changing the model")
	_check((view.get_node("%Details") as Control).visible and not (view.get_node("%EquipmentPane") as Control).visible, "short click selection swaps sidebar to details")
	var thumbnail_button := view.find_child("SelectedItemThumbnailButton", true, false) as Button
	_check(thumbnail_button != null and thumbnail_button.visible and (thumbnail_button.get_child(0) as TextureRect).texture != null, "details exposes the selected item's real thumbnail button")
	await _capture_view("details")
	var requests_before_thumbnail_drag: int = placement_requests
	await _mouse_button(thumbnail_button.get_global_rect().get_center(), true)
	await get_tree().create_timer(InventoryView.EQUIPMENT_HOLD_SECONDS + 0.05).timeout
	var thumbnail_destination: Vector2 = _cell_center(Vector2i.ZERO)
	await _mouse_motion(thumbnail_destination, MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(thumbnail_destination, false)
	await _frames(2)
	_check(placement_requests == requests_before_thumbnail_drag + 1 and model.get_placement("shape").cell == Vector2i.ZERO, "thumbnail long press releases through the real grid placement path")
	var requests_before_thumbnail_click: int = placement_requests
	await _mouse_click(thumbnail_button.get_global_rect().get_center())
	await _frames(2)
	_check(String(view.get("_selected_uid")).is_empty() and (view.get_node("%EquipmentPane") as Control).visible and placement_requests == requests_before_thumbnail_click, "thumbnail short click cancels selection without a placement transaction")

	for viewport_size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await _frames(3)
		_check(_inside_viewport(view.get_node("%CloseButton") as Control), "close remains visible at %dx%d" % [viewport_size.x, viewport_size.y])
		_check(_inside_viewport(view.get_node("%Sidebar") as Control), "single scrolling sidebar remains inside %dx%d" % [viewport_size.x, viewport_size.y])
		_check(grid.size.x >= 360.0 and grid.size.y >= 240.0, "bag surface remains usable at %dx%d" % [viewport_size.x, viewport_size.y])

	get_window().size = Vector2i(1280, 720)
	await _frames(3)
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
	_check(moved != null and moved.cell == Vector2i(2, 1) and moved.rotation == 1, "real mouse drag and physical R commit through inherited transaction wiring")

	var hand_button := _equipment_button(&"primary_hand")
	var equipment_destination := _cell_center(Vector2i(0, 3))
	await _mouse_button(hand_button.get_global_rect().get_center(), true)
	await get_tree().create_timer(InventoryView.EQUIPMENT_HOLD_SECONDS + 0.05).timeout
	await _mouse_motion(equipment_destination, MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(equipment_destination, false)
	await _frames(2)
	var stowed: InventoryPlacement = model.get_placement("hand_item")
	_check(stowed != null and stowed.cell == Vector2i(0, 3) and model.equipment.get(&"primary_hand", "").is_empty(), "long press drags equipped item into the bag grid")
	await _mouse_click(_cell_center(Vector2i(2, 1)))
	_check(String(view.get("_selected_uid")) == "shape", "item can be selected before reopening")
	thumbnail_button = view.find_child("SelectedItemThumbnailButton", true, false) as Button
	await _mouse_button(thumbnail_button.get_global_rect().get_center(), true)
	await get_tree().create_timer(InventoryView.EQUIPMENT_HOLD_SECONDS + 0.05).timeout
	_check(grid.held_uid == "shape", "selected thumbnail starts drag only after the long-press threshold")
	view.hide()
	await _frames(1)
	_check(grid.held_uid.is_empty() and String(view.get("_equipment_press_uid")).is_empty(), "hiding during a thumbnail hold cancels all interaction state")
	view.show()
	await _frames(2)
	_check(String(view.get("_selected_uid")).is_empty() and grid.held_uid.is_empty() and (view.get_node("%EquipmentPane") as Control).visible, "real hide and show clears selection and restores equipment")

	view.close_requested.connect(_on_close_requested)
	var close_button: Button = view.get_node("%CloseButton") as Button
	await _mouse_click(close_button.get_global_rect().get_center())
	_check(close_received, "fixed close button receives a real mouse click")

	print("FIELD_INV_UI_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _capture_view(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/field_inventory")
	get_viewport().get_texture().get_image().save_webp("res://artifacts/field_inventory/%s.webp" % label)


func _build_fixture() -> void:
	model = InventoryModel.new()
	var container_definition := ContainerDefinition.new()
	container_definition.id = &"field_ui_grid"
	container_definition.display_name = "INVENTORY_ROOT"
	container_definition.grid_width = 6
	container_definition.grid_height = 5

	var bag_definition := ItemDefinition.new()
	bag_definition.id = &"field_ui_bag"
	bag_definition.display_name = "INVENTORY_ROOT"
	bag_definition.description_key = &"INVENTORY_SELECT_HINT"
	bag_definition.equip_slots = [&"back"]
	bag_definition.container_definition = container_definition
	bag_definition.empty_inventory_shape = [Vector2i.ZERO]
	bag_definition.packed_inventory_shape = _rectangle_cells(6, 5)

	var shape_definition := ItemDefinition.new()
	shape_definition.id = &"field_ui_shape"
	shape_definition.display_name = "INVENTORY_NO_SELECTION"
	shape_definition.description_key = &"INVENTORY_SELECT_HINT"
	shape_definition.inventory_shape = [Vector2i.ZERO, Vector2i(0, 1)]
	shape_definition.can_rotate = true
	var image := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.68, 0.61, 0.46, 1.0))
	shape_definition.icon = ImageTexture.create_from_image(image)

	var hand_definition := ItemDefinition.new()
	hand_definition.id = &"field_ui_hand"
	hand_definition.display_name = "INVENTORY_NO_SELECTION"
	hand_definition.inventory_shape = [Vector2i.ZERO]
	hand_definition.equip_slots = [&"primary_hand"]

	var bag: ItemInstance = model.add_item(bag_definition, "bag")
	var shape: ItemInstance = model.add_item(shape_definition, "shape")
	var hand: ItemInstance = model.add_item(hand_definition, "hand_item")
	_check(bag != null and shape != null and hand != null, "field UI fixture creates inventory items")
	_check(model.equip("bag", &"back"), "field UI fixture equips bag")
	_check(model.equip("hand_item", &"primary_hand"), "field UI fixture equips hand item")
	_check(model.try_place("shape", "bag", Vector2i.ZERO, 0), "field UI fixture places rotatable item")


func _rectangle_cells(width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			result.append(Vector2i(x, y))
	return result


func _inside_viewport(control: Control) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var rect: Rect2 = control.get_global_rect()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and viewport_rect.encloses(rect)


func _equipment_button(slot: StringName) -> Button:
	var equipment_grid: GridContainer = view.get_node("%EquipmentGrid") as GridContainer
	var index: int = InventoryView.EQUIPMENT_SLOTS.find(slot)
	return equipment_grid.get_child(index) as Button if index >= 0 else null


func _cell_center(cell: Vector2i) -> Vector2:
	var dimensions := Vector2i(6, 5)
	var cell_size: float = maxf(18.0, minf(grid.size.x / float(dimensions.x), grid.size.y / float(dimensions.y)))
	var origin: Vector2 = grid.global_position + (grid.size - Vector2(dimensions) * cell_size) * 0.5
	return origin + Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5


func _mouse_click(position: Vector2) -> void:
	await _mouse_button(position, true)
	await _mouse_button(position, false)


func _mouse_button(position: Vector2, pressed: bool) -> void:
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
	return viewport_position * Vector2(get_window().size) / get_viewport().get_visible_rect().size


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
	for _index: int in range(count):
		await get_tree().process_frame


func _on_placement_requested(uid: String, container_uid: String, cell: Vector2i, rotation: int) -> void:
	placement_requests += 1
	model.try_place(uid, container_uid, cell, rotation)


func _on_close_requested() -> void:
	close_received = true


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
