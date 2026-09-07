class_name FieldInventoryGrid
extends InventoryGridView

const GRID_LINE := Color(0.29, 0.31, 0.32, 0.55)
const BLOCKED_COLOR := Color(0.025, 0.027, 0.028, 0.9)
const ITEM_OUTLINE := Color(0.65, 0.69, 0.7, 0.3)
const SELECTED_OUTLINE := Color(0.83, 0.92, 0.93, 0.72)
const ICON_INSET: float = 4.0
const ALPHA_THRESHOLD: float = 0.01

var _alpha_bounds_cache: Dictionary[int, Dictionary] = {}
var _alpha_bounds_scan_count: int = 0


func _exit_tree() -> void:
	for texture_id: int in _alpha_bounds_cache:
		var texture: Texture2D = (_alpha_bounds_cache[texture_id].texture as WeakRef).get_ref() as Texture2D
		var callback := _invalidate_alpha_bounds.bind(texture_id)
		if texture != null and texture.changed.is_connected(callback):
			texture.changed.disconnect(callback)
	_alpha_bounds_cache.clear()


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
	_draw_grid(origin, dimensions, cell_size)
	for blocked_cell: Vector2i in container.definition.blocked_cells:
		var blocked_rect := Rect2(origin + Vector2(blocked_cell) * cell_size + Vector2.ONE * 3.0, Vector2.ONE * (cell_size - 6.0))
		draw_rect(blocked_rect, BLOCKED_COLOR, true)
		draw_line(blocked_rect.position, blocked_rect.end, GRID_LINE, 1.0)
	for placement: InventoryPlacement in container.placements:
		_draw_item(placement, origin, cell_size)
	if not held_uid.is_empty() and _inside_grid(_hover_cell, dimensions):
		_draw_preview(origin, cell_size)


func _draw_grid(origin: Vector2, dimensions: Vector2i, cell_size: float) -> void:
	var grid_size := Vector2(dimensions) * cell_size
	draw_rect(Rect2(origin, grid_size), Color(0.065, 0.07, 0.073, 0.92), true)
	for x: int in range(dimensions.x + 1):
		var px: float = origin.x + float(x) * cell_size
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + grid_size.y), GRID_LINE, 1.0)
	for y: int in range(dimensions.y + 1):
		var py: float = origin.y + float(y) * cell_size
		draw_line(Vector2(origin.x, py), Vector2(origin.x + grid_size.x, py), GRID_LINE, 1.0)


func _draw_item(placement: InventoryPlacement, origin: Vector2, cell_size: float) -> void:
	var item: ItemInstance = model.get_item(placement.item_id)
	if item == null or item.definition == null:
		return
	var cells: Array[Vector2i] = model.get_cells(placement.item_id, placement.rotation)
	var bounds: Vector2i = _shape_bounds(cells)
	var item_rect := Rect2(origin + Vector2(placement.cell) * cell_size + Vector2.ONE * 5.0, Vector2(bounds) * cell_size - Vector2.ONE * 10.0)
	if item.definition.icon != null:
		_draw_rotated_icon(item.definition.icon, item_rect, placement.rotation, placement.item_id == held_uid)
	else:
		_draw_missing_icon(item_rect, cells, placement.cell, origin, cell_size, placement.item_id == held_uid)
	var outline: Color = SELECTED_OUTLINE if placement.item_id == selected_uid else ITEM_OUTLINE
	if placement.item_id == held_uid:
		outline.a = 0.45
	_draw_shape_outline(cells, placement.cell, origin, cell_size, outline, 1.5 if placement.item_id == selected_uid else 1.0)


func _draw_shape_outline(cells: Array[Vector2i], placement_cell: Vector2i, origin: Vector2, cell_size: float, color: Color, width: float) -> void:
	var occupied: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		occupied[cell] = true
	for cell: Vector2i in cells:
		var top_left: Vector2 = origin + Vector2(placement_cell + cell) * cell_size + Vector2.ONE * 4.0
		var bottom_right: Vector2 = top_left + Vector2.ONE * (cell_size - 8.0)
		if not occupied.has(cell + Vector2i.UP):
			draw_line(top_left, Vector2(bottom_right.x, top_left.y), color, width)
		if not occupied.has(cell + Vector2i.RIGHT):
			draw_line(Vector2(bottom_right.x, top_left.y), bottom_right, color, width)
		if not occupied.has(cell + Vector2i.DOWN):
			draw_line(bottom_right, Vector2(top_left.x, bottom_right.y), color, width)
		if not occupied.has(cell + Vector2i.LEFT):
			draw_line(Vector2(top_left.x, bottom_right.y), top_left, color, width)


func _draw_rotated_icon(texture: Texture2D, rect: Rect2, rotation_steps: int, held: bool) -> void:
	var tint := Color(1.0, 1.0, 1.0, 0.38 if held else 1.0)
	var layout: Dictionary = icon_draw_layout(texture, rect, rotation_steps)
	if (layout.source_rect as Rect2).size.is_zero_approx():
		return
	var radians: float = float(layout.rotation_steps) * PI * 0.5
	draw_set_transform(rect.get_center(), radians)
	draw_texture_rect_region(texture, layout.local_rect, layout.source_rect, tint)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_preview(origin: Vector2, cell_size: float) -> void:
	super(origin, cell_size)
	var item: ItemInstance = model.get_item(held_uid)
	if item == null or item.definition == null or item.definition.icon == null:
		return
	var cells: Array[Vector2i] = model.get_cells(held_uid, held_rotation)
	var bounds: Vector2i = _shape_bounds(cells)
	var preview_rect := Rect2(origin + Vector2(_hover_cell) * cell_size + Vector2.ONE * 5.0, Vector2(bounds) * cell_size - Vector2.ONE * 10.0)
	_draw_rotated_icon(item.definition.icon, preview_rect, held_rotation, true)


func icon_draw_layout(texture: Texture2D, target_rect: Rect2, rotation_steps: int) -> Dictionary:
	var normalized_rotation: int = posmod(rotation_steps, 4)
	var source_rect: Rect2 = _cached_alpha_bounds(texture)
	if source_rect.size.is_zero_approx():
		return {&"source_rect": source_rect, &"local_rect": Rect2(), &"rotation_steps": normalized_rotation}
	var available_size: Vector2 = (target_rect.size - Vector2.ONE * ICON_INSET * 2.0).max(Vector2.ONE)
	var rotated_source_size: Vector2 = source_rect.size
	if normalized_rotation % 2 == 1:
		rotated_source_size = Vector2(rotated_source_size.y, rotated_source_size.x)
	var scale_factor: float = minf(available_size.x / rotated_source_size.x, available_size.y / rotated_source_size.y)
	var rotated_draw_size: Vector2 = rotated_source_size * scale_factor
	var local_size: Vector2 = rotated_draw_size
	if normalized_rotation % 2 == 1:
		local_size = Vector2(rotated_draw_size.y, rotated_draw_size.x)
	return {
		&"source_rect": source_rect,
		&"local_rect": Rect2(-local_size * 0.5, local_size),
		&"rotation_steps": normalized_rotation,
		&"rotated_size": rotated_draw_size,
		&"target_rect": Rect2(target_rect.get_center() - rotated_draw_size * 0.5, rotated_draw_size),
	}


func _cached_alpha_bounds(texture: Texture2D) -> Rect2:
	var texture_id: int = texture.get_instance_id()
	if _alpha_bounds_cache.has(texture_id):
		var cached_texture: Texture2D = (_alpha_bounds_cache[texture_id].texture as WeakRef).get_ref() as Texture2D
		if cached_texture == texture:
			return _alpha_bounds_cache[texture_id].bounds
		_alpha_bounds_cache.erase(texture_id)
	var bounds := alpha_bounds(texture.get_image())
	_alpha_bounds_scan_count += 1
	_alpha_bounds_cache[texture_id] = {&"texture": weakref(texture), &"bounds": bounds}
	var callback := _invalidate_alpha_bounds.bind(texture_id)
	if not texture.changed.is_connected(callback):
		texture.changed.connect(callback)
	return bounds


func _invalidate_alpha_bounds(texture_id: int) -> void:
	_alpha_bounds_cache.erase(texture_id)


static func alpha_bounds(image: Image) -> Rect2:
	if image == null or image.is_empty():
		return Rect2()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2()
	return Rect2(Vector2(minimum), Vector2(maximum - minimum + Vector2i.ONE))


func _draw_missing_icon(rect: Rect2, cells: Array[Vector2i], placement_cell: Vector2i, origin: Vector2, cell_size: float, held: bool) -> void:
	var fill := Color(0.27, 0.24, 0.18, 0.35 if held else 0.72)
	for offset: Vector2i in cells:
		var cell_rect := Rect2(origin + Vector2(placement_cell + offset) * cell_size + Vector2.ONE * 7.0, Vector2.ONE * (cell_size - 14.0))
		draw_rect(cell_rect, fill, true)
	draw_line(rect.position + Vector2(5.0, 5.0), rect.end - Vector2(5.0, 5.0), Color(0.75, 0.7, 0.55, fill.a), 1.0)
	draw_line(Vector2(rect.end.x - 5.0, rect.position.y + 5.0), Vector2(rect.position.x + 5.0, rect.end.y - 5.0), Color(0.75, 0.7, 0.55, fill.a), 1.0)
