extends Node

var checks: int = 0
var failures: int = 0
var grid := FieldInventoryGrid.new()


func _ready() -> void:
	_test_horizontal_contain()
	_test_vertical_contain()
	_test_transparent_padding_crop()
	_test_quarter_turn()
	_test_bounds_cache()
	print("INVENTORY_ICON_FIT_RESULT: %d checks, %d failures" % [checks, failures])
	grid.free()
	get_tree().quit(0 if failures == 0 else 1)


func _test_horizontal_contain() -> void:
	var texture := _texture_with_content(Vector2i(80, 30), Rect2i(0, 0, 80, 30))
	var target := Rect2(10.0, 20.0, 200.0, 100.0)
	var layout: Dictionary = grid.icon_draw_layout(texture, target, 0)
	var drawn: Rect2 = layout.target_rect
	_check(is_equal_approx(drawn.size.x / drawn.size.y, 80.0 / 30.0), "horizontal icon preserves aspect ratio")
	_check(target.encloses(drawn), "horizontal icon stays inside its footprint")
	_check(is_equal_approx(drawn.size.x, target.size.x - FieldInventoryGrid.ICON_INSET * 2.0), "horizontal icon covers the limiting width")


func _test_vertical_contain() -> void:
	var texture := _texture_with_content(Vector2i(24, 72), Rect2i(0, 0, 24, 72))
	var target := Rect2(0.0, 0.0, 90.0, 180.0)
	var layout: Dictionary = grid.icon_draw_layout(texture, target, 0)
	var drawn: Rect2 = layout.target_rect
	_check(is_equal_approx(drawn.size.x / drawn.size.y, 24.0 / 72.0), "vertical icon preserves aspect ratio")
	_check(target.encloses(drawn), "vertical icon stays inside its footprint")
	_check(is_equal_approx(drawn.size.y, target.size.y - FieldInventoryGrid.ICON_INSET * 2.0), "vertical icon covers the limiting height")


func _test_transparent_padding_crop() -> void:
	var content := Rect2i(20, 10, 40, 20)
	var texture := _texture_with_content(Vector2i(100, 60), content)
	var layout: Dictionary = grid.icon_draw_layout(texture, Rect2(0.0, 0.0, 120.0, 120.0), 0)
	_check(layout.source_rect == Rect2(content), "transparent padding is removed using the effective alpha bounds")
	_check(is_equal_approx((layout.target_rect as Rect2).size.x / (layout.target_rect as Rect2).size.y, 2.0), "cropped content aspect drives fitting")


func _test_quarter_turn() -> void:
	var texture := _texture_with_content(Vector2i(90, 30), Rect2i(0, 0, 90, 30))
	var target := Rect2(5.0, 8.0, 70.0, 190.0)
	var layout: Dictionary = grid.icon_draw_layout(texture, target, 1)
	var drawn: Rect2 = layout.target_rect
	_check(is_equal_approx(drawn.size.x / drawn.size.y, 30.0 / 90.0), "quarter turn swaps the visible aspect ratio")
	_check(target.encloses(drawn), "rotated icon stays inside the swapped footprint")
	_check(is_equal_approx(drawn.size.y, target.size.y - FieldInventoryGrid.ICON_INSET * 2.0), "rotated icon covers the limiting height")
	_check((layout.local_rect as Rect2).size.x > (layout.local_rect as Rect2).size.y, "rotation uses the original image geometry before transform")


func _test_bounds_cache() -> void:
	var texture := _texture_with_content(Vector2i(40, 40), Rect2i(5, 5, 10, 20))
	var scans_before: int = grid._alpha_bounds_scan_count
	grid.icon_draw_layout(texture, Rect2(0.0, 0.0, 100.0, 100.0), 0)
	grid.icon_draw_layout(texture, Rect2(0.0, 0.0, 200.0, 120.0), 1)
	_check(grid._alpha_bounds_scan_count == scans_before + 1, "repeated layout reuses one alpha scan per texture instance")
	var updated := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	updated.fill(Color.TRANSPARENT)
	updated.fill_rect(Rect2i(10, 8, 24, 8), Color.WHITE)
	texture.set_image(updated)
	_check(not grid._alpha_bounds_cache.has(texture.get_instance_id()), "texture changed removes its cached entry")
	var refreshed: Dictionary = grid.icon_draw_layout(texture, Rect2(0.0, 0.0, 100.0, 100.0), 0)
	_check(grid._alpha_bounds_scan_count == scans_before + 2, "texture changed invalidates the cached alpha bounds")
	_check(grid._alpha_bounds_cache.has(texture.get_instance_id()) and refreshed.source_rect.size.x > 0.0, "layout repopulates bounds after resource update")


func _texture_with_content(image_size: Vector2i, content: Rect2i) -> ImageTexture:
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(content, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
