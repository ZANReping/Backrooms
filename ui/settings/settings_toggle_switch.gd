class_name SettingsToggleSwitch
extends BaseButton

const TRACK_OFF := Color("353b3c")
const TRACK_ON := Color("526f70")
const TRACK_EDGE := Color("748081")
const TRACK_EDGE_ON := Color("8fb0b0")
const KNOB_OFF := Color("c4caca")
const KNOB_ON := Color("f1f4f4")
const FOCUS := Color("b4cccc")


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(60, 36)
	toggled.connect(func(_value: bool) -> void: queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var center_y := size.y * 0.5
	var left := 7.0
	var right := size.x - 7.0
	var outer_radius := 11.0
	var inner_radius := 10.0
	var edge := TRACK_EDGE_ON if button_pressed else TRACK_EDGE
	var fill := TRACK_ON if button_pressed else TRACK_OFF
	_draw_pill(left, right, center_y, outer_radius, edge)
	_draw_pill(left + 1.0, right - 1.0, center_y, inner_radius, fill)
	var knob_x := right - outer_radius if button_pressed else left + outer_radius
	draw_circle(Vector2(knob_x, center_y), 8.0, KNOB_ON if button_pressed else KNOB_OFF, true, -1.0, true)
	if has_focus():
		draw_arc(Vector2(left + outer_radius, center_y), outer_radius + 2.5, PI * 0.5, PI * 1.5, 20, FOCUS, 1.0, true)
		draw_arc(Vector2(right - outer_radius, center_y), outer_radius + 2.5, -PI * 0.5, PI * 0.5, 20, FOCUS, 1.0, true)
		draw_line(Vector2(left + outer_radius, center_y - outer_radius - 2.5), Vector2(right - outer_radius, center_y - outer_radius - 2.5), FOCUS, 1.0, true)
		draw_line(Vector2(left + outer_radius, center_y + outer_radius + 2.5), Vector2(right - outer_radius, center_y + outer_radius + 2.5), FOCUS, 1.0, true)


func _draw_pill(left: float, right: float, center_y: float, radius: float, color: Color) -> void:
	draw_rect(Rect2(left + radius, center_y - radius, right - left - radius * 2.0, radius * 2.0), color)
	draw_circle(Vector2(left + radius, center_y), radius, color, true, -1.0, true)
	draw_circle(Vector2(right - radius, center_y), radius, color, true, -1.0, true)
