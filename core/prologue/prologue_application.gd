class_name PrologueApplication
extends FoundationApp

var director: PrologueDirector
var handheld: HandheldPhone
var audio: PrologueAudio
var fade: ColorRect
var photos: PhotoStorage = PhotoStorage.new()
var _last_clock: String = ""
var camera_overlay: CameraOverlay
var _capture_pending: bool = false
var appearance_creator: CharacterCreator


func _ready() -> void:
	$WorldEnvironment.environment = null
	super._ready()
	SaveService.photo_gc_enabled = true
	SaveService.photo_storage = photos
	WorldState.clock_modes = [&"play", &"phone", &"camera", &"inventory"]
	audio = PrologueAudio.new()
	add_child(audio)
	director = PrologueDirector.new()
	add_child(director)
	director.configure(self)
	handheld = HandheldPhone.new()
	player.camera.add_child(handheld)
	handheld.configure(player.camera)
	settings_runtime.view_preferences_applied.connect(handheld.set_world_fov)
	handheld.set_world_fov(Settings.fov)
	handheld.view.close_requested.connect(_resume)
	handheld.view.send_requested.connect(_send_message)
	handheld.view.conversation_send_requested.connect(_send_conversation_message)
	handheld.view.app_requested.connect(_on_phone_app_requested)
	handheld.view.profile_submitted.connect(_submit_profile)
	handheld.view.capture_requested.connect(_open_camera)
	handheld.view.photo_selected.connect(_select_photo)
	handheld.view.appearance_edit_requested.connect(_open_appearance_editor)
	var camera_layer := CanvasLayer.new()
	camera_layer.layer = 18
	add_child(camera_layer)
	camera_overlay = CameraOverlay.new()
	camera_layer.add_child(camera_overlay)
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.visible = false
	overlay.add_child(fade)
	loading_cover.get_child(0).hide()
	inventory_view.get_node("%InventoryGrid").item_selected.connect(director.on_item_selected)
	inventory_view.placement_requested.connect(director.on_item_placed)
	# Menu background is a real scene; starting a run replaces it transactionally.
	await SceneRouter.travel_to(initial_route)
	player.restore_transform(Transform3D(Basis.from_euler(Vector3(0, 0.35, 0)), Vector3(1.55, 0.02, 2.1)))
	GameState.set_mode(&"menu")


func _exit_tree() -> void:
	if director != null:
		director.cancel_sequences()
	WorldState.clock_modes = [&"play"]
	SaveService.photo_gc_enabled = false


func _input(event: InputEvent) -> void:
	if GameState.mode == &"appearance":
		if event.is_action_pressed(&"pause"):
			_close_appearance_editor()
			get_viewport().set_input_as_handled()
		return
	if GameState.mode == &"camera":
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"phone"):
			show_phone(_phone_uid)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_capture_photo()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"phone") and GameState.mode == &"phone":
		_resume()
		get_viewport().set_input_as_handled()
		return
	super._input(event)
	if Session.data.prologue.enabled and event is InputEventMouseMotion and GameState.mode == &"play":
		Session.data.prologue.mark_tutorial("look")


func _process(delta: float) -> void:
	super._process(delta)
	if handheld != null and GameState.mode in [&"phone", &"camera"]:
		var phone_item: ItemInstance = Session.data.inventory.get_item(_phone_uid)
		if phone_item == null or not Session.data.inventory.is_owned(_phone_uid) or phone_item.charge.current <= 0.0:
			_resume()
			_notify_key(&"NOTICE_NO_CHARGE")
			return
		if GameState.mode == &"camera":
			phone_item.charge.consume(minf(phone_item.charge.current, item_use.config.phone_drain_per_second * delta))
			camera_overlay.set_charge(phone_item.charge.current / maxf(0.01, phone_item.charge.maximum) * 100.0, Session.data.phone.offline)
		var current_clock: String = WorldState.clock_text()
		if current_clock != _last_clock:
			_last_clock = current_clock
			handheld.view.set_clock(current_clock)


func new_game(difficulty: int) -> bool:
	return await director.new_run(difficulty)


func enter_session(level_id: StringName, entrance_id: StringName, session: SessionData, world: WorldData) -> bool:
	return await _enter(level_id, entrance_id, session, world)


func _enter(level_id: StringName, entrance_id: StringName, next: SessionData, next_world: WorldData, saved: SaveSnapshot = null) -> bool:
	var success: bool = await super._enter(level_id, entrance_id, next, next_world, saved)
	if success and director != null:
		director.enter_room()
	return success


func _bind_session() -> void:
	super._bind_session()
	PlayerAppearance.apply(player, Session.data.profile)


func _on_mode_changed(mode: StringName) -> void:
	super._on_mode_changed(mode)
	if mode in [&"camera", &"appearance"]:
		shell.notify("")
	if handheld == null:
		return
	if mode != &"phone":
		handheld.hide_phone()
	player.primary_hand_mount.visible = mode not in [&"phone", &"camera"]
	player.secondary_hand_mount.visible = mode not in [&"phone", &"camera"]
	player.get_node("BodyVisual").visible = mode != &"phone"
	if camera_overlay != null:
		camera_overlay.visible = mode == &"camera"
	if appearance_creator != null:
		appearance_creator.visible = mode == &"appearance"
	if mode == &"camera":
		player.set_control_enabled(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if mode == &"inventory" and Session.data.prologue.enabled:
		director.on_inventory_opened()


func _open_phone(uid: String) -> void:
	show_phone(uid)


func show_phone(uid: String) -> void:
	var item: ItemInstance = Session.data.inventory.get_item(uid)
	if item == null or not Session.data.inventory.is_owned(uid) or item.charge.current <= 0.0:
		return
	_phone_uid = uid
	GameState.set_mode(&"phone")
	handheld.show_phone(Session.data.phone, item.charge, Session.data.profile)
	handheld.view.set_clock(WorldState.clock_text())
	handheld.view.set_photos(Session.data.album.photos)


func _send_message(text: String, conversation_id: StringName = &"default") -> void:
	super._send_message(text, conversation_id)
	# The view observes PhoneState.changed; retain the selected conversation page.


func _send_conversation_message(conversation_id: StringName, text: String) -> void:
	_send_message(text, conversation_id)


func _on_phone_app_requested(id: StringName) -> void:
	Session.data.phone.set_active_app(id)


func _open_camera() -> void:
	var item: ItemInstance = Session.data.inventory.get_item(_phone_uid)
	if GameState.mode == &"phone" and item != null and Session.data.inventory.is_owned(item.uid) and item.charge.current >= 0.25:
		GameState.set_mode(&"camera")


func _submit_profile(data: Dictionary) -> void:
	director.register_profile(data)


func _open_appearance_editor() -> void:
	if GameState.mode != &"phone" or Session.data.profile.registered:
		return
	var draft := CharacterAppearance.new()
	if not draft.load_data(handheld.view.get_appearance_data()):
		draft = Session.data.profile.appearance.copy()
	if appearance_creator == null:
		var layer := CanvasLayer.new()
		layer.layer = 19
		add_child(layer)
		appearance_creator = CharacterCreator.new()
		layer.add_child(appearance_creator)
		appearance_creator.set_supported_morphs(GdHumanBackend.SUPPORTED_MORPHS)
		appearance_creator.set_preview_character(HumanCharacter.new())
		appearance_creator.confirmed.connect(_accept_appearance)
		appearance_creator.cancelled.connect(_close_appearance_editor)
	GameState.set_mode(&"appearance")
	appearance_creator.edit(draft)


func _accept_appearance(value: CharacterAppearance) -> void:
	handheld.view.set_appearance_data(value.to_data())
	_close_appearance_editor()


func _close_appearance_editor() -> void:
	if appearance_creator != null:
		appearance_creator.hide()
	show_phone(_phone_uid)


func _pickup(uid: String) -> void:
	super._pickup(uid)
	if director != null:
		director.on_pickup(uid)


func _capture_photo() -> void:
	var item: ItemInstance = Session.data.inventory.get_item(_phone_uid)
	if _capture_pending or GameState.mode != &"camera" or item == null or not Session.data.inventory.is_owned(item.uid) or item.charge.current < 0.25:
		return
	_capture_pending = true
	var run_id: String = Session.data.run_id
	var capture_mode: StringName = GameState.mode
	var target_size: Vector2i = Vector2i(get_viewport().get_visible_rect().size) if capture_mode == &"camera" else HandheldPhone.CAMERA_VIEWPORT_SIZE
	var picture: Image = await handheld.capture_image(target_size)
	_capture_pending = false
	if GameState.mode != capture_mode or Session.data.run_id != run_id or not Session.data.inventory.is_owned(item.uid):
		return
	var photo_id: String = photos.capture(Session.data.run_id, picture, Session.data.album, WorldState.data.clock_seconds)
	if photo_id.is_empty():
		handheld.view.set_notice(tr(&"PRO_PHOTO_FAILED"))
		camera_overlay.shutter_feedback(false)
		return
	item.charge.consume(0.25)
	handheld.view.set_photos(Session.data.album.photos, photos.read(Session.data.run_id, photo_id), photo_id)
	handheld.view.set_notice(tr(&"PRO_PHOTO_SAVED"))
	camera_overlay.shutter_feedback(true)


func _select_photo(id: String) -> void:
	for row: Dictionary in Session.data.album.photos:
		if row["id"] == id:
			handheld.view.set_photos(Session.data.album.photos, photos.read(Session.data.run_id, id), id)
			return


func save_run(automatic: bool = false) -> bool:
	if Session.data.prologue.enabled and not Session.data.profile.registered:
		_notify_key(&"PRO_REGISTER_FIRST")
		return false
	return super.save_run(automatic)


func load_run() -> bool:
	if director != null and director.sequence_busy():
		return false
	return await super.load_run()


func return_to_menu() -> void:
	if SceneRouter.busy:
		return
	if director != null:
		director.cancel_sequences()
	super.return_to_menu()


func _notify_key(key: StringName) -> void:
	# Scene names are routing metadata, not title cards during the opening.
	if key in [&"PRO_APARTMENT_TITLE", &"PRO_COMMUTE_TITLE", &"PRO_ARRIVAL_TITLE"]:
		return
	if key == &"NOTICE_SAVED":
		shell.notify(tr(&"PRO_SAVED"))
		return
	super._notify_key(key)
