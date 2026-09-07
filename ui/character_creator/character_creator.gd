class_name CharacterCreator
extends Control

signal confirmed(appearance: CharacterAppearance)
signal cancelled

const HAIR_IDS: Array[StringName] = [&"short", &"crop", &"bob", &"tied"]
const BODY_TYPE_IDS: Array[StringName] = [&"neutral", &"female", &"male"]
const HAIR_COLORS: Array[Color] = [Color("241d19"), Color("594330"), Color("84765b"), Color("463b39"), Color("17191c")]

var _draft: CharacterAppearance
var _supported_morphs: Array[StringName] = []
var _morph_controls: Dictionary[StringName, Slider] = {}
var _unsupported_hint: Label
var _viewport: SubViewport
var _preview_root: Node3D
var _preview_character: Node3D
var _camera: Camera3D
var _dragging: bool = false
var _last_pointer: Vector2
var _full_body: bool = true
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _view_buttons: Array[Button] = []
var _skin_swatches: Array[Button] = []
var _hair_swatches: Array[Button] = []


func _ready() -> void:
	theme = preload("res://ui/character_creator/character_creator_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if is_instance_valid(_preview_character):
		_attach_preview_character.call_deferred()
	visible = false


func edit(appearance: CharacterAppearance) -> void:
	_draft = appearance.copy() if appearance != null else CharacterAppearance.new()
	_sync_controls()
	_apply_preview()
	visible = true


func set_preview_character(node: Node3D) -> void:
	_preview_character = node
	if is_node_ready():
		_attach_preview_character.call_deferred()


func set_supported_morphs(ids: Array[StringName]) -> void:
	_supported_morphs.clear()
	for id: StringName in ids:
		if (id in CharacterAppearance.FACE_KEYS or id in CharacterAppearance.BODY_KEYS) and id not in _supported_morphs:
			_supported_morphs.append(id)
	_update_morph_availability()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("17191c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override(&"separation", 0)
	add_child(shell)
	var header := _build_header()
	shell.add_child(header)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override(&"separation", 0)
	shell.add_child(split)
	_build_preview(split)
	_build_editor(split)


func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SidePanel"
	panel.custom_minimum_size.y = 64.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	panel.add_child(row)
	var title := Label.new()
	title.text = tr(&"CHARACTER_CREATOR_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override(&"font_size", 24)
	row.add_child(title)
	var cancel_button := Button.new()
	cancel_button.text = tr(&"CHARACTER_CREATOR_CANCEL")
	cancel_button.icon = UiIcons.icon(&"x")
	cancel_button.pressed.connect(_cancel)
	row.add_child(cancel_button)
	var confirm_button := Button.new()
	confirm_button.text = tr(&"CHARACTER_CREATOR_CONFIRM")
	confirm_button.icon = UiIcons.icon(&"check")
	confirm_button.pressed.connect(_confirm)
	row.add_child(confirm_button)
	return panel


func _build_preview(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 2.0
	parent.add_child(column)
	var preview := SubViewportContainer.new()
	preview.name = "Preview"
	preview.stretch = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.gui_input.connect(_on_preview_input)
	column.add_child(preview)
	_viewport = SubViewport.new()
	_viewport.name = "CharacterViewport"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.size = Vector2i(800, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.transparent_bg = false
	preview.add_child(_viewport)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("24272c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e0e5")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	_preview_root = Node3D.new()
	_preview_root.name = "PreviewPivot"
	_viewport.add_child(_preview_root)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 0.95, -3.5)
	_camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	_camera.fov = 32.0
	_add_preview_light(Vector3(-2.4, 3.2, -2.4), Color("fff4e7"), 1.6)
	_add_preview_light(Vector3(2.4, 2.0, -1.0), Color("b8d4eb"), 0.8)
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.custom_minimum_size.y = 52.0
	column.add_child(mode_row)
	var view_group := ButtonGroup.new()
	view_group.allow_unpress = false
	for full_body: bool in [false, true]:
		var button := Button.new()
		button.name = "FullBodyView" if full_body else "FaceView"
		button.text = tr(&"CHARACTER_CREATOR_FULL_BODY" if full_body else &"CHARACTER_CREATOR_FACE_VIEW")
		button.icon = UiIcons.icon(&"user" if full_body else &"scan-face")
		button.toggle_mode = true
		button.button_group = view_group
		button.pressed.connect(_set_view.bind(full_body))
		mode_row.add_child(button)
		_view_buttons.append(button)
	_view_buttons[1].set_pressed_no_signal(true)
	var drag_hint := Label.new()
	drag_hint.text = tr(&"CHARACTER_CREATOR_PREVIEW_HINT")
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_hint.modulate = Color(0.72, 0.75, 0.78)
	column.add_child(drag_hint)


func _build_editor(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SidePanel"
	panel.custom_minimum_size.x = 320.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)
	var editor := VBoxContainer.new()
	editor.add_theme_constant_override(&"separation", 12)
	panel.add_child(editor)
	var tabs := HBoxContainer.new()
	tabs.name = "CreatorTabs"
	tabs.add_theme_constant_override(&"separation", 6)
	editor.add_child(tabs)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	for tab_key: StringName in [&"CHARACTER_CREATOR_GENERAL", &"CHARACTER_CREATOR_FACE", &"CHARACTER_CREATOR_BODY"]:
		var tab := Button.new()
		tab.name = "%s_TAB" % String(tab_key)
		tab.text = tr(tab_key)
		tab.toggle_mode = true
		tab.button_group = tab_group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_page.bind(_tab_buttons.size()))
		tabs.add_child(tab)
		_tab_buttons.append(tab)
	var page_stack := Control.new()
	page_stack.name = "PageStack"
	page_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_child(page_stack)
	for page_name: String in ["GeneralPage", "FacePage", "BodyPage"]:
		var scroll := ScrollContainer.new()
		scroll.name = page_name
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page_stack.add_child(scroll)
		var fields := VBoxContainer.new()
		fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fields.add_theme_constant_override(&"separation", 12)
		scroll.add_child(fields)
		_pages.append(scroll)
	var general_fields := _pages[0].get_child(0) as VBoxContainer
	_add_section(general_fields, &"CHARACTER_CREATOR_GENERAL")
	_add_option(general_fields, &"CHARACTER_CREATOR_BODY_TYPE", BODY_TYPE_IDS, _on_body_type)
	_add_skin_palette(general_fields)
	_add_option(general_fields, &"CHARACTER_CREATOR_HAIR", HAIR_IDS, _on_hair)
	_add_hair_palette(general_fields)
	_unsupported_hint = Label.new()
	_unsupported_hint.text = tr(&"CHARACTER_CREATOR_UNSUPPORTED_HINT")
	_unsupported_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unsupported_hint.modulate = Color(0.92, 0.68, 0.4)
	general_fields.add_child(_unsupported_hint)
	_add_morph_section(_pages[1].get_child(0) as VBoxContainer, &"CHARACTER_CREATOR_FACE", CharacterAppearance.FACE_KEYS)
	_add_morph_section(_pages[2].get_child(0) as VBoxContainer, &"CHARACTER_CREATOR_BODY", CharacterAppearance.BODY_KEYS)
	_show_page(0)


func _show_page(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	for page_index: int in _pages.size():
		_pages[page_index].visible = page_index == index
		_tab_buttons[page_index].set_pressed_no_signal(page_index == index)
	if index == 1:
		_set_view(false)
	elif index == 2:
		_set_view(true)


func _add_section(parent: VBoxContainer, key: StringName) -> void:
	var title := Label.new()
	title.text = tr(key)
	title.add_theme_font_size_override(&"font_size", 18)
	title.add_theme_color_override(&"font_color", Color("d9dde1"))
	parent.add_child(title)


func _add_option(parent: VBoxContainer, label_key: StringName, ids: Array[StringName], callback: Callable) -> void:
	var label := Label.new()
	label.text = tr(label_key)
	parent.add_child(label)
	var option := OptionButton.new()
	option.name = String(label_key)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: StringName in ids:
		option.add_item(tr("CHARACTER_CREATOR_%s" % String(id).to_upper()))
		option.set_item_metadata(option.item_count - 1, id)
	option.item_selected.connect(func(index: int) -> void: callback.call(option.get_item_metadata(index)))
	parent.add_child(option)


func _add_skin_palette(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = tr(&"CHARACTER_CREATOR_SKIN")
	parent.add_child(label)
	var row := HFlowContainer.new()
	row.name = "SkinPalette"
	parent.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for color: Color in CharacterAppearance.SKIN_PALETTE:
		var swatch := _make_color_swatch(color, _on_skin_color, group)
		row.add_child(swatch)
		_skin_swatches.append(swatch)


func _add_hair_palette(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = tr(&"CHARACTER_CREATOR_HAIR_COLOR")
	parent.add_child(label)
	var row := HFlowContainer.new()
	row.name = "HairPalette"
	parent.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for color: Color in HAIR_COLORS:
		var swatch := _make_color_swatch(color, _on_hair_color, group)
		row.add_child(swatch)
		_hair_swatches.append(swatch)


func _make_color_swatch(color: Color, callback: Callable, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(46, 38)
	button.toggle_mode = true
	button.button_group = group
	button.set_meta(&"palette_color", Color(color, 1.0))
	button.tooltip_text = "#%s" % color.to_html(false)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(1.0, 1.0, 1.0, 0.32)
	button.add_theme_stylebox_override(&"normal", normal)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.border_width_left = 3
	selected.border_width_top = 3
	selected.border_width_right = 3
	selected.border_width_bottom = 3
	selected.border_color = Color("d6e4e7")
	button.add_theme_stylebox_override(&"pressed", selected)
	button.add_theme_stylebox_override(&"hover_pressed", selected)
	button.pressed.connect(callback.bind(color))
	return button


func _add_morph_section(parent: VBoxContainer, title_key: StringName, ids: Array[StringName]) -> void:
	_add_section(parent, title_key)
	for id: StringName in ids:
		var row := HBoxContainer.new()
		parent.add_child(row)
		var label := Label.new()
		label.text = tr("CHARACTER_MORPH_%s" % String(id).to_upper())
		label.custom_minimum_size.x = 132.0
		label.tooltip_text = ""
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = String(id)
		slider.min_value = -1.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_morph_changed.bind(id))
		row.add_child(slider)
		_morph_controls[id] = slider
	_update_morph_availability()


func _update_morph_availability() -> void:
	for id: StringName in _morph_controls:
		var slider: Slider = _morph_controls[id]
		slider.editable = id in _supported_morphs
		slider.get_parent().visible = slider.editable
		slider.tooltip_text = "" if slider.editable else tr(&"CHARACTER_CREATOR_UNSUPPORTED_FIELD")
	if is_instance_valid(_unsupported_hint):
		_unsupported_hint.hide()


func _sync_controls() -> void:
	if _draft == null:
		return
	var body_option := find_child(String(&"CHARACTER_CREATOR_BODY_TYPE"), true, false) as OptionButton
	var hair_option := find_child(String(&"CHARACTER_CREATOR_HAIR"), true, false) as OptionButton
	_select_metadata(body_option, _draft.body_type)
	_select_metadata(hair_option, _draft.hair)
	_sync_palette(_skin_swatches, _draft.skin_tone)
	_sync_palette(_hair_swatches, _draft.hair_color)
	for id: StringName in _morph_controls:
		var value: float = _draft.face_morphs.get(id, _draft.body_morphs.get(id, 0.0))
		_morph_controls[id].set_value_no_signal(value)


func _sync_palette(swatches: Array[Button], value: Color) -> void:
	var best_index := -1
	var best_distance := INF
	for index: int in swatches.size():
		var color: Color = swatches[index].get_meta(&"palette_color")
		var distance := Vector3(color.r - value.r, color.g - value.g, color.b - value.b).length_squared()
		if distance < best_distance:
			best_distance = distance
			best_index = index
	for index: int in swatches.size():
		swatches[index].set_pressed_no_signal(index == best_index)


func _select_metadata(option: OptionButton, value: StringName) -> void:
	if option == null:
		return
	for index: int in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return


func _on_morph_changed(value: float, id: StringName) -> void:
	if _draft != null and id in _supported_morphs and _draft.set_morph(id, value):
		_apply_preview()


func _on_body_type(id: StringName) -> void:
	if _draft != null:
		_draft.body_type = id
		_draft.emit_changed()
		_apply_preview()


func _on_hair(id: StringName) -> void:
	if _draft != null:
		_draft.hair = id
		_draft.emit_changed()
		_apply_preview()


func _on_skin_color(color: Color) -> void:
	if _draft != null:
		_draft.skin_tone = Color(color, 1.0)
		_draft.emit_changed()
		_apply_preview()


func _on_hair_color(color: Color) -> void:
	if _draft != null:
		_draft.hair_color = Color(color, 1.0)
		_draft.emit_changed()
		_apply_preview()


func _apply_preview() -> void:
	if _draft != null and is_instance_valid(_preview_character) and _preview_character.has_method(&"apply_appearance"):
		_preview_character.call(&"apply_appearance", _draft)


func _attach_preview_character() -> void:
	if not is_instance_valid(_preview_root) or not is_instance_valid(_preview_character):
		return
	var old_parent := _preview_character.get_parent()
	if old_parent != null and old_parent != _preview_root:
		old_parent.remove_child(_preview_character)
	if _preview_character.get_parent() == null:
		_preview_root.add_child(_preview_character)
	_preview_character.position = Vector3.ZERO
	_preview_character.rotation = Vector3.ZERO
	_apply_preview()


func _add_preview_light(position: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 7.0
	_viewport.add_child(light)


func _set_view(full_body: bool) -> void:
	_full_body = full_body
	for index: int in _view_buttons.size():
		_view_buttons[index].set_pressed_no_signal(index == (1 if full_body else 0))
	_camera.position = Vector3(0.0, 0.95, -3.5) if full_body else Vector3(0.0, 1.52, -1.0)
	_camera.look_at(Vector3(0.0, 0.87, 0.0) if full_body else Vector3(0.0, 1.52, 0.0), Vector3.UP)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse.pressed
			_last_pointer = mouse.position
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step: float = 0.15 if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.15
			_camera.position.z = clampf(_camera.position.z - step, -4.2, -0.75)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_preview_root.rotate_y(-motion.relative.x * 0.008)
		_last_pointer = motion.position


func _confirm() -> void:
	if _draft != null:
		confirmed.emit(_draft.copy())
	visible = false


func _cancel() -> void:
	visible = false
	cancelled.emit()
