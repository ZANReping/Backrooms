class_name PrologueState
extends RefCounted

enum Stage { ALARM, REGISTRATION, PREPARE, COMMUTE, ARRIVED }

const VALID_TUTORIALS: Array[String] = [
	"move", "look", "phone", "inventory", "inspect_laptop",
	"rotate", "equipment", "keys", "wallet", "leave_hint",
]

var enabled: bool = false
var stage: Stage = Stage.ALARM
var alarm_active: bool = true
var bought_water: bool = false
var credits: int = 40
var tutorial_flags: Dictionary[String, bool] = {}


func mark_tutorial(id: String) -> void:
	if id in VALID_TUTORIALS:
		tutorial_flags[id] = true


func has_tutorial(id: String) -> bool:
	return tutorial_flags.get(id, false)


func to_data() -> Dictionary:
	return {
		"enabled": enabled,
		"stage": int(stage),
		"alarm_active": alarm_active,
		"bought_water": bought_water,
		"credits": credits,
		"tutorial_flags": tutorial_flags.duplicate(true),
	}


func load_data(data: Dictionary) -> bool:
	var required: Array[String] = ["enabled", "stage", "alarm_active", "bought_water", "credits", "tutorial_flags"]
	for key: String in required:
		if not data.has(key):
			return false
	if not data["enabled"] is bool or not data["stage"] is int:
		return false
	if not data["alarm_active"] is bool or not data["bought_water"] is bool:
		return false
	if not data["credits"] is int or not data["tutorial_flags"] is Dictionary:
		return false
	var next_stage: int = data["stage"]
	var next_credits: int = data["credits"]
	if next_stage < Stage.ALARM or next_stage > Stage.ARRIVED or next_credits < 0 or next_credits > 10000:
		return false
	var next_flags: Dictionary[String, bool] = {}
	for raw_key: Variant in data["tutorial_flags"]:
		if not raw_key is String or String(raw_key) not in VALID_TUTORIALS:
			return false
		var raw_value: Variant = data["tutorial_flags"][raw_key]
		if not raw_value is bool:
			return false
		next_flags[String(raw_key)] = raw_value
	enabled = data["enabled"]
	stage = next_stage as Stage
	alarm_active = data["alarm_active"]
	bought_water = data["bought_water"]
	credits = next_credits
	tutorial_flags = next_flags
	return true
