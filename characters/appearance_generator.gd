class_name AppearanceGenerator
extends RefCounted

const DEFAULT_HAIR: StringName = &"short"
const STANDARD_HAIR_IDS: Array[StringName] = [&"short", &"crop", &"bob", &"tied"]
const DEFAULT_SKIN := Color("e6bd9d")
const DEFAULT_TOP := Color("6f7c80")
const FACE_VARIANTS: Array[StringName] = [&"nose_width", &"eye_distance", &"jaw_width", &"mouth_width"]
const BODY_VARIANTS: Array[StringName] = [&"height", &"weight", &"shoulder_width", &"hip_size"]
const HAIR_COLORS: Array[Color] = [Color("241d19"), Color("594330"), Color("84765b"), Color("463b39")]


static func generate(seed_value: int, profile: FactionAppearanceProfile) -> CharacterAppearance:
	var result := CharacterAppearance.new()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	result.character_seed = seed_value
	result.hair = _pick_hair(random, profile)
	result.skin_tone = _pick_color(random, profile.skin_palette if profile != null else [], DEFAULT_SKIN)
	result.hair_color = HAIR_COLORS[random.randi_range(0, HAIR_COLORS.size() - 1)]
	var top_color := _pick_color(random, profile.clothing_colors if profile != null else [], DEFAULT_TOP)
	result.clothing = {&"top": &"casual_shirt", &"bottom": &"trousers", &"shoes": &"everyday_shoes", &"outerwear": &"", &"gloves": &""}
	result.clothing_colors = {&"top": top_color, &"bottom": top_color.darkened(0.48), &"shoes": Color("252321")}
	var variation: float = clampf(profile.morph_variation if profile != null else 0.18, 0.0, 1.0)
	if profile == null or not profile.preset_only:
		for key: StringName in FACE_VARIANTS:
			result.face_morphs[key] = random.randf_range(-variation, variation)
		for key: StringName in BODY_VARIANTS:
			result.body_morphs[key] = random.randf_range(-variation, variation)
	return result


static func _pick_hair(random: RandomNumberGenerator, profile: FactionAppearanceProfile) -> StringName:
	if profile == null:
		return DEFAULT_HAIR
	var total := 0.0
	var usable_count: int = mini(profile.hair_ids.size(), profile.hair_weights.size())
	for index: int in usable_count:
		if profile.hair_ids[index] in STANDARD_HAIR_IDS and is_finite(profile.hair_weights[index]) and profile.hair_weights[index] > 0.0:
			total += profile.hair_weights[index]
	if total <= 0.0:
		return DEFAULT_HAIR
	var cursor := random.randf() * total
	for index: int in usable_count:
		var weight: float = profile.hair_weights[index]
		if profile.hair_ids[index] not in STANDARD_HAIR_IDS or not is_finite(weight) or weight <= 0.0:
			continue
		cursor -= weight
		if cursor <= 0.0:
			return profile.hair_ids[index]
	return DEFAULT_HAIR


static func _pick_color(random: RandomNumberGenerator, palette: Array[Color], fallback: Color) -> Color:
	if palette.is_empty():
		return fallback
	return palette[random.randi_range(0, palette.size() - 1)]
