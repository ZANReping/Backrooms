extends Node

const SettingsViewScript := preload("res://ui/settings/settings_view.gd")

var failures := 0
var checks := 0
var emissions: Array[Array] = []


func _ready() -> void:
	var view := SettingsViewScript.new()
	view.preference_changed.connect(func(key: StringName, value: Variant) -> void: emissions.append([key, value]))
	add_child(view)
	await get_tree().process_frame
	_check(view._controls.size() == 20, "all specified controls exist")
	_check(view._category_pages.size() == 4 and view._display_pages.size() == 4, "category and display tabs exist")
	view._show_display_page(2)
	await get_tree().process_frame
	_check(view._display_stack.custom_minimum_size.y >= view._display_pages[2].get_combined_minimum_size().y, "display stack follows performance page height")
	view.set_values({&"developer_mode": true, &"resolution": 1, &"render_scale": 0.75, &"fov": 90.0})
	_check(emissions.is_empty(), "set_values emits no preference changes")
	_check((view.find_child("developer_mode", true, false) as BaseButton).button_pressed, "toggle sync")
	_check((view.find_child("resolution", true, false) as OptionButton).selected == 1, "option sync")
	_check(is_equal_approx((view.find_child("render_scale", true, false) as HSlider).value, 0.75), "slider sync")
	(view.find_child("dynamic_crosshair", true, false) as BaseButton).set_pressed_no_signal(false)
	(view.find_child("dynamic_crosshair", true, false) as BaseButton).toggled.emit(false)
	_check(emissions.size() == 1 and emissions[0] == [&"dynamic_crosshair", false], "user change emits strict key and value")
	var restored: Array[bool] = [false]
	view.restore_requested.connect(func() -> void: restored[0] = true)
	(view.find_child("RestoreDefaults", true, false) as Button).pressed.emit()
	_check(restored[0], "restore button emits request")
	for page: Control in view._category_pages:
		_check(page is ScrollContainer, "every category is scrollable")
	print("SETTINGS_VIEW: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
