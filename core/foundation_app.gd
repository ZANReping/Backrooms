class_name FoundationApp
extends Node3D

@export var item_catalog: ItemCatalog
@export var route_catalog: RouteCatalog
@export var loadout: StarterLoadout
@export var initial_route: StringName = &"test_room_a"
@export var use_config: ItemUseConfig

@onready var player: PlayerController = %Player
@onready var shell: FoundationUI = %FoundationUI
@onready var inventory_view: InventoryView = %InventoryView
@onready var interactor: PlayerInteractor = %Interactor
@onready var world_items: WorldItemService = %WorldItems
@onready var equipment_view: EquipmentPresentation = %EquipmentPresentation
@onready var loading_cover: ColorRect = %LoadingCover

var interaction_context: InteractionContext = InteractionContext.new()
var item_use: ItemUseService = ItemUseService.new()
var _phone_uid: String = ""
var _ui_timer: float = 0.0
var _death_cause: StringName
var settings_runtime: SettingsRuntime


func _ready() -> void:
	TranslationServer.set_locale("zh_CN")
	SceneRouter.configure(%LevelHost, route_catalog)
	SaveService.catalog = item_catalog
	if use_config != null:
		item_use.config = use_config
	interactor.camera = player.camera
	interactor.context = interaction_context
	interactor.exclude = [player.get_rid()]
	interactor.focus_changed.connect(shell.set_interaction)
	interactor.interaction_performed.connect(player.play_interaction)
	interaction_context.pickup_requested.connect(_pickup)
	interaction_context.travel_requested.connect(travel)
	interaction_context.notice_requested.connect(_notify_key)
	world_items.notice_requested.connect(_notify_key)
	item_use.phone_requested.connect(_open_phone)
	item_use.notice_requested.connect(_notify_key)
	GameState.mode_changed.connect(_on_mode_changed)
	Settings.changed.connect(_on_settings_changed)
	SaveService.result_reported.connect(_notify_key)
	shell.new_game_requested.connect(new_game)
	shell.resume_requested.connect(_resume)
	shell.close_requested.connect(_resume)
	shell.save_requested.connect(save_run)
	shell.load_requested.connect(load_run)
	shell.menu_requested.connect(return_to_menu)
	shell.settings_changed.connect(Settings.apply)
	shell.preference_changed.connect(Settings.set_value)
	shell.restore_preferences_requested.connect(Settings.reset_defaults)
	shell.debug_give_requested.connect(_debug_give)
	shell.debug_reload_requested.connect(_reload)
	shell.debug_travel_requested.connect(_debug_travel)
	shell.debug_damage_requested.connect(_debug_damage)
	shell.phone_send_requested.connect(_send_message)
	shell.set_item_catalog(item_catalog.definitions)
	shell.set_save_available(SaveService.has_save())
	shell.set_controls_hint(tr(&"CONTROLS_HINT"))
	inventory_view.placement_requested.connect(_place)
	inventory_view.equip_requested.connect(_equip)
	inventory_view.drop_requested.connect(_drop)
	inventory_view.use_requested.connect(_use_item)
	inventory_view.stow_requested.connect(_stow)
	inventory_view.close_requested.connect(_resume)
	inventory_view.set_description_resolver(_describe_item)
	player.fell_out_of_world.connect(_on_fell)
	_bind_session()
	settings_runtime = SettingsRuntime.new()
	add_child(settings_runtime)
	settings_runtime.configure(player)
	_on_settings_changed()
	GameState.set_mode(&"menu")


func _input(event: InputEvent) -> void:
	if event.is_echo() or SceneRouter.busy:
		return
	var handled: bool = true
	if event.is_action_pressed(&"pause") and GameState.mode not in [&"menu", &"dead", &"transition"]:
		GameState.set_mode(&"pause" if GameState.mode == &"play" else &"play")
	elif event.is_action_pressed(&"inventory") and GameState.mode in [&"play", &"inventory"]:
		GameState.set_mode(&"inventory" if GameState.mode == &"play" else &"play")
	elif event.is_action_pressed(&"debug_panel") and Settings.developer_mode and GameState.mode in [&"play", &"debug"]:
		GameState.set_mode(&"debug" if GameState.mode == &"play" else &"play")
	elif event.is_action_pressed(&"phone") and GameState.mode == &"play":
		_open_owned_phone()
	elif event.is_action_pressed(&"use_primary") and GameState.mode == &"play":
		_use_item(Session.data.inventory.equipment.get(&"primary_hand", ""))
	elif event.is_action_pressed(&"use_secondary") and GameState.mode == &"play":
		_use_item(Session.data.inventory.equipment.get(&"secondary_hand", ""))
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	shell.set_crosshair_motion(Vector2(player.velocity.x, player.velocity.z).length())
	if GameState.mode == &"play":
		for item: ItemInstance in equipment_view.active_flashlights():
			item.charge.consume(minf(item.charge.current, item_use.config.flashlight_drain_per_second * delta))
		equipment_view.update_light()
	elif GameState.mode == &"phone":
		var phone_item: ItemInstance = Session.data.inventory.get_item(_phone_uid)
		if phone_item != null:
			phone_item.charge.consume(minf(phone_item.charge.current, item_use.config.phone_drain_per_second * delta))
	_ui_timer += delta
	if _ui_timer >= 0.5:
		_ui_timer = 0.0
		_refresh_debug()
		if GameState.mode == &"phone":
			shell.refresh_phone_charge()


func new_game(difficulty: int) -> bool:
	if SceneRouter.busy or difficulty < 0 or difficulty > 2:
		return false
	var next: SessionData = SessionData.new()
	next.run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	next.difficulty = difficulty as SessionData.Difficulty
	if not loadout.populate(next.inventory):
		_notify_key(&"ERR_ITEM")
		return false
	var next_world: WorldData = WorldData.new()
	if not await _enter(initial_route, &"default", next, next_world):
		return false
	await get_tree().physics_frame
	await get_tree().physics_frame
	save_run(true)
	return true


func travel(level_id: StringName, entrance_id: StringName = &"default") -> bool:
	if GameState.mode in [&"menu", &"dead", &"transition"] or SceneRouter.busy:
		return false
	return await _enter(level_id, entrance_id, Session.data, WorldState.data)


func _enter(level_id: StringName, entrance_id: StringName, next: SessionData, next_world: WorldData, saved: SaveSnapshot = null) -> bool:
	var previous_mode: StringName = GameState.mode
	GameState.set_mode(&"transition")
	var success: bool = await SceneRouter.travel_to(level_id, entrance_id)
	if not success:
		GameState.set_mode(previous_mode)
		_notify_key(&"ERR_ROUTE")
		return false
	Session.replace(next)
	WorldState.data = next_world
	WorldState.data.level_id = level_id
	WorldState.data.entrance_id = entrance_id
	WorldState.data.time_scale = route_catalog.find(level_id).time_scale
	_bind_session()
	world_items.enter_room(SceneRouter.current_room, level_id)
	var entrance: RoomEntrance = SceneRouter.current_room.get_entrance(entrance_id)
	player.restore_transform(entrance.global_transform if saved == null else saved.player_transform)
	if saved != null:
		Settings.load_data(saved.preferences)
	_refresh_inventory()
	GameState.set_mode(&"play")
	_notify_key(SceneRouter.current_room.title_key)
	return true


func _bind_session() -> void:
	player.bind_stats(Session.data.stats)
	if not Session.data.stats.died.is_connected(_on_died):
		Session.data.stats.died.connect(_on_died)
	interaction_context.inventory = Session.data.inventory
	item_use.inventory = Session.data.inventory
	item_use.stats = Session.data.stats
	world_items.configure(Session.data.inventory, WorldState.data, item_catalog)
	equipment_view.configure(player, Session.data.inventory)
	shell.set_stats(Session.data.stats)
	shell.set_manual_save_allowed(Session.data.difficulty == SessionData.Difficulty.CASUAL)
	inventory_view.bind_model(Session.data.inventory, Session.data.stats.carry_capacity_kg)
	if not Session.data.inventory.changed.is_connected(_refresh_inventory):
		Session.data.inventory.changed.connect(_refresh_inventory)
	_refresh_inventory()


func _refresh_inventory() -> void:
	player.load_ratio = Session.data.inventory.get_total_weight() / Session.data.stats.carry_capacity_kg
	var names: PackedStringArray = []
	for slot: StringName in [&"primary_hand", &"secondary_hand"]:
		var item: ItemInstance = Session.data.inventory.get_item(Session.data.inventory.equipment.get(slot, ""))
		if item != null:
			names.append(tr(item.definition.display_name))
	shell.set_held_item(" / ".join(names))


func _on_mode_changed(mode: StringName) -> void:
	var playing: bool = mode == &"play"
	player.set_control_enabled(playing)
	player.visible = mode != &"menu"
	interactor.enabled = playing
	interactor.refresh_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	shell.set_mode(mode)
	inventory_view.visible = mode == &"inventory"
	if inventory_view.visible:
		inventory_view.refresh()
	loading_cover.visible = mode == &"transition"
	_refresh_debug()


func _on_settings_changed() -> void:
	player.headbob_enabled = Settings.headbob
	shell.set_preferences(Settings.immersive_hud, Settings.headbob)
	shell.set_controls_hint(tr(&"CONTROLS_HINT") + (" · F1 调试" if Settings.developer_mode else ""))


func _resume() -> void:
	if GameState.mode not in [&"dead", &"menu", &"transition"]:
		GameState.set_mode(&"play")


func _place(uid: String, container_uid: String, cell: Vector2i, rotation: int) -> void:
	var model: InventoryModel = Session.data.inventory
	if model.is_owned(uid) and model.is_owned(container_uid):
		if not model.try_place(uid, container_uid, cell, rotation):
			_notify_key(model.last_error)


func _equip(uid: String, slot: StringName) -> void:
	var model: InventoryModel = Session.data.inventory
	if model.is_owned(uid) and not model.equip(uid, slot):
		_notify_key(model.last_error)


func _stow(uid: String, container_uid: String) -> void:
	var model: InventoryModel = Session.data.inventory
	if model.is_owned(uid) and model.is_owned(container_uid) and not model.auto_place(uid, container_uid):
		_notify_key(model.last_error)


func _pickup(uid: String) -> void:
	if world_items.pickup(uid):
		equipment_view.suppress_primary_for_pickup()


func _drop(uid: String) -> void:
	if Session.data.inventory.is_owned(uid):
		world_items.drop(uid, world_items.find_drop_transform(uid, player))


func _use_item(uid: String) -> void:
	if item_use.use(uid):
		player.play_interaction()


func _describe_item(uid: String) -> String:
	return ItemDescriptionResolver.resolve(Session.data.inventory.get_item(uid), WorldState.data.flags)


func _open_owned_phone() -> void:
	for item: ItemInstance in Session.data.inventory.items.values():
		if item.definition.use_action == &"phone" and Session.data.inventory.is_owned(item.uid):
			_use_item(item.uid)
			return
	_notify_key(&"NOTICE_NO_PHONE")


func _open_phone(uid: String) -> void:
	_phone_uid = uid
	shell.bind_phone(Session.data.phone, Session.data.inventory.get_item(uid).charge)
	GameState.set_mode(&"phone")


func _send_message(text: String, conversation_id: StringName = &"default") -> void:
	var item: ItemInstance = Session.data.inventory.get_item(_phone_uid)
	if GameState.mode != &"phone" or item == null or not Session.data.inventory.is_owned(item.uid):
		return
	if item.charge.current < item_use.config.message_charge_cost:
		_notify_key(&"NOTICE_NO_CHARGE")
	elif Session.data.phone.send_message(text, conversation_id):
		item.charge.consume(item_use.config.message_charge_cost)
		shell.refresh_phone_charge()


func capture_snapshot() -> SaveSnapshot:
	var result: SaveSnapshot = SaveSnapshot.new()
	result.session = Session.data
	result.world = WorldState.data
	result.player_transform = player.get_save_transform()
	result.preferences = Settings.to_data()
	return result


func save_run(automatic: bool = false) -> bool:
	if GameState.mode not in [&"play", &"pause"] or Session.data.stats.get_value(&"health") <= 0.0:
		return false
	if not automatic and (not player.is_on_floor() or player.stand_clearance.is_colliding()):
		_notify_key(&"ERR_UNSAFE_SAVE")
		return false
	var success: bool = SaveService.write_snapshot(capture_snapshot(), automatic)
	shell.set_save_available(SaveService.has_save())
	return success


func load_run() -> bool:
	if SceneRouter.busy or (GameState.mode == &"dead" and Session.data.difficulty == SessionData.Difficulty.EXTREME):
		return false
	var saved: SaveSnapshot = SaveService.read_snapshot()
	if saved == null:
		return false
	return await _enter(saved.world.level_id, saved.world.entrance_id, saved.session, saved.world, saved)


func return_to_menu() -> void:
	if SceneRouter.busy:
		return
	if GameState.mode == &"dead" and Session.data.difficulty == SessionData.Difficulty.EXTREME:
		if not SaveService.finalize_extreme_death(Session.data.run_id):
			_notify_key(&"ERR_SAVE")
			return
	GameState.set_mode(&"menu")
	shell.set_save_available(SaveService.has_save())


func _on_died(cause: StringName) -> void:
	_death_cause = cause
	GameState.set_mode(&"dead")
	shell.show_death(tr(&"DEATH_" + String(cause).to_upper()), Session.data.difficulty)


func _on_fell() -> void:
	if GameState.mode == &"play":
		Session.data.stats.change_value(&"health", -Session.data.stats.get_maximum(&"health"))


func _debug_give(id: StringName) -> void:
	if not Settings.developer_mode or GameState.mode != &"debug":
		return
	var item: ItemInstance = Session.data.inventory.add_item(item_catalog.find(id))
	if item == null:
		_notify_key(&"ERR_ITEM")
		return
	world_items.world.world_items[item.uid] = {"level_id": String(SceneRouter.current_id), "transform": world_items.find_drop_transform(item.uid, player)}
	if not world_items.pickup(item.uid):
		world_items.refresh()


func _reload() -> void:
	if Settings.developer_mode:
		travel(SceneRouter.current_id, SceneRouter.current_entrance)


func _debug_travel() -> void:
	if not Settings.developer_mode:
		return
	for route: RouteDefinition in route_catalog.routes:
		if route.id != SceneRouter.current_id:
			travel(route.id)
			return


func _debug_damage() -> void:
	if Settings.developer_mode:
		Session.data.stats.change_value(&"health", -Session.data.stats.get_maximum(&"health"))


func _refresh_debug() -> void:
	var stats_text: PackedStringArray = []
	for id: StringName in PlayerStats.STAT_IDS:
		stats_text.append("%s %.1f" % [tr(&"SHELL_STAT_" + String(id).to_upper()), Session.data.stats.get_value(id)])
	shell.update_debug({"scene": String(SceneRouter.current_id), "position": str(player.global_position), "fps": Engine.get_frames_per_second(), "seed": WorldState.data.seed, "flags": str(WorldState.data.flags), "stats": " / ".join(stats_text), "weight": "%.2f / %.2f kg" % [Session.data.inventory.get_total_weight(), Session.data.stats.carry_capacity_kg], "world_time": WorldState.clock_text()})


func _notify_key(key: StringName) -> void:
	shell.notify(tr(key))
