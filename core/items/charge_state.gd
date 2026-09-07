class_name ChargeState
extends RefCounted

var current: float = 0.0
var maximum: float = 0.0


func consume(amount: float) -> bool:
	if amount < 0.0 or current < amount:
		return false
	current -= amount
	return true


func to_data() -> Dictionary:
	return {"current": current, "maximum": maximum}


func load_data(data: Dictionary) -> bool:
	if not DataValidation.bounded_number(data.get("maximum"), 0.0, 100000.0):
		return false
	if not DataValidation.bounded_number(data.get("current"), 0.0, float(data["maximum"])):
		return false
	maximum = float(data["maximum"])
	current = float(data["current"])
	return true
