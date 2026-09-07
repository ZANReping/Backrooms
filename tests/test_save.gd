extends SceneTree

const SAVE_PATH := "res://artifacts/save_test/foundation.save"
const SAVE_DIR := "res://artifacts/save_test"
const SaveServiceScript := preload("res://autoload/save_service.gd")

var _failed: bool = false
var _catalog: ItemCatalog
var _service: Node

func _initialize() -> void:
	_catalog = load("res://resources/items/catalog.tres") as ItemCatalog
	_service = SaveServiceScript.new()
	root.add_child(_service)
	_service.save_path = SAVE_PATH
	_service.catalog = _catalog
	var absolute_dir := ProjectSettings.globalize_path(SAVE_DIR)
	_check(DirAccess.make_dir_recursive_absolute(absolute_dir) == OK, "isolated save directory is available")
	_clear_test_files()
	_test_difficulty_and_complete_round_trip()
	_test_corrupt_primary_uses_backup()
	_test_invalid_snapshots_do_not_change_live_data()
	_test_extreme_death_is_scoped_to_run()
	_clear_test_files()
	_service.queue_free()
	if _failed:
		quit(1)
	else:
		print("PASS: permanent save regression")
		quit(0)

func _test_difficulty_and_complete_round_trip() -> void:
	var casual := _fixture(SessionData.Difficulty.CASUAL, "run-casual")
	casual.preferences["difficulty"] = int(SessionData.Difficulty.EXTREME)
	_check(casual.session.inventory.validate(), "fixture inventory validates")
	_check(SaveSnapshot.from_data(casual.to_data(), _catalog) != null, "fixture snapshot validates")
	_check(_service.write_snapshot(casual, false), "Casual permits manual save")
	var loaded: SaveSnapshot = _service.read_snapshot()
	_check(loaded != null, "Casual save reads")
	if loaded != null:
		_check(loaded.session.run_id == "run-casual" and loaded.session.difficulty == SessionData.Difficulty.CASUAL, "settings cannot override run metadata or difficulty")
		_check(loaded.preferences == casual.preferences, "settings round-trip without changing run metadata")
		_check(loaded.player_transform == casual.player_transform, "player transform round-trips")
		_check(loaded.world.to_data() == casual.world.to_data(), "world state and world item transforms round-trip")
		_check(loaded.session.phone.to_data() == casual.session.phone.to_data(), "phone state round-trips")
		var model := loaded.session.inventory
		_check(model.equipment == casual.session.inventory.equipment, "equipment slots round-trip")
		_check(model.get_parent_container("pouch-save") == "bag-save" and model.get_parent_container("light-save") == "pouch-save", "nested inventory ownership round-trips")
		_check(model.get_placement("pouch-save").cell == Vector2i(0, 0) and model.get_placement("light-save").rotation == 1, "nested layout and rotation round-trip")
		_check(is_equal_approx(model.get_item("phone-save").charge.current, 67.0), "charge round-trips")
		_check(is_equal_approx(model.get_item("water-save").contents.current, 380.0), "liquid contents round-trip")
	_clear_test_files()
	var hardcore := _fixture(SessionData.Difficulty.HARDCORE, "run-hardcore")
	_check(not _service.write_snapshot(hardcore, false), "Hardcore rejects manual save")
	_check(_service.write_snapshot(hardcore, true), "Hardcore permits automatic save")
	_clear_test_files()
	var extreme := _fixture(SessionData.Difficulty.EXTREME, "run-extreme")
	_check(not _service.write_snapshot(extreme, false), "Extreme rejects manual save")
	_check(_service.write_snapshot(extreme, true), "Extreme permits automatic save")

func _test_corrupt_primary_uses_backup() -> void:
	_clear_test_files()
	var first := _fixture(SessionData.Difficulty.CASUAL, "backup-run")
	first.world.clock_seconds = 111.0
	_check(_service.write_snapshot(first, false), "initial backup fixture saves")
	var second := _fixture(SessionData.Difficulty.CASUAL, "primary-run")
	second.world.clock_seconds = 222.0
	_check(_service.write_snapshot(second, false), "second save creates backup")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "primary can be corrupted inside test directory")
	if file != null:
		file.store_string("corrupt primary")
		file.close()
	var recovered: SaveSnapshot = _service.read_snapshot()
	_check(recovered != null and recovered.session.run_id == "backup-run" and is_equal_approx(recovered.world.clock_seconds, 111.0), "corrupt primary falls back to valid backup")

func _test_invalid_snapshots_do_not_change_live_data() -> void:
	var live := _fixture(SessionData.Difficulty.CASUAL, "live-run")
	var live_before := live.to_data()
	var future := live.to_data().duplicate(true)
	future["schema_version"] = SaveSnapshot.SCHEMA_VERSION + 1
	_check(SaveSnapshot.from_data(future, _catalog) == null, "future schema is rejected")
	var unknown_uid := live.to_data().duplicate(true)
	unknown_uid["world"]["world_items"]["water-save"] = unknown_uid["world"]["world_items"]["water-save"].duplicate(true)
	unknown_uid["world"]["world_items"]["ghost"] = unknown_uid["world"]["world_items"]["water-save"].duplicate(true)
	_check(SaveSnapshot.from_data(unknown_uid, _catalog) == null, "unknown world item UID is rejected")
	var invalid_stat := live.to_data().duplicate(true)
	invalid_stat["session"]["stats"]["values"]["health"] = -1.0
	_check(SaveSnapshot.from_data(invalid_stat, _catalog) == null, "invalid stat is rejected")
	var invalid_transform := live.to_data().duplicate(true)
	var nan_transform: Transform3D = Transform3D.IDENTITY
	nan_transform.origin.x = NAN
	invalid_transform["player_transform"] = nan_transform
	_check(SaveSnapshot.from_data(invalid_transform, _catalog) == null, "NaN player transform is rejected")
	_check(live.to_data() == live_before, "invalid imports do not mutate the live session snapshot")

func _test_extreme_death_is_scoped_to_run() -> void:
	_clear_test_files()
	var other := _fixture(SessionData.Difficulty.EXTREME, "other-extreme-run")
	_check(_service.write_snapshot(other, true), "other Extreme run saves")
	_check(_service.finalize_extreme_death("dead-extreme-run"), "mismatched death finalization completes safely")
	_check(_service.has_save(), "mismatched run ID does not delete another run")
	var matching := _fixture(SessionData.Difficulty.EXTREME, "dead-extreme-run")
	_check(_service.write_snapshot(matching, true), "matching Extreme run saves and preserves other run as backup")
	_check(_service.finalize_extreme_death("dead-extreme-run"), "matching Extreme death finalizes")
	_check(not FileAccess.file_exists(SAVE_PATH), "matching Extreme primary is deleted")
	_check(FileAccess.file_exists(SAVE_PATH + ".bak"), "different-run backup is preserved")
	var preserved: SaveSnapshot = _service.read_snapshot()
	_check(preserved != null and preserved.session.run_id == "other-extreme-run", "preserved backup remains loadable")
	_clear_test_files()
	var casual := _fixture(SessionData.Difficulty.CASUAL, "same-id-non-extreme")
	_check(_service.write_snapshot(casual, false), "same-ID Casual save fixture writes")
	_check(_service.finalize_extreme_death("same-id-non-extreme") and _service.has_save(), "Extreme finalizer never deletes non-Extreme save")

func _fixture(difficulty: SessionData.Difficulty, run_id: String) -> SaveSnapshot:
	var result := SaveSnapshot.new()
	result.session = SessionData.new()
	result.session.run_id = run_id
	result.session.difficulty = difficulty
	result.session.stats.change_value(&"health", -7.0)
	result.session.stats.change_value(&"thirst", -12.0)
	result.session.stats.change_value(&"fatigue", 3.0)
	var model := result.session.inventory
	var bag := model.add_item(_catalog.find(&"commuter_bag"), "bag-save")
	var pouch := model.add_item(_catalog.find(&"pouch"), "pouch-save")
	var phone := model.add_item(_catalog.find(&"phone"), "phone-save")
	var light := model.add_item(_catalog.find(&"flashlight"), "light-save")
	var water := model.add_item(_catalog.find(&"water"), "water-save")
	model.equip(bag.uid, &"back")
	model.equip(phone.uid, &"secondary_hand")
	model.try_place(pouch.uid, bag.uid, Vector2i(0, 0), 0)
	model.try_place(light.uid, pouch.uid, Vector2i(0, 0), 1)
	phone.charge.consume(33.0)
	water.contents.consume(120.0)
	result.session.phone.send_message("Remember the yellow corridor.")
	result.session.phone.set_active_app(&"maps")
	result.session.phone.offline = true
	result.world = WorldData.new()
	result.world.level_id = &"test_room_a"
	result.world.entrance_id = &"from_b"
	result.world.seed = 90125
	result.world.flags = {"fixture_seen": true, "fixture_count": 2}
	result.world.initialized_rooms = [&"test_room_a"]
	result.world.clock_seconds = 30123.5
	result.world.time_scale = 3.0
	result.world.world_items[water.uid] = {
		"level_id": "test_room_a",
		"transform": Transform3D(Basis.from_euler(Vector3(0.0, 0.4, 0.0)), Vector3(2.0, 0.3, -1.0)),
	}
	result.player_transform = Transform3D(Basis.from_euler(Vector3(0.0, 0.75, 0.0)), Vector3(4.0, 1.0, -2.0))
	result.preferences = {"immersive_hud": false, "headbob": false}
	return result

func _clear_test_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
