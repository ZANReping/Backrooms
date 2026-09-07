extends Node

var failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui := (load("res://ui/shell/foundation_ui.tscn") as PackedScene).instantiate() as FoundationUI
	add_child(ui)
	await get_tree().process_frame
	ui.set_mode(&"play")
	ui.set_controls_hint("动态键位提示")
	_check(ui._controls_hint_label.visible, "controls hint defaults to enabled")
	ui.set_controls_hint_enabled(false)
	ui.set_controls_hint("更新后的动态键位提示")
	_check(not ui._controls_hint_label.visible and ui._controls_hint_label.text.contains("更新后"), "disabled controls hint still stores dynamic text without showing")
	ui.set_controls_hint_enabled(true)
	_check(ui._controls_hint_label.visible, "reenabling controls hint restores current text")
	ui.notify("第一条")
	await get_tree().create_timer(0.08).timeout
	ui.notify("第二条")
	await get_tree().create_timer(0.25).timeout
	_check(ui._notification_panel.visible and ui._notification_label.text == "第二条" and ui._notification_panel.modulate.a > 0.9, "replacement notice survives the previous animation")
	ui.notify("")
	_check(not ui._notification_panel.visible and is_zero_approx(ui._notification_panel.modulate.a), "empty notice cancels and hides immediately")
	await get_tree().create_timer(0.5).timeout
	_check(not ui._notification_panel.visible, "cancelled animation cannot reveal or clear the notice later")
	ui.notify("淡入提示")
	_check(ui._notification_panel.visible and is_zero_approx(ui._notification_panel.modulate.a), "notice begins transparent")
	await get_tree().create_timer(0.22).timeout
	_check(ui._notification_panel.modulate.a > 0.95, "notice fades in before its hold period")
	print("NOTIFICATION_HINT_RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

