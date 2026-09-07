extends SceneTree

var _failed := false


func _initialize() -> void:
	var profile := load("res://characters/resources/civilian_profile.tres") as FactionAppearanceProfile
	_assert(profile != null, "civilian profile loads")
	if profile == null:
		quit(1)
		return
	var first := AppearanceGenerator.generate(73421, profile)
	var repeated := AppearanceGenerator.generate(73421, profile)
	var different := AppearanceGenerator.generate(73422, profile)
	_assert(first.to_data() == repeated.to_data(), "same seed produces identical deep data")
	_assert(first.to_data() != different.to_data(), "different seeds produce different data")
	_assert(first.clothing[&"top"] == &"casual_shirt" and first.clothing[&"bottom"] == &"trousers" and first.clothing[&"shoes"] == &"everyday_shoes", "generator always supplies standard clothing")
	_assert(first.hair in profile.hair_ids, "generated hair belongs to profile")
	_assert(first.skin_tone in profile.skin_palette, "generated skin belongs to profile")
	_assert(first.clothing_colors[&"top"] in profile.clothing_colors, "generated top color belongs to profile")
	_assert(_morphs_in_range(first.face_morphs, profile.morph_variation), "face morphs stay in variation range")
	_assert(_morphs_in_range(first.body_morphs, profile.morph_variation), "body morphs stay in variation range")
	var restored := CharacterAppearance.new()
	_assert(restored.load_data(first.to_data()) and restored.to_data() == first.to_data(), "generated deep data loads into CharacterAppearance")
	var fallback := FactionAppearanceProfile.new()
	fallback.hair_ids.clear()
	fallback.hair_weights.clear()
	fallback.skin_palette.clear()
	fallback.clothing_colors.clear()
	var safe := AppearanceGenerator.generate(1, fallback)
	_assert(safe.hair == &"short", "empty hair data falls back safely")
	_assert(not String(safe.clothing[&"top"]).is_empty() and not String(safe.clothing[&"bottom"]).is_empty() and not String(safe.clothing[&"shoes"]).is_empty(), "fallback never produces nude clothing slots")
	fallback.hair_ids = [&"unknown", &"bob"]
	fallback.hair_weights = [0.0, 0.0]
	_assert(AppearanceGenerator.generate(2, fallback).hair == &"short", "zero weights fall back safely")
	fallback.hair_ids = [&"unknown"]
	fallback.hair_weights = [1.0]
	_assert(AppearanceGenerator.generate(3, fallback).hair == &"short", "unknown hair ids fall back safely")
	fallback.preset_only = true
	var preset := AppearanceGenerator.generate(4, fallback)
	_assert(preset.face_morphs.is_empty() and preset.body_morphs.is_empty(), "preset-only profile disables random morphs")
	if _failed:
		quit(1)
		return
	print("PASS: character generation")
	quit(0)


func _morphs_in_range(morphs: Dictionary[StringName, float], variation: float) -> bool:
	for value: float in morphs.values():
		if value < -variation or value > variation:
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	_failed = true
