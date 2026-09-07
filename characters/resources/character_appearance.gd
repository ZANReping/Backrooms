class_name CharacterAppearance
extends Resource

## Stable project data. No plugin nodes, file paths or third-party resource types.
const FACE_KEYS: Array[StringName] = [&"nose_width", &"nose_height", &"nose_length", &"eye_size", &"eye_distance", &"eye_height", &"jaw_width", &"jaw_height", &"chin_length", &"chin_width", &"mouth_width", &"mouth_height", &"cheek_size", &"brow_height"]
const BODY_KEYS: Array[StringName] = [&"height", &"weight", &"muscle", &"shoulder_width", &"chest_size", &"waist_size", &"hip_size", &"arm_size", &"leg_size"]
const CLOTHING_SLOTS: Array[StringName] = [&"top", &"bottom", &"shoes", &"outerwear", &"gloves"]
const EQUIPMENT_SLOTS: Array[StringName] = [&"head", &"face", &"chest", &"back", &"hip_left", &"hip_right", &"hand_left", &"hand_right"]
const SKIN_PALETTE: Array[Color] = [Color("f2d5c1"), Color("e6bd9d"), Color("cf9670"), Color("a86e4c"), Color("79503b"), Color("4e342d")]

@export var character_seed: int = 0
@export var body_type: StringName = &"neutral"
@export var skin_tone: Color = Color("e6bd9d")
@export var face_preset: StringName = &"default"
@export var face_morphs: Dictionary[StringName, float] = {}
@export var body_morphs: Dictionary[StringName, float] = {}
@export var hair: StringName = &"short"
@export var hair_color: Color = Color("241d19")
@export var clothing: Dictionary[StringName, StringName] = {&"top": &"casual_shirt", &"bottom": &"trousers", &"shoes": &"everyday_shoes", &"outerwear": &"", &"gloves": &""}
@export var equipment: Dictionary[StringName, StringName] = {}
@export var clothing_colors: Dictionary[StringName, Color] = {&"top": Color("6f7c80"), &"bottom": Color("303539"), &"shoes": Color("252321")}
@export var equipment_colors: Dictionary[StringName, Color] = {}


func to_data() -> Dictionary:
	return {"character_seed": character_seed, "body_type": String(body_type), "skin_tone": skin_tone, "face_preset": String(face_preset), "face_morphs": face_morphs.duplicate(), "body_morphs": body_morphs.duplicate(), "hair": String(hair), "hair_color": hair_color, "clothing": clothing.duplicate(), "equipment": equipment.duplicate(), "clothing_colors": clothing_colors.duplicate(), "equipment_colors": equipment_colors.duplicate()}


func copy() -> CharacterAppearance:
	return duplicate(true) as CharacterAppearance


func set_morph(id: StringName, value: float) -> bool:
	if not is_finite(value) or value < -1.0 or value > 1.0:
		return false
	if id in FACE_KEYS:
		face_morphs[id] = value
	elif id in BODY_KEYS:
		body_morphs[id] = value
	else:
		return false
	emit_changed()
	return true


func load_data(data: Dictionary) -> bool:
	if not data.get("character_seed") is int or not _valid_id(data.get("face_preset")) or not _valid_id(data.get("hair")):
		return false
	if data.get("body_type") not in ["neutral", "female", "male", &"neutral", &"female", &"male"]:
		return false
	if not _valid_color(data.get("skin_tone")) or not _valid_color(data.get("hair_color")):
		return false
	if not _valid_morphs(data.get("face_morphs"), FACE_KEYS) or not _valid_morphs(data.get("body_morphs"), BODY_KEYS):
		return false
	if not _valid_map(data.get("clothing"), CLOTHING_SLOTS, false) or not _valid_map(data.get("equipment"), EQUIPMENT_SLOTS, false):
		return false
	if not _valid_map(data.get("clothing_colors"), CLOTHING_SLOTS, true) or not _valid_map(data.get("equipment_colors"), EQUIPMENT_SLOTS, true):
		return false
	character_seed = data["character_seed"]
	body_type = StringName(data["body_type"])
	skin_tone = data["skin_tone"]
	face_preset = StringName(data["face_preset"])
	hair = StringName(data["hair"])
	hair_color = data["hair_color"]
	face_morphs.clear()
	body_morphs.clear()
	for key: StringName in data["face_morphs"]:
		face_morphs[key] = float(data["face_morphs"][key])
	for key: StringName in data["body_morphs"]:
		body_morphs[key] = float(data["body_morphs"][key])
	clothing.assign(data["clothing"])
	equipment.assign(data["equipment"])
	clothing_colors.assign(data["clothing_colors"])
	equipment_colors.assign(data["equipment_colors"])
	return true


static func from_legacy(preset: Dictionary, seed_value: int = 0) -> CharacterAppearance:
	var result := CharacterAppearance.new()
	result.character_seed = seed_value
	result.skin_tone = SKIN_PALETTE[clampi(int(preset.get("skin", 0)), 0, 5)]
	result.body_morphs[&"weight"] = float(clampi(int(preset.get("body", 0)), 0, 2) - 1) * 0.35
	result.hair = [&"short", &"crop", &"bob", &"tied"][clampi(int(preset.get("hair", 0)), 0, 3)]
	result.hair_color = [Color("241d19"), Color("594330"), Color("84765b"), Color("463b39")][clampi(int(preset.get("hair_color", 0)), 0, 3)]
	result.face_morphs[&"jaw_width"] = float(clampi(int(preset.get("face", 0)), 0, 2) - 1) * 0.2
	return result


static func _valid_id(value: Variant, allow_empty: bool = false) -> bool:
	if not (value is String or value is StringName):
		return false
	var text: String = String(value)
	if text.is_empty():
		return allow_empty
	if text.length() > 64:
		return false
	for index: int in text.length():
		var point: int = text.unicode_at(index)
		if not ((point >= 97 and point <= 122) or (point >= 48 and point <= 57) or point == 95):
			return false
	return true


static func _valid_color(value: Variant) -> bool:
	if not value is Color:
		return false
	for component: float in [value.r, value.g, value.b, value.a]:
		if not is_finite(component) or component < 0.0 or component > 1.0:
			return false
	return is_equal_approx(value.a, 1.0)


static func _valid_morphs(value: Variant, keys: Array[StringName]) -> bool:
	if not value is Dictionary or value.size() > keys.size():
		return false
	for key: Variant in value:
		if not (key is String or key is StringName) or StringName(key) not in keys:
			return false
		var number: Variant = value[key]
		if not (number is float or number is int) or not is_finite(float(number)) or absf(float(number)) > 1.0:
			return false
	return true


static func _valid_map(value: Variant, slots: Array[StringName], colors: bool) -> bool:
	if not value is Dictionary or value.size() > slots.size():
		return false
	for key: Variant in value:
		if not (key is String or key is StringName) or StringName(key) not in slots:
			return false
		if colors and not _valid_color(value[key]):
			return false
		if not colors and not _valid_id(value[key], true):
			return false
	return true
