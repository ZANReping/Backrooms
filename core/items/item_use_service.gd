class_name ItemUseService
extends RefCounted

signal phone_requested(uid: String)
signal notice_requested(key: StringName)

var inventory: InventoryModel
var stats: PlayerStats
var config: ItemUseConfig = ItemUseConfig.new()
var _handlers: Dictionary[StringName, Callable] = {}


func _init() -> void:
	_handlers[&"drink"] = _drink
	_handlers[&"phone"] = _phone
	_handlers[&"flashlight"] = _flashlight


func register_action(id: StringName, handler: Callable) -> void:
	_handlers[id] = handler


func use(uid: String) -> bool:
	if inventory == null or not inventory.is_owned(uid):
		return false
	var item: ItemInstance = inventory.get_item(uid)
	if item == null or not _handlers.has(item.definition.use_action):
		notice_requested.emit(&"NOTICE_NO_USE")
		return false
	var result: bool = bool(_handlers[item.definition.use_action].call(item))
	if result:
		inventory.changed.emit()
	return result


func _drink(item: ItemInstance) -> bool:
	var amount: float = item.contents.consume(config.sip_ml)
	if amount <= 0.0:
		notice_requested.emit(&"NOTICE_EMPTY")
		return false
	stats.change_value(&"thirst", config.thirst_per_sip * amount / config.sip_ml)
	notice_requested.emit(&"NOTICE_DRANK")
	return true


func _phone(item: ItemInstance) -> bool:
	if item.charge.current <= 0.0:
		notice_requested.emit(&"NOTICE_NO_CHARGE")
		return false
	phone_requested.emit(item.uid)
	return true


func _flashlight(item: ItemInstance) -> bool:
	if item.charge.current <= 0.0:
		notice_requested.emit(&"NOTICE_NO_CHARGE")
		return false
	item.custom_flags["enabled"] = not bool(item.custom_flags.get("enabled", false))
	return true
