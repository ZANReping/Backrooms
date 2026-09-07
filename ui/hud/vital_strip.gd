class_name VitalStrip
extends Control

const LABELS: Dictionary = {
	&"health": "健康",
	&"stamina": "体力",
	&"hunger": "饱腹",
	&"thirst": "水分",
	&"sanity": "理智",
	&"fatigue": "疲劳",
}
const COLORS: Dictionary = {
	&"health": Color("a65353"),
	&"stamina": Color("718879"),
	&"hunger": Color("b89b5d"),
	&"thirst": Color("718b9d"),
	&"sanity": Color("81788f"),
	&"fatigue": Color("9a7b69"),
}

var _stat_id: StringName = &"health"
var _value: float = 0.0
var _maximum: float = 1.0
var _ratio: float = 0.0
var _immersive: bool = false
var _name_label: Label
var _value_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(230.0, 24.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = Label.new()
	_name_label.position = Vector2(5.0, 1.0)
	_name_label.size = Vector2(48.0, 22.0)
	_name_label.add_theme_font_size_override(&"font_size", 14)
	_name_label.add_theme_color_override(&"font_color", Color("eef0ec"))
	_name_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_name_label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(_name_label)
	_value_label = Label.new()
	_value_label.position = Vector2(174.0, 1.0)
	_value_label.size = Vector2(51.0, 22.0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.add_theme_font_size_override(&"font_size", 14)
	_value_label.add_theme_color_override(&"font_color", Color("eef0ec"))
	_value_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_value_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_value_label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(_value_label)
	_refresh_labels()


func set_state(stat_id: StringName, value: float, maximum: float, immersive: bool) -> void:
	_stat_id = stat_id if LABELS.has(stat_id) else &"health"
	_value = value
	_maximum = maxf(maximum, 0.0)
	_ratio = clampf(value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_immersive = immersive
	_refresh_labels()
	queue_redraw()


func _refresh_labels() -> void:
	if not is_instance_valid(_name_label):
		return
	_name_label.text = String(LABELS[_stat_id])
	_value_label.text = "%d" % roundi(_value)
	_value_label.visible = not _immersive


func _draw() -> void:
	var track := Rect2(56.0, 7.0, 112.0, 10.0)
	var shadow := track.grow(2.0)
	shadow.position += Vector2(1.0, 1.0)
	draw_rect(shadow, Color(0, 0, 0, 0.45), true)
	draw_rect(track, Color(0.055, 0.065, 0.065, 0.92), true)
	var fill_width := floorf(track.size.x * _ratio)
	if fill_width > 0.0:
		draw_rect(Rect2(track.position, Vector2(fill_width, track.size.y)), COLORS[_stat_id], true)
	for index: int in range(1, 8):
		var x := track.position.x + floorf(track.size.x * float(index) / 8.0)
		draw_line(Vector2(x, track.position.y), Vector2(x, track.end.y), Color(0.05, 0.06, 0.06, 0.55), 1.0)
	draw_rect(track, Color(0.03, 0.035, 0.035, 0.95), false, 1.0)
