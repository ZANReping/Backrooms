class_name FieldInventoryView
extends InventoryView

const COMPACT_WIDTH := 1100.0

@onready var _body: HBoxContainer = %Body
@onready var _sidebar: PanelContainer = %Sidebar
@onready var _equipment_pane: VBoxContainer = %EquipmentPane
@onready var _details: PanelContainer = %Details
@onready var _show_equipment_button: Button = %ShowEquipmentButton

var _pane_tween: Tween
var _selected_thumbnail_button: Button
var _selected_thumbnail: TextureRect


func _ready() -> void:
	super()
	_pin_detail_actions()
	_show_equipment_button.pressed.connect(_on_show_equipment_pressed)
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_show_sidebar_pane(false, false)


func _pin_detail_actions() -> void:
	# Only the descriptive text scrolls. Long keepsake descriptions must not
	# push equipment/use/drop controls out of reach in the smallest window.
	var scroll := _details.get_child(0) as ScrollContainer
	var layout := VBoxContainer.new()
	layout.name = "DetailLayout"
	layout.add_theme_constant_override(&"separation", 10)
	_details.add_child(layout)
	_selected_thumbnail_button = Button.new()
	_selected_thumbnail_button.name = "SelectedItemThumbnailButton"
	_selected_thumbnail_button.custom_minimum_size = Vector2(58.0, 58.0)
	_selected_thumbnail_button.tooltip_text = tr(&"INVENTORY_SLOT_HINT")
	_selected_thumbnail_button.gui_input.connect(_on_selected_thumbnail_gui_input)
	_selected_thumbnail = TextureRect.new()
	_selected_thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	_selected_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selected_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_selected_thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_thumbnail_button.add_child(_selected_thumbnail)
	layout.add_child(_selected_thumbnail_button)
	_show_equipment_button.get_parent().reparent(layout)
	scroll.reparent(layout)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_status.reparent(layout)
	_action_hint.reparent(layout)
	_equip_target.reparent(layout)
	_equip_button.get_parent().reparent(layout)


func _apply_responsive_layout() -> void:
	var compact := size.x < COMPACT_WIDTH
	_equipment_grid.columns = 1
	_sidebar.custom_minimum_size.x = 270.0 if compact else 306.0
	_body.add_theme_constant_override(&"separation", 16 if compact else 24)


func _refresh_container() -> void:
	super()
	# A trail is useful only after entering a nested container; the root name
	# already appears in the heading.
	_back_button.visible = _container_path.size() > 1
	_breadcrumb.visible = _container_path.size() > 1


func _refresh_equipment() -> void:
	for child: Node in _equipment_grid.get_children():
		_equipment_grid.remove_child(child)
		child.queue_free()
	if _model == null:
		return
	for slot: StringName in EQUIPMENT_SLOTS:
		var button := Button.new()
		var uid: String = _model.equipment.get(slot, "")
		var item: ItemInstance = _model.get_item(uid)
		button.name = "Equipment_%s" % String(slot)
		button.theme_type_variation = &"EquipmentRow"
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.custom_minimum_size = Vector2(230.0, 52.0)
		button.tooltip_text = tr(&"INVENTORY_SLOT_HINT")
		button.gui_input.connect(_on_equipment_gui_input.bind(button, slot, uid))
		button.add_child(_make_equipment_row(slot, item))
		_equipment_grid.add_child(button)


func _make_equipment_row(slot: StringName, item: ItemInstance) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 9)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override(&"separation", 0)
	var slot_name := Label.new()
	slot_name.text = tr(_slot_key(slot))
	slot_name.add_theme_font_size_override(&"font_size", 13)
	slot_name.add_theme_color_override(&"font_color", Color(0.67, 0.75, 0.71))
	slot_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(slot_name)
	var item_name := Label.new()
	item_name.text = tr(item.definition.display_name) if item != null and item.definition != null else tr(&"INVENTORY_EMPTY_SLOT")
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_name.add_theme_font_size_override(&"font_size", 15)
	item_name.add_theme_color_override(&"font_color", Color(0.9, 0.93, 0.91) if item != null else Color(0.64, 0.71, 0.67))
	item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(item_name)
	row.add_child(copy)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(34.0, 34.0)
	thumbnail.texture = item.definition.icon if item != null and item.definition != null else null
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumbnail)
	return row


func _refresh_details() -> void:
	super()
	var item: ItemInstance = _model.get_item(_selected_uid) if _model != null else null
	if _selected_thumbnail_button != null:
		_selected_thumbnail_button.visible = item != null and item.definition != null
		_selected_thumbnail.texture = item.definition.icon if item != null and item.definition != null else null
	_show_sidebar_pane(not _selected_uid.is_empty(), is_node_ready())


func _on_selected_thumbnail_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_equipment_press_slot = &"selected_thumbnail"
		_equipment_press_uid = _selected_uid
		_equipment_press_elapsed = 0.0
		_equipment_hold_started = false
		set_process(not _selected_uid.is_empty())
	else:
		if _equipment_press_slot != &"selected_thumbnail":
			return
		if _equipment_hold_started:
			var release_global: Vector2 = _selected_thumbnail_button.get_global_transform_with_canvas() * event.position
			_grid.finish_external_hold(release_global)
		else:
			_on_show_equipment_pressed()
		_cancel_equipment_press()


func _show_sidebar_pane(show_details: bool, animate: bool) -> void:
	if not is_node_ready():
		return
	var incoming: Control = _details if show_details else _equipment_pane
	var outgoing: Control = _equipment_pane if show_details else _details
	if incoming.visible and not outgoing.visible:
		return
	if _pane_tween != null and _pane_tween.is_valid():
		_pane_tween.kill()
	incoming.visible = true
	outgoing.visible = false
	if not animate:
		incoming.modulate = Color.WHITE
		return
	incoming.modulate = Color(1.0, 1.0, 1.0, 0.0)
	# Keep the grid under the same cursor position when the sidebar changes.
	_pane_tween = create_tween().set_parallel(true)
	_pane_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pane_tween.tween_property(incoming, "modulate:a", 1.0, 0.16)


func _on_show_equipment_pressed() -> void:
	_selected_uid = ""
	_selected_slot = &""
	_grid.set_selection("")
	_refresh_details()
	_refresh_equipment()


func _on_grid_hold_started(_uid: String) -> void:
	_show_sidebar_pane(false, true)


func _on_grid_hold_ended() -> void:
	_show_sidebar_pane(not _selected_uid.is_empty(), true)
