class_name UiIcons
extends RefCounted

## Central icon lookup. SVGs are white strokes so Controls can tint them with self_modulate.

const _ROOT := "res://assets/ui/icons/lucide/"
const _PROJECT_IDS: Array[StringName] = [&"head", &"legs", &"feet", &"accessory_1", &"accessory_2"]

const _ALIASES: Dictionary = {
	&"chat": &"message-circle",
	&"maps": &"map",
	&"browser": &"globe",
	&"workspace": &"briefcase-business",
	&"health": &"heart",
	&"stamina": &"zap",
	&"thirst": &"droplets",
	&"hunger": &"utensils",
	&"sanity": &"brain",
	&"fatigue": &"moon",
	&"offline": &"wifi-off",
	&"wifi_off": &"wifi-off",
	&"head": &"user",
	&"face": &"scan-face",
	&"torso": &"shirt",
	&"legs": &"footprints",
	&"feet": &"footprints",
	&"back": &"backpack",
	&"primary_hand": &"hand",
	&"secondary_hand": &"hand",
	&"accessory_1": &"gem",
	&"accessory_2": &"gem",
}

const _CANONICAL: Array[StringName] = [
	&"message-circle", &"map", &"globe", &"phone", &"camera", &"clock",
	&"briefcase-business", &"house", &"search", &"arrow-left", &"x", &"check",
	&"chevron-right", &"settings", &"heart", &"zap", &"droplets", &"utensils",
	&"brain", &"moon", &"weight", &"battery", &"wifi", &"wifi-off", &"shirt",
	&"user", &"footprints", &"backpack", &"hand", &"gem", &"scan-face",
	&"sliders-horizontal", &"rotate-cw", &"image", &"plus", &"send", &"trash-2",
	&"download", &"smartphone",
]

static var _cache: Dictionary = {}
static var _tinted_cache: Dictionary[String, Texture2D] = {}


static func icon(id: StringName) -> Texture2D:
	if id in _PROJECT_IDS:
		var project_key: StringName = StringName("project_" + String(id))
		if not _cache.has(project_key):
			_cache[project_key] = load("res://assets/ui/icons/project/" + String(id) + ".svg") as Texture2D
		return _cache[project_key] as Texture2D
	var canonical: StringName = _ALIASES.get(id, id)
	if not _CANONICAL.has(canonical):
		push_warning("UiIcons: unknown icon id '%s'" % id)
		return null
	if not _cache.has(canonical):
		_cache[canonical] = load(_ROOT + String(canonical) + ".svg") as Texture2D
	return _cache[canonical] as Texture2D


static func has_icon(id: StringName) -> bool:
	return id in _PROJECT_IDS or _CANONICAL.has(_ALIASES.get(id, id))


## For native icon properties without a modulate option, such as LineEdit.right_icon.
## Generated once per icon/color; the original imported texture remains unchanged.
static func tinted_icon(id: StringName, color: Color) -> Texture2D:
	var key := String(id) + ":" + color.to_html()
	if _tinted_cache.has(key):
		return _tinted_cache[key]
	var source := icon(id)
	if source == null:
		return null
	var pixels := source.get_image()
	for y: int in pixels.get_height():
		for x: int in pixels.get_width():
			pixels.set_pixel(x, y, pixels.get_pixel(x, y) * color)
	var tinted := ImageTexture.create_from_image(pixels)
	_tinted_cache[key] = tinted
	return tinted
