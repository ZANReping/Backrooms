class_name CameraOverlay
extends Control

var _flash: float = 0.0
var _status: Label
var _battery: Label
var _feedback_remaining: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	ui_font.font_weight = 400
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_status.offset_left = -320
	_status.offset_right = 320
	_status.offset_top = -48
	_status.offset_bottom = -18
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = tr(&"CAMERA_CONTROLS")
	_status.add_theme_font_size_override(&"font_size", 16)
	_status.add_theme_font_override(&"font", ui_font)
	_status.add_theme_color_override(&"font_color", Color(0.93, 0.95, 0.95, 0.9))
	add_child(_status)
	_battery = Label.new()
	_battery.position = Vector2(28, 22)
	_battery.add_theme_font_size_override(&"font_size", 16)
	_battery.add_theme_font_override(&"font", ui_font)
	add_child(_battery)
	resized.connect(queue_redraw)
	visibility_changed.connect(func() -> void:
		if visible:
			_feedback_remaining = 0.0
			_flash = 0.0
			_status.text = tr(&"CAMERA_CONTROLS")
			queue_redraw())
	visible = false


func set_charge(percent: float, offline: bool) -> void:
	_battery.text = "%s   %d%%   ·   %s" % [tr(&"CAMERA_MODE_PHOTO"), roundi(percent), tr(&"CAMERA_LOCAL" if offline else &"CAMERA_READY")]


func shutter_feedback(success: bool) -> void:
	_flash = 0.1 if success else 0.0
	_feedback_remaining = 1.8 if success else 3.0
	_status.text = tr(&"CAMERA_SAVED" if success else &"PRO_PHOTO_FAILED")
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if _feedback_remaining > 0.0:
		_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
		if _feedback_remaining == 0.0:
			_status.text = tr(&"CAMERA_CONTROLS")
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func _draw() -> void:
	# The live image is the main 3D viewport below this overlay, not a screenshot.
	# Small edge scrims keep controls readable without framing out the scene.
	for strip: int in 72:
		var fade: float = float(72 - strip) / 72.0
		draw_rect(Rect2(0, strip, size.x, 1), Color(0.02, 0.022, 0.024, fade * 0.42))
		draw_rect(Rect2(0, size.y - strip - 1, size.x, 1), Color(0.02, 0.022, 0.024, fade * 0.62))
	var frame := Rect2(24, 74, size.x - 48, size.y - 148)
	var faint := Color(1, 1, 1, 0.11)
	for index: int in [1, 2]:
		var x: float = frame.position.x + frame.size.x * index / 3.0
		var y: float = frame.position.y + frame.size.y * index / 3.0
		draw_line(Vector2(x, frame.position.y), Vector2(x, frame.end.y), faint)
		draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), faint)
	var center := size * 0.5
	var focus_color := Color(1, 1, 1, 0.32)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var point := center + corner * 23.0
		draw_line(point, point - Vector2(corner.x * 8, 0), focus_color, 1.0)
		draw_line(point, point - Vector2(0, corner.y * 8), focus_color, 1.0)
	var shutter := Vector2(size.x - 56, size.y * 0.5)
	draw_circle(shutter, 33, Color(0.02, 0.022, 0.024, 0.22), true, -1, true)
	draw_circle(shutter, 28, Color(0.98, 0.98, 0.97, 0.95), false, 2, true)
	draw_circle(shutter, 23, Color(0.98, 0.98, 0.97, 0.9), true, -1, true)
	if _flash > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 1.8))
