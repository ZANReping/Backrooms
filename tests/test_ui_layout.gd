extends Node

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1024, 768),
	Vector2i(1600, 900), Vector2i(1600, 675),
]
const LONG_NOTICE: String = "界面布局验证：这是一条较长的通知，用来检查文字换行后是否仍然可以完整阅读。通知不应盖住手机、调试面板、保存选项或关闭按钮，也不应改变物品和玩家属性。"

var app: FoundationApp
var checks: int = 0
var failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Input.use_accumulated_input = false
	Settings.storage_path = ""
	Settings.reset_defaults()
	Settings.set_value(&"developer_mode", true)
	DirAccess.make_dir_recursive_absolute("res://artifacts/ui_layout")
	SaveService.save_path = "res://artifacts/ui_layout/session.save"
	app = (load("res://core/main.tscn") as PackedScene).instantiate() as FoundationApp
	add_child(app)
	await _frames(3)
	if not await app.new_game(0):
		_check(false, "layout fixture starts the real application")
		get_tree().quit(1)
		return
	var phone: ItemInstance = Session.data.inventory.get_item(Session.data.inventory.equipment[&"secondary_hand"])
	app.shell.bind_phone(Session.data.phone, phone.charge)
	Session.data.phone.send_message("窗口缩放后，聊天记录和操作按钮仍应清晰可用。Unicode ✓")
	for requested_size: Vector2i in WINDOW_SIZES:
		get_window().size = requested_size
		await _frames(6)
		var label: String = "%dx%d" % [get_window().size.x, get_window().size.y]
		_check(get_window().size == requested_size, label + " requested window size is applied")
		for mode: StringName in [&"menu", &"pause", &"phone", &"debug", &"dead", &"inventory"]:
			GameState.set_mode(mode)
			app.shell.notify(tr(&"SHELL_DEBUG_TITLE"))
			await _frames(5)
			var surface: Control = app.inventory_view if mode == &"inventory" else app.shell.root
			_check(_buttons_accessible(surface), label + " " + String(mode) + " controls are visible or scrollable and avoid the notification")
			if mode != &"inventory":
				_check(_notice_separate(mode), label + " " + String(mode) + " panel does not overlap the notification")
			if mode in [&"phone", &"inventory", &"debug"]:
				await _capture(label + "_" + String(mode))
			if mode == &"debug":
				await _click_close(app.shell.root)
				_check(GameState.mode == &"play", label + " debug footer closes through a real mouse click")
		await _verify_inventory_actions(label)
		GameState.set_mode(&"phone")
		app.shell.notify(LONG_NOTICE)
		await _frames(6)
		var notice: PanelContainer = app.shell.get("_notification_panel") as PanelContainer
		var notice_label: Label = app.shell.get("_notification_label") as Label
		_check(_notice_separate(&"phone") and _inside_viewport(notice) and notice_label.get_line_count() > 1,
			label + " multiline notification stays separate and wraps within the viewport")
		_check(notice_label.size.y >= notice_label.get_line_count() * notice_label.get_line_height(), label + " notification has enough real height to render every line")
		_check(_buttons_accessible(app.shell.root), label + " phone remains operable with a multiline notification")
		await _capture(label + "_long_notice")
		await _click_close(app.shell.root)
		_check(GameState.mode == &"play", label + " phone closes through a real mouse click below the long notice")
		app.shell.notify("")
		GameState.set_mode(&"play")
		await _verify_stat_layout(label)
		await _capture(label + "_hud")
	print("UI_LAYOUT_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _verify_stat_layout(label: String) -> void:
	app.shell.set_preferences(false, false)
	await _frames(3)
	var numbers: Dictionary = app.shell.get("_stat_values")
	var reference_x: float = -1.0
	var aligned: bool = true
	for stat_id: StringName in FoundationUI.STAT_IDS:
		var number: Label = numbers[stat_id] as Label
		var right: float = number.get_global_rect().end.x
		if reference_x < 0.0:
			reference_x = right
		aligned = aligned and number.is_visible_in_tree() and absf(right - reference_x) < 1.0
	_check(aligned, label + " six numeric values share a right-aligned column")
	var health: Label = numbers[&"health"] as Label
	var before: Rect2 = health.get_global_rect()
	Session.data.stats.change_value(&"health", 9.0 - Session.data.stats.get_value(&"health"))
	await _frames(3)
	_check(health.get_global_rect().is_equal_approx(before) and health.text == "9", label + " changing 100 to 9 does not move or resize the value column")
	app.shell.set_preferences(true, false)
	await _frames(3)
	var hidden: bool = true
	for number: Label in numbers.values():
		hidden = hidden and not number.is_visible_in_tree()
	_check(hidden and is_equal_approx(Session.data.stats.get_value(&"health"), 9.0), label + " immersive HUD hides numbers without changing stats")
	app.shell.set_preferences(false, false)
	Session.data.stats.change_value(&"health", 100.0 - Session.data.stats.get_value(&"health"))
	await _frames(3)


func _notice_separate(mode: StringName) -> bool:
	var panels: Dictionary = app.shell.get("_panels")
	var surface: Control = panels[mode] as Control
	var notice: Control = app.shell.get("_notification_panel") as Control
	var panel: PanelContainer = surface as PanelContainer
	if panel == null:
		var found: Array[Node] = surface.find_children("*", "PanelContainer", true, false)
		if not found.is_empty():
			panel = found.front() as PanelContainer
	return panel != null and _inside_viewport(panel) and not panel.get_global_rect().intersects(notice.get_global_rect())


func _buttons_accessible(surface: Control) -> bool:
	var notice: Control = app.shell.get("_notification_panel") as Control
	for node: Node in surface.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if not button.is_visible_in_tree():
			continue
		var reachable: bool = _inside_viewport(button)
		var scroll: ScrollContainer = _scroll_parent(button)
		if scroll != null and _inside_viewport(scroll):
			var bar: VScrollBar = scroll.get_v_scroll_bar()
			var rect: Rect2 = button.get_global_rect()
			reachable = reachable or (bar.max_value > bar.page and rect.position.x >= scroll.global_position.x and rect.end.x <= scroll.get_global_rect().end.x + 1.0)
		if not reachable or (notice.visible and button.get_global_rect().intersects(notice.get_global_rect())):
			print("LAYOUT_DETAIL: %s rect=%s notice=%s viewport=%s" % [button.get_path(), button.get_global_rect(), notice.get_global_rect(), get_viewport().get_visible_rect()])
			return false
	return true


func _scroll_parent(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _verify_inventory_actions(label: String) -> void:
	app.inventory_view.bind_model(Session.data.inventory, Session.data.stats.carry_capacity_kg)
	GameState.set_mode(&"inventory")
	await _frames(3)
	var use_button: Button = app.inventory_view.get_node("%UseButton") as Button
	var hint: Label = app.inventory_view.get_node("%ActionHint") as Label
	_check(use_button.disabled and not use_button.tooltip_text.is_empty() and not hint.text.is_empty(), label + " unselected inventory actions explain why they are unavailable")
	var equipment: GridContainer = app.inventory_view.get_node("%EquipmentGrid") as GridContainer
	var back: Button = equipment.get_child(InventoryView.EQUIPMENT_SLOTS.find(&"back")) as Button
	await _click(back)
	_check(use_button.disabled and use_button.tooltip_text == tr(&"INVENTORY_CANNOT_USE_HINT"), label + " container without a use action explains its disabled Use button")
	var secondary: Button = equipment.get_child(InventoryView.EQUIPMENT_SLOTS.find(&"secondary_hand")) as Button
	await _click(secondary)
	_check(not use_button.disabled and use_button.tooltip_text == tr(&"INVENTORY_USE_HINT"), label + " selecting a usable phone clears the disabled reason")
	await _click(use_button)
	_check(GameState.mode == &"phone", label + " actual inventory Use click opens the physical phone")


func _click_close(surface: Control) -> void:
	for node: Node in surface.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and button.text == tr(&"SHELL_CLOSE") and _scroll_parent(button) == null:
			await _click(button)
			return


func _click(button: Button) -> void:
	# Window resizes and screenshot readback can complete one frame before the GUI
	# hover state catches up. Settle first, then refresh the pointer immediately
	# before both phases of the physical click so neither phase uses stale input.
	await _frames(2)
	var position: Vector2 = _window_position(button.get_global_rect().get_center())
	for pressed: bool in [true, false]:
		await _mouse_motion(position)
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.window_id = get_window().get_window_id()
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)


func _mouse_motion(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _window_position(viewport_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	return viewport_position * window_size / viewport_size


func _inside_viewport(control: Control) -> bool:
	return get_viewport().get_visible_rect().grow(1.0).encloses(control.get_global_rect())


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	picture.save_webp("res://artifacts/ui_layout/" + label + ".webp")


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
