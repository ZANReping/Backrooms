class_name ContainerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(1, 32) var grid_width: int = 6
@export_range(1, 32) var grid_height: int = 5
@export var blocked_cells: Array[Vector2i] = []
@export var allowed_tags: Array[StringName] = []


func is_valid() -> bool:
	if grid_width < 1 or grid_width > 32 or grid_height < 1 or grid_height > 32:
		return false
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in blocked_cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height or seen.has(cell):
			return false
		seen[cell] = true
	return blocked_cells.size() < grid_width * grid_height


func contains_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height and not blocked_cells.has(cell)
