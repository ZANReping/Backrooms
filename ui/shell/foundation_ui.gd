class_name FoundationUI
extends CanvasLayer

signal new_game_requested(difficulty: int)
signal resume_requested
signal save_requested
signal load_requested
signal menu_requested
signal settings_changed(immersive: bool, headbob: bool)
signal preference_changed(key: StringName, value: Variant)
signal restore_preferences_requested
signal debug_give_requested(definition_id: StringName)
signal debug_reload_requested
signal debug_travel_requested
signal debug_damage_requested
signal phone_send_requested(text: String)
signal close_requested

const STAT_IDS: Array[StringName] = [
	&"health", &"stamina", &"hunger", &"thirst", &"sanity", &"fatigue"
]
const STAT_KEYS: Dictionary = {
	&"health": "SHELL_STAT_HEALTH", &"stamina": "SHELL_STAT_STAMINA",
	&"hunger": "SHELL_STAT_HUNGER", &"thirst": "SHELL_STAT_THIRST",
	&"sanity": "SHELL_STAT_SANITY", &"fatigue": "SHELL_STAT_FATIGUE",
}
const APP_KEYS: Dictionary = {
	&"chat": "SHELL_PHONE_CHAT", &"maps": "SHELL_PHONE_MAPS",
	&"browser": "SHELL_PHONE_BROWSER", &"phone": "SHELL_PHONE_CALLS",
	&"camera": "SHELL_PHONE_CAMERA", &"clock": "SHELL_PHONE_CLOCK",
}

@onready var root: Control = $Root

var _panels: Dictionary[StringName, Control] = {}
var _side_panel_footers: Dictionary[StringName, VBoxContainer] = {}
var _stat_labels: Dictionary[StringName, Label] = {}
var _stat_icons: Dictionary[StringName, TextureRect] = {}
var _stat_values: Dictionary[StringName, Label] = {}
var _stat_rows: Dictionary[StringName, Control] = {}
var _stat_visible_until: Dictionary[StringName, float] = {}
var _stat_last_attention_value: Dictionary[StringName, float] = {}
var _stats: PlayerStats
var _phone_state: PhoneState
var _charge_state: ChargeState
var _immersive: bool = true
var _headbob: bool = true
var _dynamic_crosshair: DynamicCrosshair
var _save_available: bool = false
var _world_time: String = "--:--"
var _interaction_label: Label
var _notification_label: Label
var _notification_timer: Timer
var _notification_tween: Tween
var _notification_overlay: Control
var _notification_panel: PanelContainer
var _held_item_label: Label
var _controls_hint_label: Label
var _controls_hint_enabled: bool = true
var _load_buttons: Array[Button] = []
var _debug_values: Dictionary[StringName, Label] = {}
var _debug_items: OptionButton
var _phone_title: Label
var _phone_title_icon: TextureRect
var _phone_content: VBoxContainer
var _phone_input: LineEdit
var _phone_send: Button
var _immersive_toggle: CheckButton
var _headbob_toggle: CheckButton
var _death_cause: Label
var _death_load: Button
var _death_no_revive: Label
var _manual_save_button: Button
var _clock_label: Label


func _ready() -> void:
	_build_hud()
	_build_notification_layer()
	_build_menu()
	_build_pause()
	_build_debug()
	_build_phone()
	_build_death()
	set_save_available(_save_available)
	_notification_overlay.move_to_front()
	set_mode(&"menu")
	set_process(true)


func _process(_delta: float) -> void:
	pass


func set_mode(mode: StringName) -> void:
	for panel: Control in _panels.values():
		panel.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match mode:
		&"menu", &"pause", &"phone", &"dead":
			var selected: Control = _panels.get(mode)
			if is_instance_valid(selected):
				selected.visible = true
				root.mouse_filter = Control.MOUSE_FILTER_PASS
		&"debug":
			if Settings.developer_mode:
				_panels[&"debug"].visible = true
				root.mouse_filter = Control.MOUSE_FILTER_PASS
		&"play":
			_panels[&"hud"].visible = true
		&"inventory":
			pass


func set_interaction(text: String) -> void:
	if is_instance_valid(_dynamic_crosshair):
		_dynamic_crosshair.focused = not text.is_empty()
	_interaction_label.text = text
	_interaction_label.visible = not text.is_empty()


func notify(text: String) -> void:
	_show_notification(text, 3.0)


func _show_notification(text: String, hold_seconds: float) -> void:
	if _notification_tween != null and _notification_tween.is_valid():
		_notification_tween.kill()
	_notification_timer.stop()
	_notification_label.text = text
	if text.is_empty():
		_notification_panel.hide()
		_notification_panel.modulate.a = 0.0
		return
	_notification_panel.show()
	_notification_panel.modulate.a = 0.0
	_notification_tween = create_tween()
	_notification_tween.tween_property(_notification_panel, "modulate:a", 1.0, 0.18)
	_notification_tween.tween_interval(maxf(0.0, hold_seconds))
	_notification_tween.tween_property(_notification_panel, "modulate:a", 0.0, 0.28)
	_notification_tween.tween_callback(_notification_panel.hide)


func set_held_item(text: String) -> void:
	_held_item_label.text = text
	_held_item_label.visible = not text.is_empty()


func set_controls_hint(text: String) -> void:
	_controls_hint_label.text = text
	_controls_hint_label.visible = _controls_hint_enabled and not text.is_empty()


func set_controls_hint_enabled(enabled: bool) -> void:
	_controls_hint_enabled = enabled
	if is_instance_valid(_controls_hint_label):
		_controls_hint_label.visible = enabled and not _controls_hint_label.text.is_empty()


func set_stats(stats: PlayerStats) -> void:
	if is_instance_valid(_stats) and _stats.stat_changed.is_connected(_on_stat_changed):
		_stats.stat_changed.disconnect(_on_stat_changed)
	_stats = stats
	if is_instance_valid(_stats):
		_stats.stat_changed.connect(_on_stat_changed)
		for stat_id: StringName in STAT_IDS:
			_on_stat_changed(stat_id, _stats.get_value(stat_id), _stats.get_maximum(stat_id))


func set_preferences(immersive: bool, headbob: bool) -> void:
	_immersive = immersive
	_headbob = headbob
	if is_instance_valid(_immersive_toggle):
		_immersive_toggle.set_pressed_no_signal(immersive)
	if is_instance_valid(_headbob_toggle):
		_headbob_toggle.set_pressed_no_signal(headbob)
	for stat_id: StringName in STAT_IDS:
		_redraw_stat(stat_id)
		_update_stat_visibility(stat_id)


func update_debug(data: Dictionary) -> void:
	for field: StringName in [&"scene", &"position", &"fps", &"seed", &"flags", &"stats", &"weight"]:
		if data.has(field) and _debug_values.has(field):
			_debug_values[field].text = str(data[field])
	if data.has("world_time"):
		var next_world_time: String = str(data["world_time"])
		if next_world_time != _world_time:
			_world_time = next_world_time
			if is_instance_valid(_clock_label):
				_clock_label.text = _world_time


func show_death(cause: String, difficulty: int) -> void:
	_death_cause.text = "%s: %s" % [tr("SHELL_DEATH_CAUSE"), cause]
	_death_load.visible = difficulty != 2
	_death_load.disabled = not _save_available
	_death_no_revive.visible = difficulty == 2
	set_mode(&"dead")


func set_item_catalog(items: Array[ItemDefinition]) -> void:
	_debug_items.clear()
	for item: ItemDefinition in items:
		_debug_items.add_item(tr(item.display_name))
		_debug_items.set_item_metadata(_debug_items.item_count - 1, item.id)


func bind_phone(state: PhoneState, charge: ChargeState) -> void:
	if is_instance_valid(_phone_state) and _phone_state.changed.is_connected(_refresh_phone):
		_phone_state.changed.disconnect(_refresh_phone)
	_phone_state = state
	_charge_state = charge
	if is_instance_valid(_phone_state):
		_phone_state.changed.connect(_refresh_phone)
	refresh_phone_charge()
	_refresh_phone_app(_phone_state.active_app if is_instance_valid(_phone_state) else &"chat")


func refresh_phone_charge() -> void:
	var current: float = 0.0
	var maximum: float = 0.0
	if is_instance_valid(_charge_state):
		current = _charge_state.current
		maximum = _charge_state.maximum
	_phone_title.text = "%s · %s %d%%" % [tr("SHELL_PHONE_TITLE"), tr("SHELL_PHONE_CHARGE"), roundi(0.0 if maximum <= 0.0 else current / maximum * 100.0)]
	_phone_title_icon.self_modulate = Color(0.95, 0.42, 0.32) if current <= maximum * 0.15 else Color(0.86, 0.84, 0.76)
	_phone_title_icon.tooltip_text = tr("SHELL_ICON_BATTERY_HINT")
	_phone_send.disabled = current <= 0.0
	_phone_input.editable = current > 0.0
	_phone_send.tooltip_text = tr("SHELL_PHONE_NO_CHARGE") if current <= 0.0 else ""


func set_save_available(available: bool) -> void:
	_save_available = available
	for button: Button in _load_buttons:
		button.disabled = not available
		button.tooltip_text = "" if available else tr("SHELL_LOAD_DISABLED")


func set_manual_save_allowed(allowed: bool) -> void:
	_manual_save_button.disabled = not allowed
	_manual_save_button.tooltip_text = "" if allowed else tr("SHELL_MANUAL_SAVE_DISABLED")


func _build_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_panels[&"hud"] = hud
	_dynamic_crosshair = DynamicCrosshair.new()
	_dynamic_crosshair.name = "Crosshair"
	_dynamic_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_dynamic_crosshair.position = Vector2(-10, -10)
	_dynamic_crosshair.size = Vector2(20, 20)
	hud.add_child(_dynamic_crosshair)
	_interaction_label = Label.new()
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_label.position = Vector2(-260, -112)
	_interaction_label.size = Vector2(520, 32)
	hud.add_child(_interaction_label)
	var stats_panel := PanelContainer.new()
	stats_panel.theme_type_variation = &"HudPanel"
	stats_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stats_panel.position = Vector2(24, -212)
	stats_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stats_panel)
	var stats_box := VBoxContainer.new()
	stats_box.custom_minimum_size.x = 230.0
	stats_box.add_theme_constant_override("separation", 5)
	stats_panel.add_child(stats_box)
	for stat_id: StringName in STAT_IDS:
		var row := VitalStrip.new()
		row.name = String(stat_id).capitalize()
		stats_box.add_child(row)
		_stat_rows[stat_id] = row
		_stat_values[stat_id] = row._value_label
		_stat_labels[stat_id] = row._name_label
		row.set_state(stat_id, 0.0, 100.0, _immersive)
	_held_item_label = Label.new()
	_held_item_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_held_item_label.position = Vector2(-324, -116)
	_held_item_label.size = Vector2(300, 32)
	_held_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_held_item_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_held_item_label.add_theme_constant_override("shadow_offset_x", 1)
	_held_item_label.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(_held_item_label)
	_controls_hint_label = Label.new()
	_controls_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_hint_label.position = Vector2(-300, -62)
	_controls_hint_label.size = Vector2(600, 48)
	_controls_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_controls_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_hint_label.modulate = Color(0.72, 0.7, 0.64)
	_controls_hint_label.add_theme_font_size_override("font_size", 14)
	_controls_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_controls_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_controls_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(_controls_hint_label)


func _build_notification_layer() -> void:
	_notification_overlay = Control.new()
	_notification_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notification_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notification_overlay)
	_notification_panel = PanelContainer.new()
	_notification_panel.theme_type_variation = &"NoticePanel"
	_notification_panel.custom_minimum_size = Vector2(720, 42)
	_notification_panel.anchor_left = 0.5
	_notification_panel.anchor_right = 0.5
	_notification_panel.offset_left = -360.0
	_notification_panel.offset_top = 12.0
	_notification_panel.offset_right = 360.0
	_notification_panel.offset_bottom = 54.0
	_notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_panel.visible = false
	_notification_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_notification_overlay.add_child(_notification_panel)
	_notification_label = Label.new()
	_notification_label.theme_type_variation = &"NoticeLabel"
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_panel.add_child(_notification_label)
	_notification_label.minimum_size_changed.connect(_notification_panel.reset_size)
	_notification_timer = Timer.new()
	_notification_timer.one_shot = true
	_notification_overlay.add_child(_notification_timer)


func _build_menu() -> void:
	var content := _make_center_panel(&"menu", Vector2(420, 330))
	_add_title(content, "SHELL_TITLE", 30)
	_add_label(content, tr("SHELL_START_PROMPT"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_button(content, "SHELL_CASUAL", func() -> void: new_game_requested.emit(0))
	_add_button(content, "SHELL_HARDCORE", func() -> void: new_game_requested.emit(1))
	_add_button(content, "SHELL_EXTREME", func() -> void: new_game_requested.emit(2))
	var load_button := _add_button(content, "SHELL_LOAD", func() -> void: load_requested.emit())
	_load_buttons.append(load_button)


func _build_pause() -> void:
	var content := _make_center_panel(&"pause", Vector2(420, 400))
	_add_title(content, "SHELL_TITLE", 26)
	_add_button(content, "SHELL_RESUME", func() -> void: resume_requested.emit())
	_manual_save_button = _add_button(content, "SHELL_SAVE", func() -> void: save_requested.emit())
	var load_button := _add_button(content, "SHELL_LOAD", func() -> void: load_requested.emit())
	_load_buttons.append(load_button)
	_add_button(content, "SHELL_RETURN_MENU", func() -> void: menu_requested.emit())
	_immersive_toggle = CheckButton.new()
	_immersive_toggle.name = "Immersive"
	_immersive_toggle.text = tr("SHELL_IMMERSIVE_HUD")
	_immersive_toggle.toggled.connect(func(value: bool) -> void:
		_immersive = value
		for stat_id: StringName in STAT_IDS:
			_redraw_stat(stat_id)
			_update_stat_visibility(stat_id)
		settings_changed.emit(_immersive, _headbob))
	content.add_child(_immersive_toggle)
	_headbob_toggle = CheckButton.new()
	_headbob_toggle.name = "Headbob"
	_headbob_toggle.text = tr("SHELL_HEADBOB")
	_headbob_toggle.toggled.connect(func(value: bool) -> void:
		_headbob = value
		settings_changed.emit(_immersive, _headbob))
	content.add_child(_headbob_toggle)


func _build_debug() -> void:
	var content := _make_side_panel(&"debug", Vector2(440, 0))
	_add_title(content, "SHELL_DEBUG_TITLE", 24)
	for field: StringName in [&"scene", &"position", &"fps", &"seed", &"flags", &"stats", &"weight"]:
		var row := HBoxContainer.new()
		content.add_child(row)
		var key := Label.new()
		key.text = tr("SHELL_DEBUG_%s" % String(field).to_upper()) + ":"
		key.custom_minimum_size.x = 110
		row.add_child(key)
		var value := Label.new()
		value.text = "—"
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value)
		_debug_values[field] = value
	_debug_items = OptionButton.new()
	content.add_child(_debug_items)
	_add_button(content, "SHELL_DEBUG_GIVE", func() -> void:
		if _debug_items.selected >= 0:
			debug_give_requested.emit(StringName(_debug_items.get_item_metadata(_debug_items.selected))))
	_add_button(content, "SHELL_DEBUG_RELOAD", func() -> void: debug_reload_requested.emit())
	_add_button(content, "SHELL_DEBUG_TRAVEL", func() -> void: debug_travel_requested.emit())
	_add_button(content, "SHELL_DEBUG_DAMAGE", func() -> void: debug_damage_requested.emit())
	var future := _add_label(content, tr("SHELL_DEBUG_FUTURE"), HORIZONTAL_ALIGNMENT_LEFT)
	future.modulate = Color(0.7, 0.67, 0.6)
	_add_button(_side_panel_footers[&"debug"], "SHELL_CLOSE", func() -> void: close_requested.emit())


func _build_phone() -> void:
	var content := _make_center_panel(&"phone", Vector2(780, 400))
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override(&"separation", 8)
	content.add_child(title_row)
	_phone_title_icon = _make_status_icon(&"battery", tr(&"SHELL_ICON_BATTERY_HINT"), 22.0)
	title_row.add_child(_phone_title_icon)
	_phone_title = _add_title_to_row(title_row, "SHELL_PHONE_TITLE", 24)
	var app_bar := HFlowContainer.new()
	app_bar.add_theme_constant_override("h_separation", 6)
	content.add_child(app_bar)
	for app_id: StringName in APP_KEYS:
		var button := Button.new()
		button.text = tr(APP_KEYS[app_id])
		button.pressed.connect(_select_phone_app.bind(app_id))
		app_bar.add_child(button)
	_phone_content = VBoxContainer.new()
	_phone_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phone_content.add_theme_constant_override("separation", 8)
	content.add_child(_phone_content)
	var input_row := HBoxContainer.new()
	content.add_child(input_row)
	_phone_input = LineEdit.new()
	_phone_input.placeholder_text = tr("SHELL_PHONE_INPUT")
	_phone_input.max_length = PhoneState.MAX_MESSAGE_LENGTH
	_phone_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_input.text_submitted.connect(func(text: String) -> void: _request_phone_send(text))
	input_row.add_child(_phone_input)
	_phone_send = Button.new()
	_phone_send.text = tr("SHELL_PHONE_SEND")
	_phone_send.pressed.connect(func() -> void: _request_phone_send(_phone_input.text))
	input_row.add_child(_phone_send)
	_add_label(content, tr("SHELL_PHONE_NO_REPLY"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_button(content, "SHELL_CLOSE", func() -> void: close_requested.emit())


func _build_death() -> void:
	var content := _make_center_panel(&"dead", Vector2(480, 340))
	_add_title(content, "SHELL_DEAD_TITLE", 32)
	_death_cause = _add_label(content, "", HORIZONTAL_ALIGNMENT_CENTER)
	_death_cause.name = "Cause"
	_death_load = _add_button(content, "SHELL_LOAD_RECENT", func() -> void: load_requested.emit())
	_death_load.name = "LoadRecent"
	_load_buttons.append(_death_load)
	_death_no_revive = _add_label(content, tr("SHELL_NO_REVIVE"), HORIZONTAL_ALIGNMENT_CENTER)
	_death_no_revive.name = "NoRevive"
	_add_button(content, "SHELL_RETURN_MENU", func() -> void: menu_requested.emit())


func _make_center_panel(panel_id: StringName, minimum: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 108.0
	center.offset_bottom = -16.0
	root.add_child(center)
	_panels[panel_id] = center
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	return content


func _make_side_panel(panel_id: StringName, minimum: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -minimum.x - 16.0
	panel.offset_top = 108.0
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	root.add_child(panel)
	_panels[panel_id] = panel
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 9)
	panel.add_child(shell)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var footer := VBoxContainer.new()
	footer.name = "Footer"
	shell.add_child(footer)
	_side_panel_footers[panel_id] = footer
	return content


func _add_title(parent: VBoxContainer, key: String, font_size: int) -> Label:
	var label := _add_label(parent, tr(key), HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.86, 0.7, 0.38))
	return label


func _add_label(parent: VBoxContainer, text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _add_button(parent: VBoxContainer, key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_stat_changed(stat_id: StringName, value: float, maximum: float) -> void:
	if not _stat_rows.has(stat_id):
		return
	var previous: float = _stat_last_attention_value.get(stat_id, NAN)
	if is_nan(previous) or absf(value - previous) >= 1.0:
		_stat_last_attention_value[stat_id] = value
		_stat_visible_until[stat_id] = Time.get_ticks_msec() / 1000.0 + 3.0
	_redraw_stat(stat_id, value, maximum)
	_update_stat_visibility(stat_id)


func _redraw_stat(stat_id: StringName, value: float = NAN, maximum: float = NAN) -> void:
	var row: VitalStrip = _stat_rows.get(stat_id) as VitalStrip
	if row == null:
		return
	if is_nan(value) and is_instance_valid(_stats):
		value = _stats.get_value(stat_id)
		maximum = _stats.get_maximum(stat_id)
	row.set_state(stat_id, 0.0 if is_nan(value) else value, 100.0 if is_nan(maximum) else maximum, _immersive)


func _update_stat_visibility(stat_id: StringName) -> void:
	var row: Control = _stat_rows.get(stat_id)
	if is_instance_valid(row):
		row.visible = true


func set_crosshair_motion(speed: float) -> void:
	if is_instance_valid(_dynamic_crosshair):
		_dynamic_crosshair.movement_speed = speed


func _is_critical(stat_id: StringName) -> bool:
	if not is_instance_valid(_stats):
		return false
	var maximum: float = _stats.get_maximum(stat_id)
	if maximum <= 0.0:
		return false
	var ratio: float = _stats.get_value(stat_id) / maximum
	return ratio >= 0.75 if stat_id == &"fatigue" else ratio <= 0.25


func _make_status_icon(icon_id: StringName, tooltip: String, size: float = 18.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.texture = UiIcons.icon(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.tooltip_text = tooltip
	icon.self_modulate = Color(0.86, 0.84, 0.76)
	return icon


func _add_title_to_row(parent: HBoxContainer, key: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.86, 0.7, 0.38))
	parent.add_child(label)
	return label


func _select_phone_app(app_id: StringName) -> void:
	if is_instance_valid(_phone_state):
		_phone_state.set_active_app(app_id)
	else:
		_refresh_phone_app(app_id)


func _refresh_phone() -> void:
	refresh_phone_charge()
	_refresh_phone_app(_phone_state.active_app if is_instance_valid(_phone_state) else &"chat")


func _refresh_phone_app(app_id: StringName) -> void:
	for child: Node in _phone_content.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = tr(APP_KEYS.get(app_id, "SHELL_PHONE_CHAT"))
	heading.add_theme_font_size_override("font_size", 20)
	_phone_content.add_child(heading)
	if app_id == &"chat":
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y = 220
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_content.add_child(scroll)
		var history := VBoxContainer.new()
		history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(history)
		if not is_instance_valid(_phone_state) or _phone_state.messages.is_empty():
			var empty := Label.new()
			empty.text = tr("SHELL_PHONE_EMPTY")
			history.add_child(empty)
		else:
			for message: Dictionary in _phone_state.messages:
				var line := Label.new()
				var status_key: String = "SHELL_PHONE_STATUS_%s" % String(message["status"]).to_upper()
				line.text = "#%d  %s  [%s]" % [int(message["sequence"]), str(message["text"]), tr(status_key)]
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				history.add_child(line)
		var offline_row := HBoxContainer.new()
		offline_row.add_theme_constant_override(&"separation", 7)
		offline_row.visible = is_instance_valid(_phone_state) and _phone_state.offline
		_phone_content.add_child(offline_row)
		var offline_icon := _make_status_icon(&"wifi_off", tr(&"SHELL_ICON_OFFLINE_HINT"))
		offline_icon.self_modulate = Color(0.95, 0.58, 0.38)
		offline_row.add_child(offline_icon)
		var offline := Label.new()
		offline.text = tr("SHELL_PHONE_OFFLINE")
		offline.tooltip_text = tr(&"SHELL_ICON_OFFLINE_HINT")
		offline_row.add_child(offline)
	elif app_id == &"clock":
		_clock_label = Label.new()
		_clock_label.text = _world_time
		_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_clock_label.add_theme_font_size_override("font_size", 36)
		_phone_content.add_child(_clock_label)
	else:
		var later := Label.new()
		later.text = tr("SHELL_PHONE_LATER")
		later.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_phone_content.add_child(later)
	_phone_input.visible = app_id == &"chat"
	_phone_send.visible = app_id == &"chat"


func _request_phone_send(text: String) -> void:
	if text.strip_edges().is_empty() or _phone_send.disabled:
		return
	phone_send_requested.emit(text)
	_phone_input.clear()
