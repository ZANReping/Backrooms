class_name StatModifier
extends Resource

enum Operation {
	ADD_MAXIMUM,
	MULTIPLY_MAXIMUM,
}

@export var source_id: StringName = &""
@export var stat_id: StringName = &""
@export var operation: Operation = Operation.ADD_MAXIMUM
@export var amount: float = 0.0

func is_valid() -> bool:
	return not source_id.is_empty() and not stat_id.is_empty() and is_finite(amount)

func to_data() -> Dictionary:
	return {
		"source_id": String(source_id),
		"stat_id": String(stat_id),
		"operation": int(operation),
		"amount": amount,
	}

static func from_data(data: Dictionary) -> StatModifier:
	if not data.has("source_id") or not data.has("stat_id") or not data.has("operation") or not data.has("amount"):
		return null
	if not data["source_id"] is String or not data["stat_id"] is String:
		return null
	if not data["operation"] is int or not (data["amount"] is float or data["amount"] is int):
		return null
	var operation_value: int = data["operation"]
	if operation_value < Operation.ADD_MAXIMUM or operation_value > Operation.MULTIPLY_MAXIMUM:
		return null
	var modifier := StatModifier.new()
	modifier.source_id = StringName(data["source_id"])
	modifier.stat_id = StringName(data["stat_id"])
	modifier.operation = operation_value as Operation
	modifier.amount = float(data["amount"])
	return modifier if modifier.is_valid() else null
