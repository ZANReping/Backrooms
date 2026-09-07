class_name PrologueShell
extends FoundationUI

var _checklist: TaskChecklist
var _settings_views: Array[SettingsView] = []
var _stats_panel: PanelContainer
var _prologue_active: bool = true
var _shell_mode: StringName = &"menu"
var _menu_pages: Dictionary[StringName, VBoxContainer] = {}
var _pause_pages: Dictionary[StringName, VBoxContainer] = {}
var _notice_is_save: bool = false


func _build_hud() -> void:
	super()
	var hud: Control = _panels.get(&"hud")
	for child: Node in hud.get_children():
		if child is PanelContainer:
			_stats_panel = child as PanelContainer
			_stats_panel.name = "StatsPanel"
			break
	_checklist = TaskChecklist.new()
	_checklist.name = "TaskChecklist"
	_checklist.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_checklist.offset_left = -318.0
	_checklist.offset_top = 112.0
	_checklist.offset_right = -28.0
	hud.add_child(_checklist)
	_interaction_label.add_theme_font_size_override(&"font_size", 16)
	_interaction_label.add_theme_color_override(&"font_color", Color(0.94, 0.92, 0.85, 0.95))
	_interaction_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_interaction_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_interaction_label.add_theme_constant_override(&"shadow_offset_y", 2)
	_apply_prologue_hud_visibility()


func _build_notification_layer() -> void:
	super()
	_notification_panel.theme_type_variation = &"PrologueNotice"
	_notification_panel.custom_minimum_size = Vector2(0.0, 30.0)
	_notification_label.add_theme_font_size_override(&"font_size", 14)
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_notification_label.add_theme_constant_override(&"shadow_offset_y", 1)
	root.resized.connect(_layout_prologue_notice)
	root.resized.connect(_layout_settings_pages)
	_layout_prologue_notice()


func _build_menu() -> void:
	var menu := _make_life_panel(&"menu")
	var content := _make_life_page(menu, &"home", _menu_pages)
	_life_heading(content, &"PROLOGUE_MONTH_DAY", &"PROLOGUE_DATE")
	var continue_button := _life_button(content, "PROLOGUE_CONTINUE", func() -> void: load_requested.emit())
	continue_button.name = "Continue"
	_load_buttons.append(continue_button)
	_life_button(content, "PROLOGUE_NEW_DAY", func() -> void: _show_life_page(_menu_pages, &"difficulty"))
	_life_button(content, "PROLOGUE_SETTINGS", func() -> void: _show_life_page(_menu_pages, &"settings"))
	var difficulty := _make_life_page(menu, &"difficulty", _menu_pages)
	_life_heading(difficulty, &"PROLOGUE_NEW_DAY", &"PROLOGUE_DIFFICULTY_NOTE")
	var names: Array[String] = ["SHELL_CASUAL", "SHELL_HARDCORE", "SHELL_EXTREME"]
	var details: Array[StringName] = [&"PROLOGUE_CASUAL_DETAIL", &"PROLOGUE_HARDCORE_DETAIL", &"PROLOGUE_EXTREME_DETAIL"]
	for index: int in 3:
		_life_button(difficulty, names[index], func() -> void: new_game_requested.emit(index))
		_life_copy(difficulty, details[index])
	_life_button(difficulty, "PROLOGUE_BACK", func() -> void: _show_life_page(_menu_pages, &"home"))
	_build_life_settings(menu, _menu_pages)
	_show_life_page(_menu_pages, &"home")


func _build_pause() -> void:
	var pause := _make_life_panel(&"pause")
	var content := _make_life_page(pause, &"home", _pause_pages)
	_life_heading(content, &"PROLOGUE_PAUSED", &"PROLOGUE_PAUSED_NOTE")
	_life_button(content, "SHELL_RESUME", func() -> void: resume_requested.emit())
	_manual_save_button = _life_button(content, "SHELL_SAVE", func() -> void: save_requested.emit())
	var load_button := _life_button(content, "SHELL_LOAD", func() -> void: load_requested.emit())
	_load_buttons.append(load_button)
	_life_button(content, "PROLOGUE_SETTINGS", func() -> void: _show_life_page(_pause_pages, &"settings"))
	_life_button(content, "SHELL_RETURN_MENU", func() -> void: menu_requested.emit())
	_build_life_settings(pause, _pause_pages)
	_show_life_page(_pause_pages, &"home")


func _make_life_panel(id: StringName) -> Control:
	var panel := Control.new()
	panel.name = String(id).capitalize()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	_panels[id] = panel
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(0.025, 0.028, 0.029, 0.9), Color(0.025, 0.028, 0.029, 0.78), Color(0.025, 0.028, 0.029, 0.12), Color(0.025, 0.028, 0.029, 0.04)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 2
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0)
	shade.texture = texture
	panel.add_child(shade)
	return panel


func _make_life_page(parent: Control, id: StringName, pages: Dictionary[StringName, VBoxContainer]) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = String(id).capitalize() + "Scroll"
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 42.0
	scroll.offset_top = 54.0
	scroll.offset_right = 398.0
	scroll.offset_bottom = -38.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var page := VBoxContainer.new()
	page.name = String(id).capitalize()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 8)
	scroll.add_child(page)
	pages[id] = page
	return page


func _show_life_page(pages: Dictionary[StringName, VBoxContainer], id: StringName) -> void:
	for key: StringName in pages:
		pages[key].get_parent().visible = key == id
	for child: Node in pages[id].get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			break


func _life_heading(parent: VBoxContainer, title: StringName, subtitle: StringName) -> void:
	var heading := _add_label(parent, tr(title), HORIZONTAL_ALIGNMENT_LEFT)
	heading.theme_type_variation = &"LifeHeading"
	_life_copy(parent, subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18.0
	parent.add_child(gap)


func _life_copy(parent: VBoxContainer, key: StringName) -> Label:
	var label := _add_label(parent, tr(key), HORIZONTAL_ALIGNMENT_LEFT)
	label.theme_type_variation = &"LifeSecondary"
	return label


func _life_button(parent: VBoxContainer, key: String, callback: Callable) -> Button:
	var button := _add_button(parent, key, callback)
	button.theme_type_variation = &"LifeButton"
	button.custom_minimum_size.y = 44.0
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


func _build_life_settings(parent: Control, pages: Dictionary[StringName, VBoxContainer]) -> void:
	var content := _make_life_page(parent, &"settings", pages)
	var scroll: ScrollContainer = content.get_parent() as ScrollContainer
	scroll.offset_top = 32.0
	scroll.offset_bottom = -24.0
	scroll.anchor_right = 1.0
	scroll.offset_right = -42.0
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var view := SettingsView.new()
	content.add_child(view)
	_settings_views.append(view)
	_layout_settings_pages()
	view.preference_changed.connect(func(key: StringName, value: Variant) -> void: preference_changed.emit(key, value))
	view.restore_requested.connect(func() -> void: restore_preferences_requested.emit())
	view.set_values(Settings.to_data())
	_life_button(content, "PROLOGUE_BACK", func() -> void: _show_life_page(pages, &"home"))


func _layout_settings_pages() -> void:
	for view: SettingsView in _settings_views:
		var scroll: ScrollContainer = view.get_parent().get_parent() as ScrollContainer
		scroll.anchor_right = 0.0
		scroll.offset_right = minf(root.size.x - 42.0, 902.0)


func set_preferences(immersive: bool, headbob: bool) -> void:
	super(immersive, headbob)
	for view: SettingsView in _settings_views:
		view.set_values(Settings.to_data())


func notify(text: String) -> void:
	_notice_is_save = text == tr(&"PRO_SAVED") or text == tr(&"NOTICE_SAVED")
	_show_notification(text, 1.34 if _notice_is_save else 2.54)
	_layout_prologue_notice()


func _layout_prologue_notice() -> void:
	if not is_instance_valid(_notification_panel):
		return
	var width: float = minf(580.0, maxf(280.0, root.size.x - 64.0))
	# Foundation's minimum-size signal calls reset_size(); retain the width so
	# wrapped labels cannot collapse to one character after a text update.
	_notification_panel.custom_minimum_size = Vector2(220.0 if _notice_is_save else width, 30.0)
	_notification_panel.anchor_left = 1.0 if _notice_is_save else 0.5
	_notification_panel.anchor_right = _notification_panel.anchor_left
	_notification_panel.anchor_top = 0.0
	_notification_panel.anchor_bottom = _notification_panel.anchor_top
	_notification_panel.offset_left = -244.0 if _notice_is_save else -width * 0.5
	_notification_panel.offset_right = -24.0 if _notice_is_save else width * 0.5
	_notification_panel.offset_top = 18.0 if _notice_is_save else 16.0
	_notification_panel.offset_bottom = 52.0
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _notice_is_save else HORIZONTAL_ALIGNMENT_CENTER


func _add_title(parent: VBoxContainer, key: String, font_size: int) -> Label:
	var label := _add_label(parent, tr(key), HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color(0.9, 0.88, 0.81, 1.0))
	return label


func set_mode(mode: StringName) -> void:
	_shell_mode = mode
	super(mode)
	if mode == &"menu" and not _menu_pages.is_empty():
		_show_life_page(_menu_pages, &"home")
	elif mode == &"pause" and not _pause_pages.is_empty():
		_show_life_page(_pause_pages, &"home")
	_layout_prologue_notice()
	if mode in [&"menu", &"pause", &"camera", &"appearance"]:
		notify("")
	if mode == &"phone":
		var phone_panel: Control = _panels.get(&"phone")
		if is_instance_valid(phone_panel):
			phone_panel.visible = false
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	var pages: Dictionary[StringName, VBoxContainer] = _menu_pages if _shell_mode == &"menu" else _pause_pages
	if _shell_mode in [&"menu", &"pause"] and not pages.is_empty() and not pages[&"home"].get_parent().visible:
		_show_life_page(pages, &"home")
		get_viewport().set_input_as_handled()


func set_interaction(text: String) -> void:
	var verb: String = text.trim_prefix("E  ").trim_prefix("[E] ").strip_edges()
	super("[E]  %s" % verb if not verb.is_empty() else "")


func set_held_item(text: String) -> void:
	super(text)
	if _prologue_active:
		_held_item_label.visible = false


func set_controls_hint(text: String) -> void:
	super(text)
	_controls_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_controls_hint_label.offset_left = -360.0
	_controls_hint_label.offset_right = 360.0
	_controls_hint_label.offset_top = 62.0
	_controls_hint_label.offset_bottom = 106.0
	_controls_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_controls_hint_label.modulate = Color(0.86, 0.87, 0.85, 0.96)
	_controls_hint_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_controls_hint_label.add_theme_constant_override(&"shadow_offset_x", 0)
	_controls_hint_label.add_theme_constant_override(&"shadow_offset_y", 1)
	_controls_hint_label.visible = _controls_hint_enabled and not text.is_empty()


func is_rebinding() -> bool:
	for view: SettingsView in _settings_views:
		if is_instance_valid(view) and view.has_method(&"is_rebinding") and bool(view.call(&"is_rebinding")):
			return true
	return false


func capture_binding_event(event: InputEvent) -> bool:
	for view: SettingsView in _settings_views:
		if is_instance_valid(view) and view.has_method(&"capture_binding_event") and bool(view.call(&"is_rebinding")):
			return bool(view.call(&"capture_binding_event", event))
	return false


func set_objective(text: String) -> void:
	# Compatibility for callers outside the prologue's progress projection.
	set_task(&"objective", text, [])


func set_task(task_id: StringName, title: String, entries: Array[Dictionary]) -> void:
	if is_instance_valid(_checklist):
		_checklist.set_task(task_id, title, entries)
		_checklist.visible = not title.is_empty()


func set_prologue_active(active: bool) -> void:
	_prologue_active = active
	_apply_prologue_hud_visibility()


func _apply_prologue_hud_visibility() -> void:
	if is_instance_valid(_held_item_label):
		_held_item_label.visible = not _prologue_active and not _held_item_label.text.is_empty()
	if is_instance_valid(_controls_hint_label):
		_controls_hint_label.visible = _controls_hint_enabled and not _controls_hint_label.text.is_empty()
	_update_stats_panel_visibility()


func _process(delta: float) -> void:
	super(delta)
	_update_stats_panel_visibility()


func _update_stats_panel_visibility() -> void:
	if not is_instance_valid(_stats_panel):
		return
	var has_visible_stat: bool = false
	for row: Control in _stat_rows.values():
		if is_instance_valid(row) and row.visible:
			has_visible_stat = true
			break
	_stats_panel.visible = has_visible_stat
