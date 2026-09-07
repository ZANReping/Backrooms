extends Node

var failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var strip := VitalStrip.new()
	add_child(strip)
	strip.set_state(&"health", 40.0, 80.0, false)
	await get_tree().process_frame
	_check(is_equal_approx(float(strip.get("_ratio")), 0.5), "vital fill reflects value ratio")
	var ratio_before: float = strip.get("_ratio")
	strip.set_state(&"health", 40.0, 80.0, true)
	_check(is_equal_approx(float(strip.get("_ratio")), ratio_before), "immersive mode preserves fill ratio")
	_check(not (strip.get("_value_label") as Label).visible and (strip.get("_name_label") as Label).text == "健康", "immersive mode hides only the number")

	var checklist := TaskChecklist.new()
	add_child(checklist)
	checklist.set_task(&"prepare", "出门准备", [
		{"id": &"water", "text": "带上瓶装水", "optional": true, "completed": false},
		{"id": &"keys", "text": "拿钥匙", "optional": false, "completed": true},
	])
	await get_tree().process_frame
	_check(checklist.get_node_or_null("Task_water") != null, "incomplete task is visible")
	_check(checklist.get_node_or_null("Task_keys") == null, "initially completed task does not replay")
	var optional_wrapper := checklist.get_node("Task_water") as Control
	var optional_row := optional_wrapper.get_child(0) as RichTextLabel
	_check(optional_row.text.contains("可选"), "optional task is labelled")
	checklist.set_task(&"prepare", "出门准备", [{"id": &"water", "text": "带上瓶装水", "optional": true, "completed": true}])
	_check(optional_row.text.contains("[s]"), "new completion is struck through")
	checklist.set_task(&"prepare", "出门准备", [{"id": &"water", "text": "带上瓶装水", "optional": true, "completed": true}])
	_check((checklist.get("_rows") as Dictionary).size() == 1, "repeated refresh does not recreate or replay a completing row")
	checklist.set_task(&"prepare", "出门准备", [{"id": &"water", "text": "带上瓶装水", "optional": true, "completed": false}])
	_check(checklist.get_node_or_null("Task_water") == optional_wrapper and optional_wrapper.modulate.a == 1.0, "regressed completion restores the same pending row")
	await get_tree().create_timer(1.4).timeout
	_check(checklist.get_node_or_null("Task_water") != null, "cancelled completion callback cannot delete restored row")
	checklist.set_task(&"prepare", "出门准备", [{"id": &"water", "text": "带上瓶装水", "optional": true, "completed": true}])
	await get_tree().create_timer(1.1).timeout
	_check(optional_wrapper.custom_minimum_size.y < 22.0, "completion collapses the clipping wrapper height")
	await get_tree().create_timer(1.6).timeout
	_check(checklist.get_node_or_null("Task_water") == null, "completed row fades and collapses")
	checklist.set_task(&"prepare", "出门准备", [{"id": &"coat", "text": "穿外套", "optional": false, "completed": false}])
	checklist.set_task(&"prepare", "出门准备", [{"id": &"coat", "text": "穿外套", "optional": false, "completed": true}])
	checklist.set_task(&"catch_train", "赶上列车", [{"id": &"platform", "text": "前往站台", "optional": false, "completed": false}])
	await get_tree().create_timer(1.4).timeout
	_check(checklist.get_node_or_null("Task_platform") != null and checklist.get_node_or_null("Task_coat") == null, "switching task cancels old completion animation")
	print("HUD_COMPONENT_RESULT: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
