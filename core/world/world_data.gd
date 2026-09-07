class_name WorldData
extends RefCounted

var level_id: StringName = &""
var entrance_id: StringName = &"default"
var seed: int = 42017
var flags: Dictionary = {}
var initialized_rooms: Array[StringName] = []
var world_items: Dictionary[String, Dictionary] = {}
var clock_seconds: float = 28800.0
var time_scale: float = 1.0


func to_data() -> Dictionary:
	var rooms: Array[String] = []
	for id: StringName in initialized_rooms:
		rooms.append(String(id))
	return {"level_id": String(level_id), "entrance_id": String(entrance_id), "seed": seed, "flags": flags.duplicate(true), "initialized_rooms": rooms, "world_items": world_items.duplicate(true), "clock_seconds": clock_seconds, "time_scale": time_scale}


func load_data(data: Dictionary) -> bool:
	if not data.get("level_id") is String or not data.get("entrance_id") is String or not data.get("seed") is int:
		return false
	if not data.get("flags") is Dictionary or not DataValidation.flags_valid(data["flags"]):
		return false
	if not data.get("initialized_rooms") is Array or not data.get("world_items") is Dictionary:
		return false
	if not DataValidation.bounded_number(data.get("clock_seconds"), 0.0, 1e12) or not DataValidation.bounded_number(data.get("time_scale"), 0.0, 100.0):
		return false
	var rooms: Array = data["initialized_rooms"]
	var records: Dictionary = data["world_items"]
	if rooms.size() > 1000 or records.size() > InventoryModel.MAX_ITEMS:
		return false
	var next_rooms: Array[StringName] = []
	for id: Variant in rooms:
		if not id is String or String(id).length() > 128 or StringName(id) in next_rooms:
			return false
		next_rooms.append(StringName(id))
	var next_records: Dictionary[String, Dictionary] = {}
	for uid: Variant in records:
		if not uid is String or not records[uid] is Dictionary:
			return false
		var row: Dictionary = records[uid]
		if not row.get("level_id") is String or not DataValidation.safe_transform(row.get("transform")):
			return false
		if not next_rooms.has(StringName(row["level_id"])):
			return false
		next_records[uid] = row.duplicate(true)
	level_id = StringName(data["level_id"])
	entrance_id = StringName(data["entrance_id"])
	seed = data["seed"]
	flags = data["flags"].duplicate(true)
	initialized_rooms = next_rooms
	world_items = next_records
	clock_seconds = float(data["clock_seconds"])
	time_scale = float(data["time_scale"])
	return true
