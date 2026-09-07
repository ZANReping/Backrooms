class_name SessionData
extends RefCounted

enum Difficulty { CASUAL, HARDCORE, EXTREME }

var run_id: String = ""
var difficulty: Difficulty = Difficulty.CASUAL
var stats: PlayerStats = PlayerStats.new()
var inventory: InventoryModel = InventoryModel.new()
var phone: PhoneState = PhoneState.new()
var profile: CharacterProfile = CharacterProfile.new()
var prologue: PrologueState = PrologueState.new()
var album: PhotoAlbumState = PhotoAlbumState.new()
var story_date: Dictionary = {"year": 2026, "month": 10, "day": 18}


func to_data() -> Dictionary:
	return {"run_id": run_id, "difficulty": int(difficulty), "stats": stats.to_data(), "inventory": inventory.to_data(), "phone": phone.to_data(), "profile": profile.to_data(), "prologue": prologue.to_data(), "album": album.to_data(), "story_date": story_date.duplicate()}


func load_data(data: Dictionary, catalog: ItemCatalog) -> bool:
	if not data.get("run_id") is String or String(data["run_id"]).is_empty() or String(data["run_id"]).length() > 128:
		return false
	if not data.get("difficulty") is int or int(data["difficulty"]) < 0 or int(data["difficulty"]) > 2:
		return false
	if not data.get("stats") is Dictionary or not data.get("inventory") is Dictionary or not data.get("phone") is Dictionary:
		return false
	var next_stats: PlayerStats = PlayerStats.new()
	var next_inventory: InventoryModel = InventoryModel.new()
	var next_phone: PhoneState = PhoneState.new()
	var next_profile: CharacterProfile = CharacterProfile.new()
	var next_prologue: PrologueState = PrologueState.new()
	var next_album: PhotoAlbumState = PhotoAlbumState.new()
	if not data.get("profile") is Dictionary or not data.get("prologue") is Dictionary or not data.get("album") is Dictionary or not data.get("story_date") is Dictionary:
		return false
	if not next_profile.load_data(data["profile"], data["story_date"]) or not next_prologue.load_data(data["prologue"]) or not next_album.load_data(data["album"]):
		return false
	if next_prologue.enabled and next_prologue.stage >= PrologueState.Stage.PREPARE and not next_profile.registered:
		return false
	if not next_stats.load_data(data["stats"]) or not next_inventory.load_data(data["inventory"], catalog) or not next_phone.load_data(data["phone"]):
		return false
	run_id = data["run_id"]
	difficulty = int(data["difficulty"]) as Difficulty
	stats = next_stats
	inventory = next_inventory
	phone = next_phone
	profile = next_profile
	prologue = next_prologue
	album = next_album
	story_date = data["story_date"].duplicate()
	return true
