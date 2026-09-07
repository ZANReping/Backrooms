extends Node

signal result_reported(message_key: StringName)

const MAGIC: String = "BACKROOMS_M1_V1"
const MAX_BYTES: int = 4194304

var save_path: String = "user://foundation.save"
var catalog: ItemCatalog
var photo_storage: PhotoStorage = PhotoStorage.new()
var photo_gc_enabled: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func write_snapshot(snapshot: SaveSnapshot, automatic: bool = false) -> bool:
	if snapshot == null or (not automatic and snapshot.session.difficulty != SessionData.Difficulty.CASUAL):
		result_reported.emit(&"ERR_MANUAL_SAVE")
		return false
	if SaveSnapshot.from_data(snapshot.to_data(), catalog) == null:
		result_reported.emit(&"ERR_SAVE")
		return false
	var bytes: PackedByteArray = var_to_bytes(snapshot.to_data())
	if bytes.size() > MAX_BYTES:
		return false
	var file: FileAccess = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		result_reported.emit(&"ERR_SAVE")
		return false
	file.store_line(MAGIC)
	file.store_line(_digest(bytes))
	file.store_buffer(bytes)
	file.flush()
	var file_error: Error = file.get_error()
	file.close()
	if file_error != OK:
		result_reported.emit(&"ERR_SAVE")
		return false
	if FileAccess.file_exists(save_path):
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			result_reported.emit(&"ERR_SAVE")
			return false
	var error: Error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error == OK and photo_gc_enabled and PhotoAlbumState.valid_id(snapshot.session.run_id):
		var retained_runs: Array[String] = [snapshot.session.run_id]
		var backup: SaveSnapshot = _read_file(save_path + ".bak")
		if backup != null:
			retained_runs.append(backup.session.run_id)
		if backup != null or not FileAccess.file_exists(save_path + ".bak"):
			photo_storage.remove_unreferenced_runs(retained_runs)
	result_reported.emit(&"NOTICE_SAVED" if error == OK else &"ERR_SAVE")
	return error == OK


func read_snapshot() -> SaveSnapshot:
	var snapshot: SaveSnapshot = _read_file(save_path)
	if snapshot == null:
		snapshot = _read_file(save_path + ".bak")
		if snapshot != null:
			result_reported.emit(&"NOTICE_BACKUP")
	if snapshot == null:
		result_reported.emit(&"ERR_LOAD")
	return snapshot


func _read_file(path: String) -> SaveSnapshot:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES + 128 or file.get_length() < 80:
		return null
	if file.get_line() != MAGIC:
		return null
	var digest: String = file.get_line()
	var bytes: PackedByteArray = file.get_buffer(file.get_length() - file.get_position())
	if digest != _digest(bytes):
		return null
	var decoded: Variant = bytes_to_var(bytes)
	if not decoded is Dictionary:
		return null
	return SaveSnapshot.from_data(decoded, catalog)


func finalize_extreme_death(run_id: String) -> bool:
	# Called only after the death summary's menu action, scoped to the dead run.
	var matched_extreme: bool = false
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = save_path + suffix
		var snapshot: SaveSnapshot = _read_file(path)
		if snapshot != null and snapshot.session.run_id == run_id and snapshot.session.difficulty == SessionData.Difficulty.EXTREME:
			matched_extreme = true
			if DirAccess.remove_absolute(path) != OK:
				return false
	if matched_extreme and PhotoAlbumState.valid_id(run_id):
		return photo_storage.erase_run(run_id)
	return true


func _digest(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
