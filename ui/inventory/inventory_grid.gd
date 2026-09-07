class_name InventoryGridView
extends Control

signal item_selected(uid: String)
signal placement_requested(uid: String, container_uid: String, cell: Vector2i, rotation: int)
signal item_rotated(uid: String)
signal external_hold_released(uid: String, global_position: Vector2)
signal recommended_equip_requested(uid: String, slot: StringName)
signal hold_started(uid: String)
signal hold_ended

const CELL_GAP: float = 3.0
const HOLD_SECONDS: float = 0.32

var model: InventoryModel
var container_uid: String = ""
var selected_uid: String = ""
var held_uid: String = ""
var held_rotation: int = 0
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _press_cell: Vector2i = Vector2i(-1, -1)
var _dragging: bool = false
var _press_uid: String = ""
var _press_elapsed: float = 0.0
var _press_active: bool = false
var _grab_offset: Vector2i = Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	set_process(false)


func _process(delta: float) -> void:
	if not _press_active or _press_uid.is_empty() or not held_uid.is_empty():
		return
	_press_elapsed += delta
	if _press_elapsed >= HOLD_SECONDS:
		begin_hold(_press_uid)
		_dragging = true
		queue_redraw()


func bind_inventory(inventory_model: InventoryModel, uid: String, selection: String) -> void:
	model = inventory_model
	container_uid = uid
	selected_uid = selection
	_cancel_hold()
	queue_redraw()


func set_selection(uid: String) -> void:
	selected_uid = uid
	queue_redraw()


func begin_hold(uid: String) -> void:
	if model == null or model.get_item(uid) == null:
		return
	selected_uid = uid
	held_uid = uid
	var placement: InventoryPlacement = model.get_placement(uid)
	held_rotation = placement.rotation if placement != null else 0
	if placement == null:
		_grab_offset = Vector2i.ZERO
	grab_focus()
	hold_started.emit(uid)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if model == null or container_uid.is_empty():
		return
	if event is InputEventMouseMotion:
		_hover_cell = _point_to_cell(event.position)
		if _dragging:
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			_press_cell = _point_to_cell(event.position)
			_press_uid = _item_at_cell(_press_cell)
			if not _press_uid.is_empty():
				var placement: InventoryPlacement = model.get_placement(_press_uid)
				_grab_offset = _press_cell - placement.cell if placement != null else Vector2i.ZERO
			_press_elapsed = 0.0
			_press_active = not _press_uid.is_empty()
			set_process(_press_active)
		else:
			if _dragging and not held_uid.is_empty():
				var release_cell: Vector2i = _point_to_cell(event.position)
				if release_cell == Vector2i(-1, -1):
					external_hold_released.emit(held_uid, get_global_transform_with_canvas() * event.position)
				else:
					_request_current_placement(release_cell - _grab_offset)
			elif _press_active and not _press_uid.is_empty():
				_select_only(_press_uid)
			_press_cell = Vector2i(-1, -1)
			_press_uid = ""
			_press_active = false
			_press_elapsed = 0.0
			_dragging = false
			held_uid = ""
			hold_ended.emit()
			set_process(false)
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var uid: String = _item_at_cell(_point_to_cell(event.position))
		var item: ItemInstance = model.get_item(uid)
		if not uid.is_empty() and uid == selected_uid and item != null and item.definition.equip_slot != &"":
			recommended_equip_requested.emit(uid, item.definition.equip_slot)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and ((InputMap.has_action(&"inventory_rotate") and event.is_action_pressed(&"inventory_rotate")) or (not InputMap.has_action(&"inventory_rotate") and event.physical_keycode == KEY_R)):
		if not held_uid.is_empty():
			var item: ItemInstance = model.get_item(held_uid)
			if item != null and item.definition.can_rotate:
				var old_bounds: Vector2i = _shape_bounds(model.get_cells(held_uid, held_rotation))
				_grab_offset = Vector2i(old_bounds.y - 1 - _grab_offset.y, _grab_offset.x)
				held_rotation = (held_rotation + 1) % 4
				item_rotated.emit(held_uid)
				queue_redraw()
			accept_event()


func _draw() -> void:
	if model == null or container_uid.is_empty():
		return
	var container: ContainerInstance = model.get_container(container_uid)
	if container == null or container.definition == null:
		return
	var dimensions := Vector2i(container.definition.grid_width, container.definition.grid_height)
	var geometry: Dictionary = _grid_geometry(dimensions)
	var origin: Vector2 = geometry.origin
	var cell_size: float = geometry.cell_size
	var blocked: Array[Vector2i] = container.definition.blocked_cells
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * (cell_size - CELL_GAP))
			var fill := Color(0.12, 0.13, 0.14, 0.94)
			if cell in blocked:
				fill = Color(0.055, 0.06, 0.065, 0.98)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.3, 0.32, 0.34, 0.8), false, 1.0)
	for placement: InventoryPlacement in container.placements:
		_draw_item(placement, origin, cell_size)
	if not held_uid.is_empty() and _inside_grid(_hover_cell, dimensions):
		_draw_preview(origin, cell_size)


func _draw_item(placement: InventoryPlacement, origin: Vector2, cell_size: float) -> void:
	var item: ItemInstance = model.get_item(placement.item_id)
	if item == null or item.definition == null:
		return
	var color: Color = item.definition.color
	if placement.item_id == selected_uid:
		color = color.lightened(0.18)
	if placement.item_id == held_uid:
		color.a = 0.35
	for offset: Vector2i in model.get_cells(placement.item_id, placement.rotation):
		var cell: Vector2i = placement.cell + offset
		var rect := Rect2(origin + Vector2(cell) * cell_size + Vector2.ONE * 2.0, Vector2.ONE * (cell_size - CELL_GAP - 4.0))
		draw_rect(rect, color, true)
		draw_rect(rect, color.lightened(0.28), false, 2.0)
	var bounds := _shape_bounds(model.get_cells(placement.item_id, placement.rotation))
	var label_pos: Vector2 = origin + Vector2(placement.cell) * cell_size + Vector2(7.0, minf(cell_size * float(bounds.y), 24.0))
	draw_string(get_theme_default_font(), label_pos, tr(item.definition.display_name), HORIZONTAL_ALIGNMENT_LEFT, cell_size * float(bounds.x) - 10.0, get_theme_default_font_size(), Color.WHITE)


func _draw_preview(origin: Vector2, cell_size: float) -> void:
	var legal: bool = model.can_place(held_uid, container_uid, _hover_cell, held_rotation)
	var color := Color(0.22, 0.85, 0.48, 0.58) if legal else Color(0.95, 0.22, 0.2, 0.65)
	for offset: Vector2i in model.get_cells(held_uid, held_rotation):
		var rect := Rect2(origin + Vector2(_hover_cell + offset) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - CELL_GAP - 2.0))
		draw_rect(rect, color, true)
		draw_rect(rect, color.lightened(0.25), false, 2.0)


func _select_only(uid: String) -> void:
	selected_uid = uid
	item_selected.emit(uid)
	queue_redraw()


func finish_external_hold(global_position: Vector2) -> void:
	if held_uid.is_empty():
		return
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_position
	_request_current_placement(_point_to_cell(local_position))
	held_uid = ""
	_dragging = false
	hold_ended.emit()
	queue_redraw()


func cancel_interaction() -> void:
	_cancel_hold()
	queue_redraw()


func _request_current_placement(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		return
	placement_requested.emit(held_uid, container_uid, cell, held_rotation)


func _cancel_hold() -> void:
	held_uid = ""
	_dragging = false
	_press_cell = Vector2i(-1, -1)
	_press_uid = ""
	_press_active = false
	_press_elapsed = 0.0
	set_process(false)


func _point_to_cell(point: Vector2) -> Vector2i:
	var container: ContainerInstance = model.get_container(container_uid)
	if container == null or container.definition == null:
		return Vector2i(-1, -1)
	var dimensions := Vector2i(container.definition.grid_width, container.definition.grid_height)
	var geometry: Dictionary = _grid_geometry(dimensions)
	var local: Vector2 = point - geometry.origin
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var cell := Vector2i(floori(local.x / geometry.cell_size), floori(local.y / geometry.cell_size))
	return cell if _inside_grid(cell, dimensions) else Vector2i(-1, -1)


func _item_at_cell(cell: Vector2i) -> String:
	if cell == Vector2i(-1, -1):
		return ""
	var container: ContainerInstance = model.get_container(container_uid)
	if container == null:
		return ""
	for placement: InventoryPlacement in container.placements:
		for offset: Vector2i in model.get_cells(placement.item_id, placement.rotation):
			if placement.cell + offset == cell:
				return placement.item_id
	return ""


func _grid_geometry(dimensions: Vector2i) -> Dictionary:
	var cell_size: float = maxf(18.0, minf(size.x / float(maxi(1, dimensions.x)), size.y / float(maxi(1, dimensions.y))))
	var grid_size := Vector2(dimensions) * cell_size
	return {&"cell_size": cell_size, &"origin": (size - grid_size) * 0.5}


func _inside_grid(cell: Vector2i, dimensions: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y


func _shape_bounds(cells: Array[Vector2i]) -> Vector2i:
	var maximum := Vector2i.ONE
	for cell: Vector2i in cells:
		maximum.x = maxi(maximum.x, cell.x + 1)
		maximum.y = maxi(maximum.y, cell.y + 1)
	return maximum
