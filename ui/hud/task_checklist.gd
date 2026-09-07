class_name TaskChecklist
extends VBoxContainer

const COMPLETE_HOLD_SECONDS: float = 1.0
const FADE_SECONDS: float = 0.22

var _task_id: StringName = &""
var _title_label: Label
var _rows: Dictionary = {}
var _known_completed: Dictionary = {}
var _tweens: Array[Tween] = []
var _row_tweens: Dictionary = {}


func _ready() -> void:
	custom_minimum_size.x = 280.0
	add_theme_constant_override(&"separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_title()


func set_task(task_id: StringName, title: String, entries: Array[Dictionary]) -> void:
	_ensure_title()
	if task_id != _task_id:
		_clear_task()
		_task_id = task_id
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	var present: Dictionary = {}
	for entry: Dictionary in entries:
		var entry_id := StringName(entry.get("id", &""))
		if entry_id == &"":
			continue
		present[entry_id] = true
		var completed := bool(entry.get("completed", false))
		if completed:
			if _rows.has(entry_id):
				_complete_row(entry_id)
			else:
				_known_completed[entry_id] = true
			continue
		if _known_completed.has(entry_id):
			_known_completed.erase(entry_id)
			_cancel_row_tween(entry_id)
		if not _rows.has(entry_id):
			_rows[entry_id] = _make_row(entry)
		else:
			var wrapper := _rows[entry_id] as Control
			wrapper.modulate.a = 1.0
			wrapper.custom_minimum_size.y = 22.0
			_update_row(wrapper.get_child(0) as RichTextLabel, entry)
	for entry_id: Variant in _rows.keys():
		if not present.has(entry_id):
			_remove_row(StringName(entry_id))


func _ensure_title() -> void:
	if is_instance_valid(_title_label):
		return
	_title_label = Label.new()
	_title_label.add_theme_font_size_override(&"font_size", 16)
	_title_label.add_theme_color_override(&"font_color", Color("f1f0eb"))
	_title_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.82))
	_title_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_title_label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(_title_label)


func _make_row(entry: Dictionary) -> Control:
	var wrapper := Control.new()
	wrapper.name = "Task_%s" % String(entry.get("id", &""))
	wrapper.custom_minimum_size = Vector2(280.0, 22.0)
	wrapper.clip_contents = true
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := RichTextLabel.new()
	row.bbcode_enabled = true
	row.scroll_active = false
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override(&"normal_font_size", 14)
	row.add_theme_color_override(&"default_color", Color("deddd7"))
	row.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.78))
	row.add_theme_constant_override(&"shadow_offset_x", 1)
	row.add_theme_constant_override(&"shadow_offset_y", 1)
	_update_row(row, entry)
	wrapper.add_child(row)
	add_child(wrapper)
	return wrapper


func _update_row(row: RichTextLabel, entry: Dictionary) -> void:
	var suffix := "  [color=#aaa79f]（可选）[/color]" if bool(entry.get("optional", false)) else ""
	row.text = "□ %s%s" % [_escape_bbcode(String(entry.get("text", ""))), suffix]


func _complete_row(entry_id: StringName) -> void:
	if _known_completed.has(entry_id) or not _rows.has(entry_id):
		return
	_known_completed[entry_id] = true
	var wrapper := _rows[entry_id] as Control
	var row := wrapper.get_child(0) as RichTextLabel
	row.text = "[s]%s[/s]" % row.text.replace("□", "✓")
	var tween := create_tween()
	_tweens.append(tween)
	_row_tweens[entry_id] = tween
	tween.tween_interval(COMPLETE_HOLD_SECONDS)
	tween.tween_property(wrapper, "modulate:a", 0.0, FADE_SECONDS)
	tween.parallel().tween_property(wrapper, "custom_minimum_size:y", 0.0, FADE_SECONDS)
	tween.tween_callback(_remove_row.bind(entry_id))


func _remove_row(entry_id: StringName) -> void:
	if not _rows.has(entry_id):
		return
	_cancel_row_tween(entry_id)
	var row := _rows[entry_id] as Control
	_rows.erase(entry_id)
	if is_instance_valid(row):
		remove_child(row)
		row.queue_free()


func _cancel_row_tween(entry_id: StringName) -> void:
	if not _row_tweens.has(entry_id):
		return
	var tween := _row_tweens[entry_id] as Tween
	_row_tweens.erase(entry_id)
	if tween != null and tween.is_valid():
		tween.kill()


func _clear_task() -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_row_tweens.clear()
	for row: Variant in _rows.values():
		if is_instance_valid(row):
			(row as Node).queue_free()
	_rows.clear()
	_known_completed.clear()


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")
