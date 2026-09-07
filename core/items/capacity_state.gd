class_name CapacityState
extends RefCounted

var current: float = 0.0
var maximum: float = 0.0
var unit: StringName = &"ml"
var content_type: StringName = &"water"


func consume(amount: float) -> float:
	var consumed: float = minf(current, maxf(amount, 0.0))
	current -= consumed
	return consumed


func to_data() -> Dictionary:
	return {"current": current, "maximum": maximum, "unit": String(unit), "content_type": String(content_type)}


func load_data(data: Dictionary) -> bool:
	if not DataValidation.bounded_number(data.get("maximum"), 0.0, 100000.0):
		return false
	if not DataValidation.bounded_number(data.get("current"), 0.0, float(data["maximum"])):
		return false
	if not data.get("unit") is String or not data.get("content_type") is String:
		return false
	maximum = float(data["maximum"])
	current = float(data["current"])
	unit = StringName(data["unit"])
	content_type = StringName(data["content_type"])
	return true
