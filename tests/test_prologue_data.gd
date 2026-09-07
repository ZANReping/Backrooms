extends SceneTree

const CharacterProfileScript := preload("res://core/session/character_profile.gd")
const PrologueStateScript := preload("res://core/prologue/prologue_state.gd")
const STORY_DATE: Dictionary = {"year": 2026, "month": 10, "day": 18}
var _failed: bool = false


func _initialize() -> void:
	_test_profile_dates_and_names()
	_test_profile_transaction()
	_test_state_transaction()
	_test_defaults_roundtrip()
	if _failed:
		quit(1)
		return
	print("PASS: prologue data")
	quit(0)


func _test_profile_dates_and_names() -> void:
	var profile: Resource = _registered_profile()
	profile.birth_date = {"year": 2008, "month": 10, "day": 18}
	_assert(profile.age_on(STORY_DATE) == 18 and profile.validate(STORY_DATE) == &"", "age 18 boundary is accepted")
	profile.birth_date = {"year": 2008, "month": 10, "day": 19}
	_assert(profile.validate(STORY_DATE) == &"PROFILE_ERR_AGE", "one day before age 18 is rejected")
	profile.birth_date = {"year": 1985, "month": 10, "day": 19}
	_assert(profile.age_on(STORY_DATE) == 40 and profile.validate(STORY_DATE) == &"", "age 40 boundary is accepted")
	profile.birth_date = {"year": 1985, "month": 10, "day": 18}
	_assert(profile.validate(STORY_DATE) == &"PROFILE_ERR_AGE", "one day after age 40 is rejected")
	profile.birth_date = {"year": 1988, "month": 2, "day": 29}
	profile.surname = "李"
	profile.given_name = "Zoë"
	_assert(profile.validate(STORY_DATE) == &"", "leap day and common Unicode names are accepted")
	profile.birth_date = {"year": 1989, "month": 2, "day": 29}
	_assert(profile.validate(STORY_DATE) == &"PROFILE_ERR_BIRTH_DATE", "invalid leap day is rejected")
	profile.birth_date = {"year": 1988, "month": 2, "day": 29}
	profile.given_name = "Bad\u0007Name"
	_assert(profile.validate(STORY_DATE) == &"PROFILE_ERR_NAME", "control characters in names are rejected")
	profile.given_name = "Zoë"
	profile.appearance_preset["skin"] = 6
	_assert(profile.validate(STORY_DATE) == &"PROFILE_ERR_APPEARANCE", "out-of-range appearance preset is rejected")


func _test_profile_transaction() -> void:
	var profile: Resource = _registered_profile()
	var before: Dictionary = profile.to_data()
	var invalid: Dictionary = before.duplicate(true)
	invalid["appearance_preset"]["hair"] = 99
	_assert(not profile.load_data(invalid, STORY_DATE), "invalid profile load fails")
	_assert(profile.to_data() == before, "failed profile load does not mutate state")


func _test_state_transaction() -> void:
	var state: RefCounted = PrologueStateScript.new()
	state.enabled = true
	state.stage = PrologueStateScript.Stage.PREPARE
	state.mark_tutorial("move")
	state.mark_tutorial("unknown")
	_assert(state.has_tutorial("move") and not state.has_tutorial("unknown"), "tutorial allowlist is enforced")
	var before: Dictionary = state.to_data()
	var invalid: Dictionary = before.duplicate(true)
	invalid["tutorial_flags"]["bad_flag"] = true
	_assert(not state.load_data(invalid), "invalid prologue state load fails")
	_assert(state.to_data() == before, "failed state load does not mutate state")


func _test_defaults_roundtrip() -> void:
	var profile: Resource = CharacterProfileScript.new()
	var profile_data: Dictionary = profile.to_data()
	var restored_profile: Resource = CharacterProfileScript.new()
	_assert(restored_profile.load_data(profile_data, STORY_DATE), "unregistered default profile loads")
	_assert(restored_profile.to_data() == profile_data, "unregistered default profile round trips")
	var state: RefCounted = PrologueStateScript.new()
	var state_data: Dictionary = state.to_data()
	var restored_state: RefCounted = PrologueStateScript.new()
	_assert(restored_state.load_data(state_data), "default prologue state loads")
	_assert(restored_state.to_data() == state_data, "default prologue state round trips")
	var config: Resource = load("res://resources/prologue/default_prologue.tres")
	_assert(config.story_date == STORY_DATE and config.opening_seconds == 28080.0, "default prologue config loads")


func _registered_profile() -> Resource:
	var profile: Resource = CharacterProfileScript.new()
	profile.surname = "Doe"
	profile.given_name = "Alex"
	profile.birth_date = {"year": 1980, "month": 1, "day": 1}
	profile.employee_id = "AB1234"
	profile.registered = true
	return profile


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	_failed = true
