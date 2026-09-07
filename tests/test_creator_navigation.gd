extends Node

var _failed := false

func _ready() -> void:
	var creator := CharacterCreator.new()
	add_child(creator)
	var supported: Array[StringName] = []
	for id: StringName in CharacterAppearance.FACE_KEYS:
		if supported.size() < 12:
			supported.append(id)
	for id: StringName in CharacterAppearance.BODY_KEYS:
		if supported.size() < 17:
			supported.append(id)
	creator.set_supported_morphs(supported)
	var appearance := CharacterAppearance.new()
	appearance.skin_tone = CharacterAppearance.SKIN_PALETTE[2]
	appearance.hair_color = CharacterCreator.HAIR_COLORS[3]
	creator.edit(appearance)
	await get_tree().process_frame
	_check(creator._pages.size() == 3, "three creator pages exist")
	_check(creator._pages[0].visible and not creator._pages[1].visible and not creator._pages[2].visible, "basics page opens first")
	creator._show_page(1)
	_check(not creator._full_body and creator._pages[1].visible, "face tab selects close view")
	creator._show_page(2)
	_check(creator._full_body and creator._pages[2].visible, "body tab selects full view")
	var visible_morphs := 0
	for slider: Slider in creator._morph_controls.values():
		visible_morphs += int(slider.get_parent().visible)
	_check(visible_morphs == 17, "only supported morphs are visible")
	_check(creator._skin_swatches[2].button_pressed, "skin selection syncs from draft")
	_check(creator._hair_swatches[3].button_pressed, "hair selection syncs from draft")
	var action_count := 0
	for button: Button in creator.find_children("*", "Button", true, false):
		if button.text in [tr(&"CHARACTER_CREATOR_CANCEL"), tr(&"CHARACTER_CREATOR_CONFIRM")]:
			action_count += 1
			_check(button.is_visible_in_tree(), "%s remains visible" % button.text)
	_check(action_count == 2, "both actions exist")
	if _failed:
		get_tree().quit(1)
		return
	print("PASS: creator navigation and selection state")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: %s" % message)
