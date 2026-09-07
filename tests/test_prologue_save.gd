extends SceneTree

const SAVE_DIR := "res://artifacts/prologue_save"
const SAVE_PATH := SAVE_DIR + "/schema3.save"
const PHOTO_DIR := SAVE_DIR + "/photos"
const PHOTO_GC_DIR := SAVE_DIR + "/photos_gc"
const RUN_A := "0123456789abcdef0123456789abcdef"
const RUN_B := "fedcba9876543210fedcba9876543210"
const RUN_C := "cccccccccccccccccccccccccccccccc"
const RUN_D := "dddddddddddddddddddddddddddddddd"
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
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PHOTO_DIR)) == OK, "isolated artifact directory is available")
	_clear_save_files()
	_test_v1_migration_and_schema3_write()
	_test_complete_schema3_roundtrip()
	_test_v2_character_migration()
	_test_atomic_rejections()
	_test_photo_storage()
	_test_photo_gc_save_rotation()
	_clear_save_files()
	_service.queue_free()
	if _failed:
		quit(1)
		return
	print("PASS: prologue schema 3 save")
	quit(0)


func _test_v1_migration_and_schema3_write() -> void:
	var current: SaveSnapshot = _fixture(RUN_A)
	var legacy: Dictionary = current.to_data().duplicate(true)
	legacy["schema_version"] = 1
	for key: String in ["profile", "prologue", "album", "story_date"]:
		legacy["session"].erase(key)
	var migrated: SaveSnapshot = SaveSnapshot.from_data(legacy, _catalog)
	_check(migrated != null, "schema 1 dictionary migrates")
	if migrated == null:
		return
	_check(not migrated.session.prologue.enabled and migrated.session.prologue.stage == PrologueState.Stage.ALARM, "schema 1 migration does not start prologue")
	_check(not migrated.session.profile.registered and migrated.session.album.photos.is_empty(), "schema 1 migration injects compatible defaults")
	_check(_service.write_snapshot(migrated, false), "migrated snapshot writes through the real save container")
	var loaded: SaveSnapshot = _service.read_snapshot()
	_check(loaded != null and loaded.to_data()["schema_version"] == 3, "migrated save is persisted as schema 3")
	_clear_save_files()


func _test_complete_schema3_roundtrip() -> void:
	var source: SaveSnapshot = _fixture(RUN_A)
	_check(_service.write_snapshot(source, false), "schema 3 snapshot writes")
	var loaded: SaveSnapshot = _service.read_snapshot()
	_check(loaded != null, "schema 3 snapshot reads")
	if loaded == null:
		return
	_check(loaded.session.profile.to_data() == source.session.profile.to_data(), "registered character profile round-trips")
	_check(loaded.session.prologue.to_data() == source.session.prologue.to_data(), "prologue stage and tutorial state round-trip")
	_check(loaded.session.album.to_data() == source.session.album.to_data(), "photo metadata round-trips")
	_check(loaded.session.phone.messages[0]["text"] == "明早别忘了带钥匙 — Zoë", "free Unicode phone message round-trips")
	var model: InventoryModel = loaded.session.inventory
	_check(model.get_parent_container("pouch-prologue") == "bag-prologue" and model.get_parent_container("light-prologue") == "pouch-prologue", "nested bag UID ownership round-trips")
	_check(model.get_placement("light-prologue").rotation == 1, "nested rotated placement round-trips")
	_check(is_equal_approx(model.get_item("water-prologue").contents.current, 375.0), "liquid content and UID round-trip")
	_check(is_equal_approx(model.get_total_weight(), source.session.inventory.get_total_weight()), "recursive equipped weight round-trips")
	_clear_save_files()


func _test_v2_character_migration() -> void:
	var legacy: Dictionary = _fixture(RUN_A).to_data()
	legacy["schema_version"] = 2
	legacy["session"]["story_date"]["year"] = 2010
	legacy["session"]["profile"]["birth_date"] = {"year": 1988, "month": 3, "day": 2}
	legacy["session"]["profile"].erase("appearance")
	var before: Dictionary = legacy.duplicate(true)
	var migrated := SaveSnapshot.from_data(legacy, _catalog)
	_check(migrated != null, "schema 2 character migrates")
	if migrated != null:
		_check(migrated.session.story_date["year"] == 2026, "prototype story year corrected")
		_check(migrated.session.profile.birth_date["year"] == 2004 and migrated.session.profile.age_on(migrated.session.story_date) == 22, "age is preserved by timeline migration")
		_check(not migrated.session.profile.appearance.to_data().is_empty(), "legacy preset becomes independent appearance data")
	_check(legacy == before, "migration never mutates caller snapshot")


func _test_atomic_rejections() -> void:
	var live: SessionData = _fixture(RUN_A).session
	var before: Dictionary = live.to_data()
	var malformed_profile: Dictionary = before.duplicate(true)
	malformed_profile["profile"]["employee_id"] = "../escape"
	_check(not live.load_data(malformed_profile, _catalog), "malformed registered profile is rejected")
	_check(live.to_data() == before, "malformed profile rejection is atomic")
	var malformed_appearance: Dictionary = before.duplicate(true)
	malformed_appearance["profile"]["appearance"]["face_morphs"]["nose_width"] = NAN
	_check(not live.load_data(malformed_appearance, _catalog), "nonfinite character morph is rejected")
	_check(live.to_data() == before, "invalid appearance rejection is atomic")
	var malformed_date: Dictionary = before.duplicate(true)
	malformed_date["story_date"] = {"year": 2026, "month": 2, "day": 29}
	_check(not live.load_data(malformed_date, _catalog), "invalid story date is rejected")
	_check(live.to_data() == before, "invalid story date rejection is atomic")
	var traversal: Dictionary = before.duplicate(true)
	traversal["album"]["photos"][0]["id"] = "../../outside.webp"
	_check(not live.load_data(traversal, _catalog), "photo path traversal metadata is rejected")
	_check(live.to_data() == before, "path traversal rejection is atomic")
	var duplicate: Dictionary = before.duplicate(true)
	duplicate["album"]["photos"].append(duplicate["album"]["photos"][0].duplicate(true))
	_check(not live.load_data(duplicate, _catalog), "duplicate photo ID is rejected")
	_check(live.to_data() == before, "duplicate photo rejection is atomic")
	var future: Dictionary = _fixture(RUN_A).to_data()
	future["schema_version"] = SaveSnapshot.SCHEMA_VERSION + 1
	_check(SaveSnapshot.from_data(future, _catalog) == null, "future save schema is rejected")


func _test_photo_storage() -> void:
	var storage := PhotoStorage.new()
	storage.base_path = PHOTO_DIR
	storage.erase_run(RUN_A)
	storage.erase_run(RUN_B)
	var album_a := PhotoAlbumState.new()
	var album_b := PhotoAlbumState.new()
	var image := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color("6f8fa8"))
	var photo_a: String = storage.capture(RUN_A, image, album_a, 28080.0)
	var photo_b: String = storage.capture(RUN_B, image, album_b, 28081.0)
	_check(PhotoAlbumState.valid_id(photo_a) and PhotoAlbumState.valid_id(photo_b), "small images capture to generated hex IDs")
	var texture: Texture2D = storage.read(RUN_A, photo_a)
	_check(texture != null and texture.get_width() == 8 and texture.get_height() == 6, "captured WebP reads back through FileAccess")
	_check(storage.capture("../bad-run", image, album_a, 1.0).is_empty(), "capture rejects invalid run ID")
	_check(storage.read("../bad-run", photo_a) == null and not storage.erase_run("../bad-run"), "read and erase reject invalid run ID")
	var missing_snapshot: SaveSnapshot = _fixture(RUN_A)
	missing_snapshot.session.album = album_a
	_check(storage.erase_run(RUN_A), "first run photo files erase")
	_check(storage.read(RUN_A, photo_a) == null, "missing image reads as absent")
	_check(SaveSnapshot.from_data(missing_snapshot.to_data(), _catalog) != null, "missing image does not invalidate save metadata")
	_check(storage.read(RUN_B, photo_b) != null, "erasing one run preserves another run")
	_check(storage.erase_run(RUN_B), "second isolated run cleans up")


func _test_photo_gc_save_rotation() -> void:
	_clear_save_files()
	var storage := PhotoStorage.new()
	storage.base_path = PHOTO_GC_DIR
	_prepare_gc_directory(storage)
	_service.photo_storage = storage
	_service.photo_gc_enabled = true
	var image := Image.create(5, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("936f62"))
	var albums: Dictionary[String, PhotoAlbumState] = {}
	var photo_ids: Dictionary[String, String] = {}
	for run_id: String in [RUN_A, RUN_B, RUN_C]:
		var album := PhotoAlbumState.new()
		albums[run_id] = album
		photo_ids[run_id] = storage.capture(run_id, image, album, 28100.0)
		_check(PhotoAlbumState.valid_id(photo_ids[run_id]), "GC fixture captures photo for %s" % run_id.left(1))
		var snapshot: SaveSnapshot = _fixture(run_id)
		snapshot.session.album = album
		_check(_service.write_snapshot(snapshot, false), "GC fixture saves run %s" % run_id.left(1))
		if run_id == RUN_B:
			_check(storage.read(RUN_A, photo_ids[RUN_A]) != null, "writing B retains A backup photos")
			_check(storage.read(RUN_B, photo_ids[RUN_B]) != null, "writing B retains B primary photos")
			var run_foreign: FileAccess = FileAccess.open(PHOTO_GC_DIR.path_join(RUN_A).path_join("foreign.txt"), FileAccess.WRITE)
			_check(run_foreign != null, "foreign file in a valid run directory can be created")
			if run_foreign:
				run_foreign.store_string("preserve")
				run_foreign.close()
	_check(storage.read(RUN_A, photo_ids[RUN_A]) == null, "writing C removes unreferenced A photos")
	_check(FileAccess.file_exists(PHOTO_GC_DIR.path_join(RUN_A).path_join("foreign.txt")), "GC preserves non-WebP files in valid run directories")
	_check(storage.read(RUN_B, photo_ids[RUN_B]) != null, "writing C retains B backup photos")
	_check(storage.read(RUN_C, photo_ids[RUN_C]) != null, "writing C retains C primary photos")
	_check(FileAccess.file_exists(PHOTO_GC_DIR.path_join("foreign.txt")), "GC preserves foreign root files")
	_check(FileAccess.file_exists(PHOTO_GC_DIR.path_join("not-a-run").path_join("sentinel.webp")), "GC preserves non-hex directories")
	var album_d := PhotoAlbumState.new()
	var photo_d: String = storage.capture(RUN_D, image, album_d, 28101.0)
	var invalid: SaveSnapshot = _fixture(RUN_D)
	invalid.session.album = album_d
	invalid.session.profile.employee_id = "bad/id"
	_check(not _service.write_snapshot(invalid, false), "invalid snapshot save fails before GC")
	_check(storage.read(RUN_D, photo_d) != null, "failed save does not run photo GC")
	_service.photo_gc_enabled = false
	_clear_gc_directory(storage)
	_clear_save_files()


func _prepare_gc_directory(storage: PhotoStorage) -> void:
	_clear_gc_directory(storage)
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PHOTO_GC_DIR.path_join("not-a-run"))) == OK, "GC isolation directories are available")
	var foreign: FileAccess = FileAccess.open(PHOTO_GC_DIR.path_join("foreign.txt"), FileAccess.WRITE)
	_check(foreign != null, "foreign root sentinel can be created")
	if foreign:
		foreign.store_string("preserve")
		foreign.close()
	var invalid_file: FileAccess = FileAccess.open(PHOTO_GC_DIR.path_join("not-a-run").path_join("sentinel.webp"), FileAccess.WRITE)
	_check(invalid_file != null, "invalid-directory sentinel can be created")
	if invalid_file:
		invalid_file.store_string("preserve")
		invalid_file.close()


func _clear_gc_directory(storage: PhotoStorage) -> void:
	for run_id: String in [RUN_A, RUN_B, RUN_C, RUN_D]:
		storage.erase_run(run_id)
		var run_path: String = PHOTO_GC_DIR.path_join(run_id)
		var run_directory: DirAccess = DirAccess.open(run_path)
		if run_directory != null:
			for filename: String in run_directory.get_files():
				run_directory.remove(filename)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))
	var invalid_path: String = PHOTO_GC_DIR.path_join("not-a-run")
	var invalid_directory: DirAccess = DirAccess.open(invalid_path)
	if invalid_directory != null:
		for filename: String in invalid_directory.get_files():
			invalid_directory.remove(filename)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	var foreign_path: String = PHOTO_GC_DIR.path_join("foreign.txt")
	if FileAccess.file_exists(foreign_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(foreign_path))


func _fixture(run_id: String) -> SaveSnapshot:
	var result := SaveSnapshot.new()
	result.session = SessionData.new()
	result.session.run_id = run_id
	result.session.difficulty = SessionData.Difficulty.CASUAL
	result.session.profile.surname = "李"
	result.session.profile.given_name = "Zoë"
	result.session.profile.birth_date = {"year": 1988, "month": 2, "day": 29}
	result.session.profile.gender_id = &"unspecified"
	result.session.profile.appearance_preset = {"skin": 3, "body": 1, "hair": 2, "hair_color": 1, "face": 2}
	result.session.profile.employee_id = "EMP2026A"
	result.session.profile.registered = true
	result.session.prologue.enabled = true
	result.session.prologue.stage = PrologueState.Stage.COMMUTE
	result.session.prologue.alarm_active = false
	result.session.prologue.bought_water = true
	result.session.prologue.credits = 37
	result.session.prologue.mark_tutorial("move")
	result.session.prologue.mark_tutorial("inventory")
	result.session.album.append("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 28080.0)
	result.session.phone.send_message("明早别忘了带钥匙 — Zoë")
	var model: InventoryModel = result.session.inventory
	var bag: ItemInstance = model.add_item(_catalog.find(&"commuter_bag"), "bag-prologue")
	var pouch: ItemInstance = model.add_item(_catalog.find(&"pouch"), "pouch-prologue")
	var light: ItemInstance = model.add_item(_catalog.find(&"flashlight"), "light-prologue")
	var water: ItemInstance = model.add_item(_catalog.find(&"water"), "water-prologue")
	_check(model.equip(bag.uid, &"back"), "fixture equips commuter bag")
	_check(model.try_place(pouch.uid, bag.uid, Vector2i(0, 0), 0), "fixture places nested pouch")
	_check(model.try_place(light.uid, pouch.uid, Vector2i(0, 0), 1), "fixture places rotated nested light")
	_check(model.try_place(water.uid, bag.uid, Vector2i(3, 0), 0), "fixture places liquid bottle")
	water.contents.consume(125.0)
	result.world = WorldData.new()
	result.world.level_id = &"prologue_commute"
	result.world.entrance_id = &"default"
	result.world.clock_seconds = 28125.0
	result.world.initialized_rooms = [&"prologue_apartment", &"prologue_commute"]
	result.player_transform = Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 2.0))
	result.preferences = {"immersive_hud": true, "headbob": false}
	return result


func _clear_save_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)

