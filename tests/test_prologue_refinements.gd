extends Node

var app: PrologueApplication
var checks: int = 0
var failures: int = 0
const OUTPUT := "res://artifacts/prologue_refinements"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.storage_path = ""
	Settings.reset_defaults()
	Settings.set_value(&"fps_limit", 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	SaveService.save_path = OUTPUT + "/test.save"
	app = (load("res://core/prologue/main.tscn") as PackedScene).instantiate() as PrologueApplication
	add_child(app)
	app.photos.base_path = OUTPUT + "/photos"
	while SceneRouter.current_room == null or SceneRouter.busy:
		await get_tree().process_frame
	_check(await app.new_game(0), "fresh prologue starts")
	await get_tree().create_timer(0.3).timeout
	var shell: PrologueShell = app.shell as PrologueShell
	var initial_task: Dictionary = PrologueTasks.describe(Session.data)
	_check(initial_task.entries.size() == 7, "morning task projects seven actual steps")
	_check(_entry(initial_task, &"inspect").optional and _entry(initial_task, &"organize").optional, "inspection and packing marked optional")
	_check(shell._controls_hint_label.is_visible_in_tree() and shell._controls_hint_label.get_global_rect().position.y >= 0.0 and shell._controls_hint_label.get_global_rect().end.x <= shell.root.size.x, "persistent controls hint fits the top of the screen")
	_check(shell._notification_panel.anchor_top == 0.0 and shell._notification_panel.is_visible_in_tree(), "game notices use the top overlay")
	for stat_id: StringName in FoundationUI.STAT_IDS:
		var strip: VitalStrip = shell._stat_rows[stat_id] as VitalStrip
		_check(strip.is_visible_in_tree() and not strip._value_label.visible, "immersive %s retains the whole magnitude strip" % stat_id)
	await _shot("hud_immersive")
	Session.data.stats.change_value(&"health", -62.0)
	Session.data.stats.change_value(&"thirst", -45.0)
	await _shot("hud_reduced")
	_check(is_equal_approx((shell._stat_rows[&"health"] as VitalStrip)._ratio, 0.38), "reduced health has its actual fill ratio")
	var invalid_save: Dictionary = app.capture_snapshot().to_data()
	invalid_save["settings"]["render_scale"] = NAN
	_check(SaveSnapshot.from_data(invalid_save, app.item_catalog) == null, "snapshot rejects malformed extended preferences before loading the scene")
	var phone: ItemInstance = app.director.find_item(&"phone")
	app._pickup(phone.uid)
	_check(Session.data.inventory.equipment.get(&"primary_hand") == phone.uid, "first pickup occupies the real primary hand")
	_check(_primary_hidden(), "primary item hidden immediately during pickup")
	await get_tree().create_timer(0.85).timeout
	_check(not _primary_hidden(), "primary item returns after reaching animation")
	var bag: ItemInstance = app.director.find_item(&"commuter_bag")
	app._pickup(bag.uid)
	_check(_primary_hidden(), "picking another item also hides the old main-hand object")
	app.show_phone(phone.uid)
	await get_tree().create_timer(0.85).timeout
	_check(not app.player.primary_hand_mount.is_visible_in_tree(), "pickup completion does not reveal the mount inside phone mode")
	app._resume()
	await get_tree().create_timer(0.25).timeout
	_check(app.player.primary_hand_mount.is_visible_in_tree() and not _primary_hidden(), "returning to play restores the current primary item")
	Session.data.prologue.alarm_active = false
	app.director._update_objective()
	var row: Control = shell._checklist._rows.get(&"alarm") as Control
	_check(row != null and (row.get_child(0) as RichTextLabel).text.contains("[s]"), "completed real task displays strikethrough")
	await _shot("todo_completed")
	await get_tree().create_timer(1.4).timeout
	_check(not shell._checklist._rows.has(&"alarm"), "completed real task disappears after animation")
	for id: StringName in [&"keys", &"wallet"]:
		app._pickup(app.director.find_item(id).uid)
	_check(app.director._has_essentials() and not Session.data.prologue.has_tutorial("rotate") and not Session.data.prologue.has_tutorial("inspect_laptop"), "optional steps do not gate the existing essentials check")
	Session.data.prologue.stage = PrologueState.Stage.COMMUTE
	var commute_task: Dictionary = PrologueTasks.describe(Session.data)
	_check(commute_task.title == "去上班" and _entry(commute_task, &"water").optional, "commute has a separate task and optional purchase")
	GameState.set_mode(&"inventory")
	app.inventory_view._on_item_selected(phone.uid)
	GameState.set_mode(&"play")
	GameState.set_mode(&"inventory")
	_check(app.inventory_view._selected_uid.is_empty() and app.inventory_view._grid.held_uid.is_empty(), "actual application reopen clears selection and drag")
	await get_tree().create_timer(0.22).timeout
	var equipment_pane: Control = app.inventory_view._equipment_pane
	_check(equipment_pane.is_visible_in_tree() and equipment_pane.modulate.a > 0.99 and app.inventory_view._equipment_grid.get_child_count() == 10, "duplicate refresh on reopen preserves the visible ten-slot equipment pane")
	await _shot("equipment")
	if DisplayServer.get_name() != "headless":
		var original_size: Vector2i = get_window().size
		get_window().size = Vector2i(960, 540)
		await get_tree().create_timer(0.25).timeout
		var hand_button: Button = app.inventory_view._equipment_grid.get_child(InventoryView.EQUIPMENT_SLOTS.find(&"primary_hand")) as Button
		await _click(hand_button.get_global_rect().get_center())
		await get_tree().create_timer(0.2).timeout
		var thumbnail: Button = app.inventory_view._selected_thumbnail_button
		_check(app.inventory_view._selected_uid == phone.uid and app.inventory_view._grid.held_uid.is_empty(), "equipped phone short click selects without dragging in the real shell")
		_check(thumbnail.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(thumbnail.get_global_rect()), "selected equipment thumbnail remains accessible at 960x540")
		await _shot("equipment_details_960")
		await _click(thumbnail.get_global_rect().get_center())
		await get_tree().create_timer(0.2).timeout
		_check(app.inventory_view._selected_uid.is_empty() and equipment_pane.is_visible_in_tree() and Session.data.inventory.equipment.get(&"primary_hand") == phone.uid, "repeated click on the actual equipped item cancels selection and preserves equipment")
		get_window().size = original_size
		await get_tree().create_timer(0.25).timeout
	GameState.set_mode(&"play")
	Settings.set_value(&"immersive_hud", false)
	await _shot("hud_numeric")
	_check(not Settings.vcr_filter, "VCR filtering is disabled by default")
	Settings.set_value(&"vcr_filter", true)
	_check(app.settings_runtime._filter.visible, "VCR preference activates the actual screen material")
	await _shot("vcr_filter")
	Settings.set_value(&"vcr_filter", false)
	print("PROLOGUE_REFINEMENTS: %d checks / %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _primary_hidden() -> bool:
	for node: Node in app.player.primary_hand_mount.get_children():
		if node is Node3D and (node as Node3D).visible:
			return false
	return true


func _click(point: Vector2) -> void:
	var window_point: Vector2 = point * Vector2(get_window().size) / get_viewport().get_visible_rect().size
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = window_point
		event.global_position = window_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.window_id = get_window().get_window_id()
		Input.parse_input_event(event)
		await get_tree().process_frame


func _entry(task: Dictionary, id: StringName) -> Dictionary:
	for entry: Dictionary in task.entries:
		if entry.id == id:
			return entry
	return {}


func _shot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_webp(OUTPUT + "/" + filename + ".webp", false, 0.9)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
