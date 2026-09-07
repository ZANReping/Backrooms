class_name SaveSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 3

var session: SessionData
var world: WorldData
var player_transform: Transform3D
var preferences: Dictionary


func to_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "session": session.to_data(), "world": world.to_data(), "player_transform": player_transform, "settings": preferences.duplicate()}


static func from_data(data: Dictionary, catalog: ItemCatalog) -> SaveSnapshot:
	if not data.get("schema_version") is int or int(data["schema_version"]) not in [1, 2, SCHEMA_VERSION]:
		return null
	if data["schema_version"] == 1:
		data = _migrate_v1(data)
	if data["schema_version"] == 2:
		data = _migrate_v2(data)
	if not data.get("session") is Dictionary or not data.get("world") is Dictionary or not data.get("settings") is Dictionary:
		return null
	if not data["session"].get("profile") is Dictionary or not data["session"]["profile"].get("appearance") is Dictionary:
		return null
	if not DataValidation.safe_transform(data.get("player_transform")):
		return null
	var result: SaveSnapshot = SaveSnapshot.new()
	result.session = SessionData.new()
	result.world = WorldData.new()
	if not result.session.load_data(data["session"], catalog) or not result.world.load_data(data["world"]):
		return null
	if result.session.stats.get_value(&"health") <= 0.0:
		return null
	var settings_data: Dictionary = data["settings"]
	if not settings_data.get("immersive_hud") is bool or not settings_data.get("headbob") is bool:
		return null
	for key: StringName in PreferenceSchema.DEFAULTS:
		if settings_data.has(String(key)) and not PreferenceSchema.valid_value(key, settings_data[String(key)]):
			return null
	# Each item is in exactly one equipment/container tree or a world record.
	var model: InventoryModel = result.session.inventory
	for uid: String in result.world.world_items:
		if not model.items.has(uid) or model.is_owned(uid) or not model.get_parent_container(uid).is_empty():
			return null
	for uid: String in model.items:
		if not model.is_owned(uid) and model.get_parent_container(uid).is_empty() and not result.world.world_items.has(uid):
			return null
	result.player_transform = data["player_transform"]
	result.preferences = settings_data.duplicate()
	return result


static func _migrate_v1(source: Dictionary) -> Dictionary:
	var migrated: Dictionary = source.duplicate(true)
	if migrated.get("session") is Dictionary:
		var defaults: SessionData = SessionData.new()
		for key: String in ["profile", "prologue", "album", "story_date"]:
			migrated["session"][key] = defaults.to_data()[key]
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated


static func _migrate_v2(source: Dictionary) -> Dictionary:
	var migrated: Dictionary = source.duplicate(true)
	if migrated.get("session") is Dictionary:
		var session_data: Dictionary = migrated["session"]
		if session_data.get("profile") is Dictionary:
			var profile_data: Dictionary = session_data["profile"]
			if profile_data.get("appearance_preset") is Dictionary:
				profile_data["appearance"] = CharacterAppearance.from_legacy(profile_data["appearance_preset"], String(session_data.get("run_id", "")).hash()).to_data()
			# Early M2 confused building age with the story timeline. Preserve
			# fictional character age when correcting that prototype date.
			var date: Variant = session_data.get("story_date")
			if date is Dictionary and date.get("year") == 2010:
				date["year"] = 2026
				var birth: Variant = profile_data.get("birth_date")
				if birth is Dictionary and birth.get("year") is int:
					birth["year"] += 16
				var employee: Variant = profile_data.get("employee_id")
				if employee is String and employee.begins_with("201018"):
					profile_data["employee_id"] = "261018" + employee.substr(6)
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated
