class_name InventoryView
extends Control

signal placement_requested(uid: String, container_uid: String, cell: Vector2i, rotation: int)
signal equip_requested(uid: String, slot: StringName)
signal drop_requested(uid: String)
signal use_requested(uid: String)
signal close_requested
signal stow_requested(uid: String, container_uid: String)
signal item_rotated(uid: String)

const EQUIPMENT_SLOTS: Array[StringName] = [
	&"head", &"face", &"torso", &"legs", &"feet", &"back", &"primary_hand",
	&"secondary_hand", &"accessory_1", &"accessory_2",
]
const EQUIPMENT_HOLD_SECONDS: float = 0.32

var _model: InventoryModel
var _capacity: float = 0.0
var _current_container_uid: String = ""
var _container_path: Array[String] = []
var _selected_uid: String = ""
var _selected_slot: StringName = &""
var _description_resolver: Callable
var _equipment_press_slot: StringName = &""
var _equipment_press_uid: String = ""
var _equipment_press_elapsed: float = 0.0
var _equipment_hold_started: bool = false

@onready var _container_title: Label = %ContainerTitle
@onready var _breadcrumb: Label = %Breadcrumb
@onready var _back_button: Button = %BackButton
@onready var _grid: InventoryGridView = %InventoryGrid
@onready var _empty_container: Label = %EmptyContainer
@onready var _weight_label: Label = %WeightLabel
@onready var _equipment_grid: GridContainer = %EquipmentGrid
@onready var _detail_name: Label = %DetailName
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_status: Label = %DetailStatus
@onready var _action_hint: Label = %ActionHint
@onready var _equip_target: OptionButton = %EquipTarget
@onready var _equip_button: Button = %EquipButton
@onready var _open_button: Button = %OpenButton
@onready var _use_button: Button = %UseButton
@onready var _drop_button: Button = %DropButton


func _ready() -> void:
	_grid.item_selected.connect(_on_item_selected)
	_grid.placement_requested.connect(placement_requested.emit)
	_grid.item_rotated.connect(item_rotated.emit)
	_grid.recommended_equip_requested.connect(equip_requested.emit)
	_grid.external_hold_released.connect(_on_grid_hold_released)
	_grid.hold_started.connect(_on_grid_hold_started)
	_grid.hold_ended.connect(_on_grid_hold_ended)
	_back_button.pressed.connect(_on_back_pressed)
	_equip_button.pressed.connect(_on_equip_pressed)
	_open_button.pressed.connect(_on_open_pressed)
	_use_button.pressed.connect(_on_use_pressed)
	_drop_button.pressed.connect(_on_drop_pressed)
	%CloseButton.pressed.connect(close_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


func _process(delta: float) -> void:
	if _equipment_press_slot.is_empty() or _equipment_press_uid.is_empty() or _equipment_hold_started:
		return
	_equipment_press_elapsed += delta
	if _equipment_press_elapsed >= EQUIPMENT_HOLD_SECONDS:
		_equipment_hold_started = true
		_grid.begin_hold(_equipment_press_uid)


func _input(event: InputEvent) -> void:
	if not _equipment_hold_started or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return
	_grid.finish_external_hold(event.global_position)
	_cancel_equipment_press()


func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	_cancel_equipment_press()
	_grid.cancel_interaction()
	if not visible:
		return
	_selected_uid = ""
	_selected_slot = &""
	if _model != null:
		refresh()


func _cancel_equipment_press() -> void:
	_equipment_press_slot = &""
	_equipment_press_uid = ""
	_equipment_press_elapsed = 0.0
	_equipment_hold_started = false
	set_process(false)


func bind_model(model: InventoryModel, capacity: float) -> void:
	if _model != null and _model.changed.is_connected(refresh):
		_model.changed.disconnect(refresh)
	_model = model
	_capacity = capacity
	_selected_uid = ""
	_selected_slot = &""
	_container_path.clear()
	_current_container_uid = _model.get_back_container() if _model != null else ""
	if not _current_container_uid.is_empty():
		_container_path.append(_current_container_uid)
	if _model != null:
		_model.changed.connect(refresh)
	refresh()


func set_description_resolver(resolver: Callable) -> void:
	_description_resolver = resolver
	if is_node_ready():
		_refresh_details()


func refresh() -> void:
	_validate_projection_state()
	_refresh_container()
	_refresh_equipment()
	_refresh_details()
	_weight_label.text = _format_translation(&"INVENTORY_WEIGHT", [_model.get_total_weight() if _model != null else 0.0, _capacity])


func _validate_projection_state() -> void:
	if _model == null:
		_current_container_uid = ""
		_container_path.clear()
		_selected_uid = ""
		return
	if not _selected_uid.is_empty() and (_model.get_item(_selected_uid) == null or not _model.is_owned(_selected_uid)):
		_selected_uid = ""
		_selected_slot = &""
	var valid_path: Array[String] = []
	var seen: Dictionary[String, bool] = {}
	for index: int in range(_container_path.size()):
		var uid: String = _container_path[index]
		if seen.has(uid) or _model.get_container(uid) == null or not _model.is_owned(uid):
			break
		if index > 0 and _model.get_parent_container(uid) != valid_path[index - 1]:
			break
		seen[uid] = true
		valid_path.append(uid)
	_container_path = valid_path
	if not _container_path.has(_current_container_uid):
		_current_container_uid = _model.get_back_container()
		_container_path.clear()
		if not _current_container_uid.is_empty() and _model.get_container(_current_container_uid) != null and _model.is_owned(_current_container_uid):
			_container_path.append(_current_container_uid)
		else:
			_current_container_uid = ""


func _refresh_container() -> void:
	var container: ContainerInstance = _model.get_container(_current_container_uid) if _model != null else null
	var has_container: bool = container != null and container.definition != null
	_grid.visible = has_container
	_empty_container.visible = not has_container
	_back_button.disabled = _container_path.size() <= 1
	_back_button.tooltip_text = tr(&"INVENTORY_BACK_ROOT_HINT") if _back_button.disabled else tr(&"INVENTORY_BACK_HINT")
	if not has_container:
		_container_title.text = tr(&"INVENTORY_NO_CONTAINER_TITLE")
		_breadcrumb.text = tr(&"INVENTORY_NO_CONTAINER")
		return
	_container_title.text = tr(container.definition.display_name)
	var crumbs: PackedStringArray = []
	for uid: String in _container_path:
		var item: ItemInstance = _model.get_item(uid)
		crumbs.append(tr(item.definition.display_name) if item != null and item.definition != null else tr(&"INVENTORY_ROOT"))
	_breadcrumb.text = "  ›  ".join(crumbs)
	_grid.bind_inventory(_model, _current_container_uid, _selected_uid)


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
		var item_name: String = tr(item.definition.display_name) if item != null and item.definition != null else tr(&"INVENTORY_EMPTY_SLOT")
		button.text = "%s\n%s" % [tr(_slot_key(slot)), item_name]
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.custom_minimum_size = Vector2(132.0, 54.0)
		button.tooltip_text = tr(&"INVENTORY_SLOT_HINT")
		button.gui_input.connect(_on_equipment_gui_input.bind(button, slot, uid))
		_equipment_grid.add_child(button)


func _on_equipment_gui_input(event: InputEvent, button: Button, slot: StringName, uid: String) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_equipment_press_slot = slot
		_equipment_press_uid = uid
		_equipment_press_elapsed = 0.0
		_equipment_hold_started = false
		set_process(not uid.is_empty())
	else:
		if _equipment_press_slot != slot:
			return
		if _equipment_hold_started:
			var release_global: Vector2 = button.get_global_transform_with_canvas() * event.position
			_grid.finish_external_hold(release_global)
		else:
			_on_slot_pressed(slot, uid)
		_cancel_equipment_press()


func _on_grid_hold_released(uid: String, global_position: Vector2) -> void:
	var item: ItemInstance = _model.get_item(uid) if _model != null else null
	if item == null or item.definition == null:
		return
	for index: int in range(_equipment_grid.get_child_count()):
		var button := _equipment_grid.get_child(index) as Button
		var slot: StringName = EQUIPMENT_SLOTS[index]
		if button.get_global_rect().has_point(global_position) and item.definition.equip_slots.has(slot):
			equip_requested.emit(uid, slot)
			return


func _on_grid_hold_started(_uid: String) -> void:
	pass


func _on_grid_hold_ended() -> void:
	pass


func _refresh_details() -> void:
	var item: ItemInstance = _model.get_item(_selected_uid) if _model != null else null
	var has_item: bool = item != null and item.definition != null
	var can_equip: bool = has_item and not item.definition.equip_slots.is_empty()
	var can_use: bool = has_item and item.definition.use_action != &""
	_detail_name.text = tr(item.definition.display_name) if has_item else tr(&"INVENTORY_NO_SELECTION")
	_detail_description.text = _resolve_description(item) if has_item else tr(&"INVENTORY_SELECT_HINT")
	_detail_status.text = _format_item_status(item) if has_item else ""
	_equip_target.clear()
	if can_equip:
		for slot: StringName in item.definition.equip_slots:
			_equip_target.add_item(tr(_slot_key(slot)))
			_equip_target.set_item_metadata(_equip_target.item_count - 1, slot)
	_equip_target.disabled = _equip_target.item_count == 0
	_equip_button.disabled = not can_equip
	_use_button.disabled = not can_use
	_drop_button.disabled = not has_item
	_open_button.visible = has_item and item.container_inventory != null
	_refresh_action_hints(has_item, can_equip, can_use)


func _refresh_action_hints(has_item: bool, can_equip: bool, can_use: bool) -> void:
	if not has_item:
		_action_hint.text = tr(&"INVENTORY_ACTION_HINT_NO_SELECTION")
		_equip_target.tooltip_text = tr(&"INVENTORY_EQUIP_TARGET_NO_SELECTION_HINT")
		_equip_button.tooltip_text = tr(&"INVENTORY_EQUIP_NO_SELECTION_HINT")
		_use_button.tooltip_text = tr(&"INVENTORY_USE_NO_SELECTION_HINT")
		_drop_button.tooltip_text = tr(&"INVENTORY_DROP_NO_SELECTION_HINT")
		return

	var hint_lines := PackedStringArray([tr(&"INVENTORY_ACTION_HINT_SELECTED")])
	if not can_equip:
		hint_lines.append(tr(&"INVENTORY_CANNOT_EQUIP_HINT"))
	if not can_use:
		hint_lines.append(tr(&"INVENTORY_CANNOT_USE_HINT"))
	_action_hint.text = "\n".join(hint_lines)
	_equip_target.tooltip_text = tr(&"INVENTORY_EQUIP_TARGET_HINT") if can_equip else tr(&"INVENTORY_CANNOT_EQUIP_HINT")
	_equip_button.tooltip_text = tr(&"INVENTORY_EQUIP_HINT") if can_equip else tr(&"INVENTORY_CANNOT_EQUIP_HINT")
	_use_button.tooltip_text = tr(&"INVENTORY_USE_HINT") if can_use else tr(&"INVENTORY_CANNOT_USE_HINT")
	_drop_button.tooltip_text = tr(&"INVENTORY_DROP_HINT")


func _format_item_status(item: ItemInstance) -> String:
	var lines := PackedStringArray([_format_translation(&"INVENTORY_CONDITION", [item.condition * 100.0]), _format_translation(&"INVENTORY_ITEM_WEIGHT", [_model.get_item_weight(item.uid)])])
	if item.charge != null and item.charge.maximum > 0.0:
		lines.append(_format_translation(&"INVENTORY_CHARGE", [item.charge.current, item.charge.maximum]))
	if item.contents != null and item.contents.maximum > 0.0:
		lines.append(_format_translation(&"INVENTORY_CONTENTS", [item.contents.current, item.contents.maximum, tr(String(item.contents.unit))]))
	return "\n".join(lines)


func _resolve_description(item: ItemInstance) -> String:
	if _description_resolver.is_valid():
		var resolved: Variant = _description_resolver.call(item.uid)
		if resolved is String and not String(resolved).is_empty():
			return String(resolved)
	return tr(item.definition.description_key)


func _format_translation(key: StringName, values: Array[Variant]) -> String:
	var translated: String = tr(key)
	if translated.count("%") < values.size():
		return translated
	return translated % values


func _on_item_selected(uid: String) -> void:
	_selected_uid = "" if _selected_uid == uid else uid
	_selected_slot = &""
	_grid.set_selection(_selected_uid)
	_refresh_details()
	_refresh_equipment()


func _on_slot_pressed(slot: StringName, uid: String) -> void:
	if uid == _selected_uid and slot == _selected_slot:
		_selected_slot = &""
		_selected_uid = ""
		_grid.set_selection("")
		_refresh_details()
		_refresh_equipment()
		return
	_selected_slot = slot
	_selected_uid = uid
	_grid.set_selection(uid)
	_refresh_details()
	_refresh_equipment()


func _on_back_pressed() -> void:
	if _container_path.size() <= 1:
		return
	_container_path.pop_back()
	_current_container_uid = _container_path.back()
	refresh()


func _on_open_pressed() -> void:
	var item: ItemInstance = _model.get_item(_selected_uid) if _model != null else null
	if item == null or item.container_inventory == null or not _model.is_owned(item.uid):
		return
	if _current_container_uid == item.uid or _container_path.has(item.uid):
		return
	var parent_uid: String = _model.get_parent_container(item.uid)
	if not parent_uid.is_empty() and parent_uid != _current_container_uid:
		return
	if parent_uid.is_empty():
		_container_path.clear()
	_current_container_uid = item.uid
	_container_path.append(item.uid)
	refresh()


func _on_equip_pressed() -> void:
	if _selected_uid.is_empty() or _equip_target.selected < 0:
		return
	var slot: StringName = _equip_target.get_item_metadata(_equip_target.selected)
	equip_requested.emit(_selected_uid, slot)


func _on_use_pressed() -> void:
	if _use_button.disabled or _selected_uid.is_empty() or _model == null:
		return
	var item: ItemInstance = _model.get_item(_selected_uid)
	if item == null or item.definition == null or item.definition.use_action == &"" or not _model.is_owned(item.uid):
		return
	use_requested.emit(_selected_uid)


func _on_drop_pressed() -> void:
	if not _selected_uid.is_empty():
		drop_requested.emit(_selected_uid)


func _slot_key(slot: StringName) -> StringName:
	return StringName("INVENTORY_SLOT_%s" % String(slot).to_upper())
