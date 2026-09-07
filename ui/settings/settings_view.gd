class_name SettingsView
extends VBoxContainer

signal preference_changed(key: StringName, value: Variant)
signal restore_requested

const PreferenceSchemaScript := preload("res://core/settings/preference_schema.gd")
const ToggleSwitchScript := preload("res://ui/settings/settings_toggle_switch.gd")
const InputBindingsScript := preload("res://core/input/input_bindings.gd")
const DEFAULT_VALUES := PreferenceSchemaScript.DEFAULTS

var _controls: Dictionary[StringName, Control] = {}
var _value_labels: Dictionary[StringName, Label] = {}
var _category_buttons: Array[Button] = []
var _category_pages: Array[Control] = []
var _display_buttons: Array[Button] = []
var _display_pages: Array[Control] = []
var _display_stack: Control
var _syncing := false
var _key_bindings: Dictionary = {}
var _binding_buttons: Dictionary[StringName, Array] = {}
var _rebinding_action: StringName
var _rebinding_slot := -1


func _ready() -> void:
	custom_minimum_size = Vector2(520, 360)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 12)
	_build_header()
	_build_category_tabs()
	_build_pages()
	set_values(DEFAULT_VALUES)
	_show_category(0)


func set_values(values: Dictionary) -> void:
	_syncing = true
	for key: StringName in _controls:
		var value: Variant = values.get(key, DEFAULT_VALUES[key])
		var control := _controls[key]
		if control is OptionButton:
			(control as OptionButton).select(clampi(int(value), 0, (control as OptionButton).item_count - 1))
		elif control is BaseButton:
			(control as BaseButton).set_pressed_no_signal(bool(value))
		elif control is Range:
			(control as Range).set_value_no_signal(float(value))
		_update_value_label(key, value)
	_key_bindings = _copy_bindings(values.get("key_bindings", InputBindingsScript.defaults()))
	_refresh_binding_buttons()
	_syncing = false


func is_rebinding() -> bool:
	return _rebinding_slot >= 0


func capture_binding_event(event: InputEvent) -> bool:
	if not is_rebinding():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		var code := 0 if key_event.physical_keycode == KEY_ESCAPE else int(key_event.physical_keycode)
		_commit_binding(code)
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return true
		_commit_binding(-int(mouse_event.button_index))
		return true
	return true


func _input(event: InputEvent) -> void:
	if capture_binding_event(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_rebinding()


func _build_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)
	var heading := Label.new()
	heading.text = "设置"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override(&"font_size", 24)
	heading.add_theme_color_override(&"font_color", Color("edf0f0"))
	row.add_child(heading)
	var restore := Button.new()
	restore.name = "RestoreDefaults"
	restore.text = "恢复默认"
	restore.tooltip_text = "请求恢复全部设置为默认值"
	restore.custom_minimum_size = Vector2(112, 40)
	restore.pressed.connect(func() -> void: restore_requested.emit())
	row.add_child(restore)


func _build_category_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "CategoryTabs"
	tabs.add_theme_constant_override(&"separation", 6)
	add_child(tabs)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for title: String in ["游戏", "画面", "音频", "操作"]:
		var button := _tab_button(title, group)
		button.pressed.connect(_show_category.bind(_category_buttons.size()))
		tabs.add_child(button)
		_category_buttons.append(button)


func _build_pages() -> void:
	var stack := Control.new()
	stack.name = "CategoryPages"
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(stack)
	for page_name: String in ["GamePage", "DisplayPage", "AudioPage", "ControlsPage"]:
		var scroll := ScrollContainer.new()
		scroll.name = page_name
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		stack.add_child(scroll)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override(&"separation", 10)
		scroll.add_child(content)
		_category_pages.append(scroll)
	_build_game(_content(0))
	_build_display(_content(1))
	_build_audio(_content(2))
	_build_controls(_content(3))


func _build_game(parent: VBoxContainer) -> void:
	_add_section(parent, "游戏体验", "调整界面反馈与开发辅助功能。")
	_add_toggle(parent, &"developer_mode", "开发者模式", "显示调试入口与诊断信息")
	_add_toggle(parent, &"dynamic_crosshair", "动态准星", "动态响应移动与可交互目标")
	_add_toggle(parent, &"immersive_hud", "沉浸状态栏", "隐藏数值，保留完整状态条")
	_add_toggle(parent, &"controls_hint", "操作提示", "显示当前场景可用的操作提示")


func _build_display(parent: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 5)
	parent.add_child(tabs)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for title: String in ["基础", "光影", "性能", "氛围"]:
		var button := _tab_button(title, group)
		button.pressed.connect(_show_display_page.bind(_display_buttons.size()))
		tabs.add_child(button)
		_display_buttons.append(button)
	_display_stack = Control.new()
	_display_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_display_stack)
	for page_name: String in ["Basic", "Lighting", "Performance", "Atmosphere"]:
		var page := VBoxContainer.new()
		page.name = "Display" + page_name
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override(&"separation", 10)
		_display_stack.add_child(page)
		_display_pages.append(page)
		page.minimum_size_changed.connect(_sync_display_stack.bind(page))
	var resolution_labels: Array[String] = ["960 × 540", "1280 × 720", "1600 × 900", "1920 × 1080"]
	_add_option(_display_pages[0], &"resolution", "窗口分辨率", resolution_labels)
	_add_option(_display_pages[0], &"window_mode", "窗口模式", ["窗口", "无边框全屏", "独占全屏"])
	_add_toggle(_display_pages[1], &"shadows", "阴影", "显示动态与静态阴影")
	_add_toggle(_display_pages[1], &"ambient_occlusion", "环境光遮蔽", "加强物体接触处的层次")
	_add_toggle(_display_pages[1], &"glow", "辉光", "保留高亮光源的柔和扩散")
	_add_toggle(_display_pages[2], &"vsync", "垂直同步", "减少画面撕裂")
	_add_option(_display_pages[2], &"fps_limit", "帧率上限", ["不限", "60", "90", "120"])
	_add_slider(_display_pages[2], &"render_scale", "渲染比例", 0.5, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_option(_display_pages[2], &"msaa", "多重采样抗锯齿", ["关闭", "2×", "4×"])
	_add_toggle(_display_pages[3], &"headbob", "行走晃动", "启用自然、克制的步行动作")
	_add_toggle(_display_pages[3], &"vcr_filter", "录像带滤镜", "模拟老式录像设备的画面特征")
	_show_display_page(0)


func _build_audio(parent: VBoxContainer) -> void:
	_add_section(parent, "音频", "各通道独立调节，修改立即反馈。")
	var percent := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	_add_slider(parent, &"master_volume", "主音量", 0.0, 1.0, 0.01, percent)
	_add_slider(parent, &"ambience_volume", "环境音量", 0.0, 1.0, 0.01, percent)
	_add_slider(parent, &"effects_volume", "效果音量", 0.0, 1.0, 0.01, percent)


func _build_controls(parent: VBoxContainer) -> void:
	_add_section(parent, "操作", "调整视角响应与观察范围。")
	_add_slider(parent, &"mouse_sensitivity", "鼠标灵敏度", 0.3, 2.0, 0.05, func(v: float) -> String: return "%.2f" % v)
	_add_toggle(parent, &"invert_y", "反转纵向视角", "向上移动鼠标时视角向下")
	_add_slider(parent, &"fov", "视野范围", 65.0, 100.0, 1.0, func(v: float) -> String: return "%d°" % roundi(v))
	_add_section(parent, "按键绑定", "每项可设置两个输入。冲突会提示，但仍可保存。")
	_build_key_bindings(parent)
	var fixed := _card(parent)
	var fixed_row := HBoxContainer.new()
	fixed.add_child(fixed_row)
	fixed_row.add_child(_setting_label("暂停 / 返回"))
	var fixed_value := Label.new()
	fixed_value.text = "Esc（固定）"
	fixed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fixed_value.add_theme_color_override(&"font_color", Color("aebbbb"))
	fixed_row.add_child(fixed_value)


func _build_key_bindings(parent: VBoxContainer) -> void:
	for action: StringName in InputBindingsScript.ACTIONS:
		var card := _card(parent)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		card.add_child(row)
		var title := _setting_label(String(InputBindingsScript.LABELS.get(action, action)))
		title.custom_minimum_size.x = 150
		row.add_child(title)
		var buttons: Array[Button] = []
		for slot: int in 2:
			var button := Button.new()
			button.name = "Binding_%s_%d" % [String(action), slot]
			button.custom_minimum_size = Vector2(150, 42)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_begin_rebinding.bind(action, slot))
			row.add_child(button)
			buttons.append(button)
		_binding_buttons[action] = buttons


func _begin_rebinding(action: StringName, slot: int) -> void:
	_cancel_rebinding()
	_rebinding_action = action
	_rebinding_slot = slot
	var button: Button = _binding_buttons[action][slot]
	button.text = "按下按键…"
	button.add_theme_color_override(&"font_color", Color("e6c36a"))
	button.grab_focus()


func _commit_binding(code: int) -> void:
	var action := _rebinding_action
	var slot := _rebinding_slot
	_rebinding_slot = -1
	var values: Array = _key_bindings.get(action, [0, 0])
	while values.size() < 2:
		values.append(0)
	values[slot] = code
	_key_bindings[action] = values
	_refresh_binding_buttons()
	preference_changed.emit(&"key_bindings", _copy_bindings(_key_bindings))


func _cancel_rebinding() -> void:
	if not is_rebinding():
		return
	_rebinding_slot = -1
	_refresh_binding_buttons()


func _refresh_binding_buttons() -> void:
	if _binding_buttons.is_empty():
		return
	var conflict_map: Dictionary = InputBindingsScript.conflicts(_key_bindings)
	for action: StringName in _binding_buttons:
		var values: Array = _key_bindings.get(action, [0, 0])
		var action_conflicts: Array = conflict_map.get(action, [false, false])
		for slot: int in 2:
			var button: Button = _binding_buttons[action][slot]
			button.text = InputBindingsScript.binding_label(int(values[slot]))
			var conflicted := bool(action_conflicts[slot])
			if conflicted:
				button.add_theme_color_override(&"font_color", Color("e6c36a"))
				button.tooltip_text = "此按键与其他操作冲突"
			else:
				button.remove_theme_color_override(&"font_color")
				button.tooltip_text = "点击后按下新按键；Esc 清空此槽"


func _copy_bindings(source: Dictionary) -> Dictionary:
	var result: Dictionary[StringName, Array] = {}
	for action: StringName in InputBindingsScript.ACTIONS:
		var values: Array = source.get(action, source.get(String(action), [0, 0]))
		result[action] = [int(values[0]) if values.size() > 0 else 0, int(values[1]) if values.size() > 1 else 0]
	return result


func _add_section(parent: VBoxContainer, title: String, description: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override(&"font_size", 20)
	heading.add_theme_color_override(&"font_color", Color("e3e8e8"))
	parent.add_child(heading)
	var copy := Label.new()
	copy.text = description
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override(&"font_size", 14)
	copy.add_theme_color_override(&"font_color", Color("9ca5a5"))
	parent.add_child(copy)


func _add_toggle(parent: Control, key: StringName, title: String, detail: String) -> void:
	var card := _card(parent)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	card.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	labels.add_child(_setting_label(title))
	var description := Label.new()
	description.text = detail
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override(&"font_size", 13)
	description.add_theme_color_override(&"font_color", Color("98a0a0"))
	labels.add_child(description)
	var toggle := ToggleSwitchScript.new() as BaseButton
	toggle.name = String(key)
	toggle.tooltip_text = "%s：点击切换" % title
	toggle.toggled.connect(func(value: bool) -> void: _emit_value(key, value))
	row.add_child(toggle)
	_controls[key] = toggle


func _add_option(parent: Control, key: StringName, title: String, items: Array[String]) -> void:
	var card := _card(parent)
	var label_row := HBoxContainer.new()
	card.add_child(label_row)
	label_row.add_child(_setting_label(title))
	var option := OptionButton.new()
	option.name = String(key)
	option.custom_minimum_size.y = 42
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		option.add_item(item)
	option.item_selected.connect(func(index: int) -> void: _emit_value(key, index))
	card.add_child(option)
	_controls[key] = option


func _add_slider(parent: Control, key: StringName, title: String, minimum: float, maximum: float, step: float, formatter: Callable) -> void:
	var card := _card(parent)
	var label_row := HBoxContainer.new()
	card.add_child(label_row)
	label_row.add_child(_setting_label(title))
	var value_label := _current_value_label()
	label_row.add_child(value_label)
	_value_labels[key] = value_label
	var slider := HSlider.new()
	slider.name = String(key)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size.y = 34
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.set_meta(&"formatter", formatter)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("303637")
	track.set_corner_radius_all(2)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("718586")
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	var fill_hover := fill.duplicate() as StyleBoxFlat
	fill_hover.bg_color = Color("849b9c")
	slider.add_theme_stylebox_override(&"slider", track)
	slider.add_theme_stylebox_override(&"grabber_area", fill)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", fill_hover)
	slider.value_changed.connect(func(value: float) -> void: _emit_value(key, value))
	card.add_child(slider)
	_controls[key] = slider


func _card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15191a")
	style.border_color = Color("303738")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override(&"panel", style)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 6)
	panel.add_child(content)
	return content


func _setting_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color("d7dddd"))
	return label


func _current_value_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size.x = 128
	label.add_theme_font_size_override(&"font_size", 14)
	label.add_theme_color_override(&"font_color", Color("aebbbb"))
	return label


func _tab_button(title: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _content(index: int) -> VBoxContainer:
	return _category_pages[index].get_child(0) as VBoxContainer


func _show_category(index: int) -> void:
	_cancel_rebinding()
	for page_index: int in _category_pages.size():
		_category_pages[page_index].visible = page_index == index
		_category_buttons[page_index].set_pressed_no_signal(page_index == index)


func _show_display_page(index: int) -> void:
	for page_index: int in _display_pages.size():
		_display_pages[page_index].visible = page_index == index
		_display_buttons[page_index].set_pressed_no_signal(page_index == index)
	_sync_display_stack(_display_pages[index])
	_sync_display_stack.call_deferred(_display_pages[index])


func _sync_display_stack(page: Control) -> void:
	if not is_instance_valid(_display_stack) or not is_instance_valid(page) or not page.visible:
		return
	_display_stack.custom_minimum_size.y = ceilf(page.get_combined_minimum_size().y)


func _emit_value(key: StringName, value: Variant) -> void:
	_update_value_label(key, value)
	if not _syncing:
		preference_changed.emit(key, value)


func _update_value_label(key: StringName, value: Variant) -> void:
	var label: Label = _value_labels.get(key)
	if label == null:
		return
	var control: Control = _controls.get(key) as Control
	if control is OptionButton:
		var option := control as OptionButton
		var index := clampi(int(value), 0, option.item_count - 1)
		label.text = option.get_item_text(index)
	elif control is Range:
		label.text = String((control as Range).get_meta(&"formatter").call(float(value)))
