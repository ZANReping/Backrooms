class_name DiegeticPhoneView
extends Control

signal close_requested
signal send_requested(text: String)
signal conversation_send_requested(conversation_id: StringName, text: String)
signal app_requested(app_id: StringName)
signal profile_submitted(data: Dictionary)
signal capture_requested
signal photo_selected(photo_id: String)
signal appearance_edit_requested

const CONTENT: PhoneContentCatalog = preload("res://resources/phone/local_content.tres")
const APP_IDS: Array[StringName] = [&"chat", &"maps", &"browser", &"phone", &"camera", &"clock", &"workspace"]
const APP_KEYS: Array[StringName] = [&"PHONE_APP_CHAT", &"PHONE_APP_MAPS", &"PHONE_APP_BROWSER", &"PHONE_APP_PHONE", &"PHONE_APP_CAMERA", &"PHONE_APP_CLOCK", &"PHONE_APP_WORKSPACE"]
const APP_COLORS: Array[Color] = [Color("38a169"), Color("4d7cfe"), Color("4f8df7"), Color("26a65b"), Color("29313d"), Color("ef8d32"), Color("5965d8")]
const CONVERSATION_IDS: Array[StringName] = [&"lin_qian", &"a_ming", &"project_group"]

var _phone: PhoneState
var _charge: ChargeState
var _profile: CharacterProfile
var _clock_text: String = "07:48"
var _notice_text: String = ""
var _camera_texture: Texture2D
var _photos: Array[Dictionary] = []
var _photo_texture: Texture2D
var _page: StringName = &"home"
var _chat_conversation: StringName = &"lin_qian"
var _phone_tab: StringName = &"recents"
var _selected_photo_id: String = ""
var _pending_registration: bool = false
var _pending_appearance_data: Dictionary = {}
var _registration_draft: Dictionary = {}
var _registration_options: Dictionary = {}
var _registration_avatar: PhoneAvatarPreview

var _status_time: Label
var _status_network: Label
var _status_charge: Label
var _title: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _fixed_content: VBoxContainer
var _notice: Label
var _back_button: Button
var _home_button: Button
var _clock_display: Label
var _chat_send: Button
var _camera_capture: Button
var _camera_preview: TextureRect
var _photo_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(360.0, 640.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	if _pending_registration:
		_show_registration_form()
	elif is_instance_valid(_phone) and _phone.active_app in APP_IDS:
		_show_app(_phone.active_app)
	else:
		_show_home()


func bind_state(phone: PhoneState, charge: ChargeState, profile: CharacterProfile) -> void:
	if _phone != phone:
		_registration_draft.clear()
		_pending_appearance_data.clear()
		_registration_options.clear()
		_page = &"home"
	if is_instance_valid(_phone) and _phone.changed.is_connected(_on_phone_changed):
		_phone.changed.disconnect(_on_phone_changed)
	_phone = phone
	_charge = charge
	_profile = profile
	if is_instance_valid(_phone) and not _phone.changed.is_connected(_on_phone_changed):
		_phone.changed.connect(_on_phone_changed)
	if not is_node_ready():
		return
	_refresh_status()
	if _page == &"registration":
		return
	if is_instance_valid(_phone) and _phone.active_app in APP_IDS:
		_show_app(_phone.active_app)
	else:
		_show_home()


func set_clock(text: String) -> void:
	_clock_text = text
	if is_instance_valid(_status_time):
		_status_time.text = text
	if _page == &"clock" and is_instance_valid(_clock_display):
		_clock_display.text = text


func set_camera_texture(texture: Texture2D) -> void:
	_camera_texture = texture
	if _page == &"camera":
		_show_camera()


func set_notice(text: String) -> void:
	_notice_text = text
	if is_instance_valid(_notice):
		_notice.text = text
		_notice.visible = not text.is_empty()


func show_registration() -> void:
	_pending_registration = true
	if not is_node_ready():
		return
	_page = &"registration"
	_show_registration_form()


func set_appearance_data(data: Dictionary) -> void:
	_pending_appearance_data = data.duplicate(true)
	if is_instance_valid(_registration_avatar) and not _registration_options.is_empty():
		_registration_avatar.set_appearance(get_appearance_data())


func get_appearance_data() -> Dictionary:
	if not _pending_appearance_data.is_empty():
		return _pending_appearance_data.duplicate(true)
	var legacy: Dictionary = CharacterProfile.DEFAULT_APPEARANCE.duplicate(true)
	if not _registration_options.is_empty():
		legacy = _appearance_from(_registration_options)
	elif _registration_draft.has("appearance_preset"):
		legacy = Dictionary(_registration_draft["appearance_preset"]).duplicate(true)
	return CharacterAppearance.from_legacy(legacy).to_data()


func set_photos(rows: Array[Dictionary], texture: Texture2D = null, texture_photo_id: String = "") -> void:
	_photos = rows.duplicate(true)
	_photo_texture = texture
	_selected_photo_id = texture_photo_id if _has_photo(texture_photo_id) else ""
	if _selected_photo_id.is_empty():
		_photo_texture = null
	if _page == &"camera":
		_show_camera()


func refresh_charge() -> void:
	_refresh_status()
	var empty: bool = not _has_charge()
	if is_instance_valid(_chat_send):
		_chat_send.disabled = empty
		_chat_send.tooltip_text = tr(&"PHONE_NO_CHARGE") if empty else ""
	if is_instance_valid(_camera_capture):
		_camera_capture.disabled = empty
		_camera_capture.tooltip_text = tr(&"PHONE_NO_CHARGE") if empty else ""


func clear_external_textures() -> void:
	_camera_texture = null
	_photo_texture = null
	if is_instance_valid(_camera_preview):
		_camera_preview.texture = null
	for button: Button in _photo_buttons:
		if is_instance_valid(button):
			button.icon = null
	_photo_buttons.clear()


func open_app(app_id: StringName) -> void:
	if app_id in APP_IDS:
		_request_app(app_id)


func _build_shell() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 0)
	add_child(root)

	var status_panel := PanelContainer.new()
	status_panel.theme_type_variation = &"PhoneChrome"
	status_panel.custom_minimum_size.y = 28.0
	root.add_child(status_panel)
	var status := HBoxContainer.new()
	status.add_theme_constant_override(&"separation", 8)
	status_panel.add_child(status)
	_status_time = _label(_clock_text, &"PhoneChromeLabel")
	_status_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(_status_time)
	_status_network = _label(tr(&"PHONE_STATUS_LOCAL"), &"PhoneChromeLabel")
	_status_network.add_theme_font_size_override(&"font_size", 13)
	status.add_child(_status_network)
	_status_charge = _label("--%", &"PhoneChromeLabel")
	status.add_child(_status_charge)

	var title_panel := PanelContainer.new()
	title_panel.theme_type_variation = &"PhoneContent"
	title_panel.custom_minimum_size.y = 48.0
	root.add_child(title_panel)
	var title_row := HBoxContainer.new()
	title_panel.add_child(title_row)
	_title = _label(tr(&"PHONE_HOME_TITLE"), &"PhoneTitle")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title)
	var close := _icon_button(&"x", tr(&"PHONE_CLOSE"), 40.0)
	close.tooltip_text = tr(&"PHONE_CLOSE")
	close.pressed.connect(func() -> void: close_requested.emit())
	title_row.add_child(close)

	var body_panel := PanelContainer.new()
	body_panel.theme_type_variation = &"PhoneContent"
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 7)
	body_panel.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 10)
	_scroll.add_child(_content)
	_fixed_content = VBoxContainer.new()
	_fixed_content.add_theme_constant_override(&"separation", 0)
	body.add_child(_fixed_content)
	_notice = _label("", &"PhoneMutedLabel")
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false
	body.add_child(_notice)

	var nav_panel := PanelContainer.new()
	nav_panel.theme_type_variation = &"PhoneChrome"
	nav_panel.custom_minimum_size.y = 42.0
	root.add_child(nav_panel)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override(&"separation", 22)
	nav_panel.add_child(nav)
	_back_button = _icon_button(&"arrow-left", tr(&"PHONE_BACK"), 64.0)
	_style_system_nav_button(_back_button)
	_back_button.tooltip_text = tr(&"PHONE_BACK")
	_back_button.pressed.connect(_on_back)
	nav.add_child(_back_button)
	_home_button = _icon_button(&"house", tr(&"PHONE_HOME"), 64.0)
	_style_system_nav_button(_home_button)
	_home_button.tooltip_text = tr(&"PHONE_HOME")
	_home_button.pressed.connect(_show_home)
	nav.add_child(_home_button)


func _show_home() -> void:
	_page = &"home"
	_title.text = ""
	_clear_content()
	var hero := PanelContainer.new()
	hero.theme_type_variation = &"PhoneHero"
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override(&"separation", 1)
	hero.add_child(hero_box)
	var date := _label(tr(&"PHONE_HOME_DATE"), &"PhoneHeroMeta")
	hero_box.add_child(date)
	var home_clock := _label(_clock_text, &"PhoneHeroClock")
	hero_box.add_child(home_clock)
	_content.add_child(hero)
	var greeting := _label(tr(&"PHONE_HOME_GREETING"), &"PhoneMutedLabel")
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(greeting)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 7)
	grid.add_theme_constant_override(&"v_separation", 14)
	_content.add_child(grid)
	for index: int in APP_IDS.size():
		var id: StringName = APP_IDS[index]
		var button := _app_button(id, tr(APP_KEYS[index]), APP_COLORS[index])
		button.pressed.connect(_request_app.bind(id))
		grid.add_child(button)
	_refresh_status()


func _request_app(app_id: StringName) -> void:
	app_requested.emit(app_id)
	_show_app(app_id)


func _show_app(app_id: StringName) -> void:
	match app_id:
		&"chat": _show_chat()
		&"maps": _show_maps()
		&"browser": _show_browser()
		&"phone": _show_phone()
		&"camera": _show_camera()
		&"clock": _show_clock()
		&"workspace": _show_workspace()
		_: _show_home()


func _show_chat() -> void:
	_begin_page(&"chat", &"PHONE_APP_CHAT")
	var search := _line_edit(&"PHONE_CHAT_SEARCH")
	search.right_icon = UiIcons.tinted_icon(&"search", Color(0.35, 0.39, 0.45))
	_content.add_child(search)
	var conversation_list := VBoxContainer.new()
	conversation_list.add_theme_constant_override(&"separation", 10)
	_content.add_child(conversation_list)
	for index: int in CONTENT.conversations.size():
		var conversation: Dictionary = CONTENT.conversations[index]
		var card := PanelContainer.new()
		card.theme_type_variation = &"PhoneCard"
		card.set_meta(&"search_text", "%s %s" % [tr(conversation.get("name_key", &"")), tr(conversation.get("preview_key", &""))])
		var thread := Button.new()
		thread.flat = true
		thread.alignment = HORIZONTAL_ALIGNMENT_LEFT
		thread.custom_minimum_size.y = 62.0
		thread.tooltip_text = tr(conversation.get("name_key", &""))
		thread.pressed.connect(_show_chat_detail.bind(CONVERSATION_IDS[index]))
		card.add_child(thread)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		var avatar := _avatar_letter(tr(conversation.get("name_key", &"")))
		heading.add_child(avatar)
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_child(_section_title(tr(conversation.get("name_key", &""))))
		identity.add_child(_wrapped(tr(conversation.get("preview_key", &"")), true))
		heading.add_child(identity)
		var thread_time := _label(tr(conversation.get("time_key", &"")), &"PhoneMutedLabel")
		thread_time.add_theme_font_size_override(&"font_size", 12)
		heading.add_child(thread_time)
		thread.add_child(heading)
		conversation_list.add_child(card)
	search.text_changed.connect(func(query: String) -> void:
		var needle := query.strip_edges().to_lower()
		for card_node: Node in conversation_list.get_children():
			var haystack := String(card_node.get_meta(&"search_text", "")).to_lower()
			(card_node as Control).visible = needle.is_empty() or haystack.contains(needle)
	)


func _show_chat_detail(conversation_id: StringName) -> void:
	_chat_conversation = conversation_id
	_page = &"chat_detail"
	_clear_content()
	var index: int = CONVERSATION_IDS.find(conversation_id)
	if index < 0:
		index = 0
		_chat_conversation = CONVERSATION_IDS[0]
	var conversation: Dictionary = CONTENT.conversations[index]
	_title.text = tr(conversation.get("name_key", &"PHONE_APP_CHAT"))
	for key: Variant in conversation.get("lines", []):
		var outgoing: bool = StringName(key) == &"PHONE_CHAT_FRIEND_2"
		_content.add_child(_chat_bubble(tr(StringName(key)), outgoing))
	if is_instance_valid(_phone):
		for message: Dictionary in _phone.messages:
			var message_conversation := StringName(message.get("conversation_id", &"default"))
			if message_conversation == &"default":
				message_conversation = CONVERSATION_IDS[0]
			if message_conversation != _chat_conversation:
				continue
			var status_key: StringName = &"PHONE_MESSAGE_FAILED" if StringName(message.get("status", &"sent")) == &"failed" else &"PHONE_MESSAGE_SENT"
			_content.add_child(_chat_bubble("%s\n%s" % [String(message.get("text", "")), tr(status_key)], true))
	var composer := PanelContainer.new()
	composer.theme_type_variation = &"PhoneComposer"
	var compose_box := VBoxContainer.new()
	composer.add_child(compose_box)
	var input := TextEdit.new()
	input.name = "MessageInput"
	input.placeholder_text = tr(&"PHONE_CHAT_PLACEHOLDER")
	input.custom_minimum_size.y = 74.0
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	compose_box.add_child(input)
	var count := _label("0 / 1000", &"PhoneMutedLabel")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	compose_box.add_child(count)
	input.text_changed.connect(func() -> void:
		if input.text.length() > PhoneState.MAX_MESSAGE_LENGTH:
			input.text = input.text.left(PhoneState.MAX_MESSAGE_LENGTH)
			input.set_caret_column(input.text.length())
		count.text = "%d / %d" % [input.text.length(), PhoneState.MAX_MESSAGE_LENGTH]
	)
	_chat_send = _button(tr(&"PHONE_CHAT_SEND"), 0.0)
	_chat_send.disabled = not _has_charge()
	_chat_send.tooltip_text = tr(&"PHONE_NO_CHARGE") if _chat_send.disabled else ""
	_chat_send.pressed.connect(func() -> void:
		var text: String = input.text.strip_edges()
		if text.is_empty():
			set_notice(tr(&"PHONE_EMPTY_MESSAGE"))
			return
		conversation_send_requested.emit(_chat_conversation, text)
		input.clear()
	)
	_chat_send.icon = UiIcons.icon(&"send")
	compose_box.add_child(_chat_send)
	_fixed_content.add_child(composer)


func _show_maps() -> void:
	_begin_page(&"maps", &"PHONE_APP_MAPS")
	var search := _line_edit(&"PHONE_MAP_SEARCH")
	search.editable = false
	search.right_icon = UiIcons.tinted_icon(&"search", Color(0.35, 0.39, 0.45))
	_content.add_child(search)
	var map := Control.new()
	map.custom_minimum_size = Vector2(320.0, 238.0)
	map.draw.connect(_draw_map.bind(map))
	_content.add_child(map)
	if is_instance_valid(_phone) and _phone.offline:
		_content.add_child(_wrapped(tr(&"PHONE_MAP_LOCATION_UNAVAILABLE"), true))
	var route_card := PanelContainer.new()
	route_card.theme_type_variation = &"PhoneRouteCard"
	var route_box := VBoxContainer.new()
	route_card.add_child(route_box)
	route_box.add_child(_section_title(tr(&"PHONE_MAP_ROUTE_TITLE")))
	route_box.add_child(_wrapped(tr(&"PHONE_MAP_ROUTE")))
	_content.add_child(route_card)
	for place: Dictionary in CONTENT.map_places:
		_content.add_child(_section_title(tr(place.get("name_key", &""))))
		_content.add_child(_wrapped(tr(place.get("detail_key", &"")), true))


func _draw_map(map: Control) -> void:
	var scale_factor := Vector2(map.size.x / 320.0, map.size.y / 238.0)
	map.draw_set_transform(Vector2.ZERO, 0.0, scale_factor)
	map.draw_rect(Rect2(Vector2.ZERO, Vector2(320.0, 238.0)), Color("e9edf0"), true)
	for block: Rect2 in [Rect2(14, 14, 56, 38), Rect2(108, 14, 72, 44), Rect2(214, 12, 82, 42), Rect2(18, 88, 55, 64), Rect2(174, 75, 74, 52), Rect2(262, 88, 44, 60), Rect2(148, 160, 66, 55), Rect2(236, 169, 69, 52)]:
		map.draw_style_box(_flat_box(Color("d8dde1"), 7), block)
	var roads: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(2, 65), Vector2(80, 68), Vector2(142, 57), Vector2(212, 63), Vector2(322, 66)]),
		PackedVector2Array([Vector2(3, 179), Vector2(72, 166), Vector2(131, 128), Vector2(197, 135), Vector2(322, 142)]),
		PackedVector2Array([Vector2(87, 0), Vector2(91, 63), Vector2(109, 119), Vector2(116, 239)]),
		PackedVector2Array([Vector2(251, 0), Vector2(250, 61), Vector2(235, 120), Vector2(228, 239)]),
	]
	for road: PackedVector2Array in roads:
		map.draw_polyline(road, Color("c1c8ce"), 16.0, true)
		map.draw_polyline(road, Color("ffffff"), 10.0, true)
	var route := PackedVector2Array([Vector2(47, 176), Vector2(72, 166), Vector2(109, 132), Vector2(131, 128), Vector2(197, 135), Vector2(270, 139)])
	map.draw_polyline(route, Color("3977f6"), 6.0, true)
	if not is_instance_valid(_phone) or not _phone.offline:
		for point: Vector2 in [route[0], route[route.size() - 1], Vector2(150, 105)]:
			map.draw_circle(point, 8.0, Color("ffffff"))
			map.draw_circle(point, 5.0, Color("3977f6"))
	map.draw_set_transform(Vector2.ZERO)


func _show_browser() -> void:
	_begin_page(&"browser", &"PHONE_APP_BROWSER")
	var address := _line_edit(&"PHONE_BROWSER_ADDRESS")
	address.editable = false
	address.text = tr(&"PHONE_BROWSER_LOCAL_ADDRESS")
	address.right_icon = UiIcons.tinted_icon(&"check", Color(0.35, 0.39, 0.45))
	_content.add_child(address)
	_content.add_child(_wrapped(tr(&"PHONE_BROWSER_LOCAL_NOTE"), true))
	for row: Dictionary in CONTENT.browser_pages:
		var button := _button(tr(row.get("title_key", &"")), 0.0)
		button.icon = UiIcons.icon(&"globe")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_browser_page.bind(StringName(row.get("id", &""))))
		_content.add_child(button)


func _show_browser_page(page_id: StringName) -> void:
	_page = &"browser_detail"
	_clear_content()
	var row: Dictionary = CONTENT.browser_page(page_id)
	_title.text = tr(row.get("title_key", &"PHONE_APP_BROWSER"))
	var address_row := HBoxContainer.new()
	var address := _line_edit(&"PHONE_BROWSER_ADDRESS")
	address.editable = false
	address.text = tr(row.get("address_key", &"PHONE_BROWSER_LOCAL_ADDRESS"))
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_row.add_child(address)
	var refresh := _icon_button(&"rotate-cw", tr(&"PHONE_BROWSER_REFRESH"), 42.0)
	refresh.name = "BrowserRefresh"
	refresh.pressed.connect(_refresh_browser_page.bind(page_id))
	address_row.add_child(refresh)
	_content.add_child(address_row)
	var article := PanelContainer.new()
	article.theme_type_variation = &"PhoneCard"
	var body := VBoxContainer.new()
	article.add_child(body)
	body.add_child(_section_title(tr(row.get("title_key", &""))))
	body.add_child(_wrapped(tr(row.get("body_key", &""))))
	_content.add_child(article)


func _refresh_browser_page(page_id: StringName) -> void:
	if is_instance_valid(_phone) and _phone.offline:
		set_notice(tr(&"PHONE_BROWSER_CONNECTION_FAILED"))
		return
	_show_browser_page(page_id)
	set_notice(tr(&"PHONE_BROWSER_REFRESHED"))


func _show_phone() -> void:
	_begin_page(&"phone", &"PHONE_APP_PHONE")
	var tabs := HBoxContainer.new()
	var tab_ids: Array[StringName] = [&"recents", &"contacts"]
	var tab_keys: Array[StringName] = [&"PHONE_RECENTS", &"PHONE_CONTACTS"]
	for index: int in tab_ids.size():
		var key: StringName = tab_keys[index]
		var tab := _button(tr(key), 0.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.button_pressed = _phone_tab == tab_ids[index]
		tab.pressed.connect(_set_phone_tab.bind(tab_ids[index]))
		tabs.add_child(tab)
	_content.add_child(tabs)
	if _phone_tab == &"contacts":
		for contact: Dictionary in CONTENT.contacts:
			var button := _button("%s\n%s" % [tr(contact.get("name_key", &"")), String(contact.get("number", ""))], 0.0)
			button.icon = UiIcons.icon(&"phone")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_dial)
			_content.add_child(button)
	else:
		for recent: Dictionary in CONTENT.recent_calls:
			var button := _button("%s\n%s" % [tr(recent.get("name_key", &"")), tr(recent.get("detail_key", &""))], 0.0)
			button.icon = UiIcons.icon(&"phone")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_dial)
			_content.add_child(button)


func _set_phone_tab(tab_id: StringName) -> void:
	_phone_tab = tab_id
	_show_phone()


func _on_dial() -> void:
	set_notice(tr(&"PHONE_CALL_UNAVAILABLE"))


func _show_camera() -> void:
	_begin_page(&"camera", &"PHONE_APP_CAMERA")
	_camera_preview = TextureRect.new()
	_camera_preview.custom_minimum_size = Vector2(320.0, 250.0)
	_camera_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camera_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_camera_preview.texture = _photo_texture if not _selected_photo_id.is_empty() else _camera_texture
	_content.add_child(_camera_preview)
	if _camera_preview.texture == null:
		_content.add_child(_wrapped(tr(&"PHONE_CAMERA_FILE_MISSING" if not _selected_photo_id.is_empty() else &"PHONE_CAMERA_WAITING"), true))
	_camera_capture = _button(tr(&"PHONE_CAMERA_CAPTURE"), 0.0)
	_camera_capture.icon = UiIcons.icon(&"camera")
	_camera_capture.custom_minimum_size.y = 44.0
	_camera_capture.disabled = not _has_charge()
	_camera_capture.tooltip_text = tr(&"PHONE_NO_CHARGE") if _camera_capture.disabled else ""
	_camera_capture.pressed.connect(func() -> void: capture_requested.emit())
	_content.add_child(_camera_capture)
	_content.add_child(_section_title(tr(&"PHONE_CAMERA_GALLERY")))
	if _photos.is_empty():
		_content.add_child(_wrapped(tr(&"PHONE_CAMERA_EMPTY"), true))
	for row: Dictionary in _photos:
		var seconds: int = maxi(0, roundi(float(row.get("clock_seconds", 0.0))))
		var time_text := "%02d:%02d" % [(seconds / 3600) % 24, (seconds / 60) % 60]
		var button := _button("%s · %s" % [tr(&"PHONE_CAMERA_PHOTO"), time_text], 0.0)
		button.icon = UiIcons.icon(&"image")
		_photo_buttons.append(button)
		if String(row.get("id", "")) == _selected_photo_id and _photo_texture != null:
			button.text += "  ·  %s" % tr(&"PHONE_CAMERA_SELECTED")
		else:
			button.tooltip_text = tr(&"PHONE_CAMERA_VIEW_PHOTO")
		button.pressed.connect(_select_photo.bind(String(row.get("id", ""))))
		_content.add_child(button)


func _select_photo(photo_id: String) -> void:
	_selected_photo_id = photo_id
	photo_selected.emit(photo_id)


func _has_photo(photo_id: String) -> bool:
	for row: Dictionary in _photos:
		if String(row.get("id", "")) == photo_id:
			return true
	return false


func _show_clock() -> void:
	_begin_page(&"clock", &"PHONE_APP_CLOCK")
	_clock_display = _label(_clock_text, &"PhoneTitle")
	_clock_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_display.add_theme_font_size_override(&"font_size", 48)
	_clock_display.custom_minimum_size.y = 92.0
	_content.add_child(_clock_display)
	var alarm := PanelContainer.new()
	alarm.theme_type_variation = &"PhoneCard"
	var alarm_row := HBoxContainer.new()
	alarm.add_child(alarm_row)
	var alarm_icon := TextureRect.new()
	alarm_icon.texture = UiIcons.tinted_icon(&"clock", Color(0.25, 0.31, 0.36))
	alarm_icon.custom_minimum_size = Vector2(28, 28)
	alarm_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alarm_row.add_child(alarm_icon)
	var alarm_text := VBoxContainer.new()
	alarm_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alarm_text.add_child(_section_title("07:48"))
	alarm_text.add_child(_wrapped(tr(&"PHONE_CLOCK_WEEKDAYS"), true))
	alarm_row.add_child(alarm_text)
	var state := _label(tr(&"PHONE_CLOCK_READ_ONLY"), &"PhoneMutedLabel")
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alarm_row.add_child(state)
	_content.add_child(alarm)
	_content.add_child(_wrapped(tr(&"PHONE_CLOCK_DEVICE_TIME"), true))


func _show_workspace() -> void:
	_begin_page(&"workspace", &"PHONE_APP_WORKSPACE")
	if is_instance_valid(_profile) and _profile.registered:
		_content.add_child(_section_title("%s%s" % [_profile.surname, _profile.given_name]))
		_content.add_child(_wrapped(tr(&"PHONE_WORKSPACE_EMPLOYEE") + "  " + _profile.employee_id, true))
		_content.add_child(_wrapped(tr(&"PHONE_WORKSPACE_STATUS_OK")))
	else:
		var workspace_icon := TextureRect.new()
		workspace_icon.texture = UiIcons.tinted_icon(&"briefcase-business", Color(0.24, 0.36, 0.5))
		workspace_icon.custom_minimum_size = Vector2(54, 54)
		workspace_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_content.add_child(workspace_icon)
		_content.add_child(_section_title(tr(&"PHONE_WORKSPACE_LOGIN_EXPIRED")))
		_content.add_child(_wrapped(tr(&"PHONE_WORKSPACE_EXPIRED_BODY")))
		var register := _button(tr(&"PHONE_WORKSPACE_REGISTER"), 0.0)
		register.pressed.connect(show_registration)
		_content.add_child(register)


func _show_registration_form() -> void:
	_pending_registration = false
	_title.text = tr(&"PHONE_REGISTER_TITLE")
	_clear_content()
	_content.add_child(_wrapped(tr(&"PHONE_REGISTER_NOTE"), true))
	var surname := _line_edit(&"PHONE_REGISTER_SURNAME")
	var given_name := _line_edit(&"PHONE_REGISTER_GIVEN_NAME")
	surname.text = String(_registration_draft.get("surname", ""))
	given_name.text = String(_registration_draft.get("given_name", ""))
	_content.add_child(_field(&"PHONE_REGISTER_SURNAME", surname))
	_content.add_child(_field(&"PHONE_REGISTER_GIVEN_NAME", given_name))
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override(&"separation", 5)
	var birth: Dictionary = _registration_draft.get("birth_date", {"year": 1998, "month": 6, "day": 15})
	var year := _spin(1985, 2008, int(birth.get("year", 1998)))
	var month := _spin(1, 12, int(birth.get("month", 6)))
	var day := _spin(1, 31, int(birth.get("day", 15)))
	for spin: SpinBox in [year, month, day]:
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		date_row.add_child(spin)
	_content.add_child(_section_title(tr(&"PHONE_REGISTER_BIRTHDAY")))
	_content.add_child(date_row)
	var gender := OptionButton.new()
	for key: StringName in [&"PHONE_GENDER_MALE", &"PHONE_GENDER_FEMALE", &"PHONE_GENDER_UNSPECIFIED"]:
		gender.add_item(tr(key))
	var genders: Array[StringName] = [&"male", &"female", &"unspecified"]
	gender.select(maxi(0, genders.find(StringName(_registration_draft.get("gender_id", &"unspecified")))))
	_content.add_child(_field(&"PHONE_REGISTER_GENDER", gender))
	_registration_avatar = PhoneAvatarPreview.new()
	_registration_avatar.custom_minimum_size = Vector2(320.0, 145.0)
	_content.add_child(_registration_avatar)
	var options: Dictionary = {}
	var preset: Dictionary = _registration_draft.get("appearance_preset", CharacterProfile.DEFAULT_APPEARANCE)
	for descriptor: Dictionary in [
		{"id": "skin", "key": &"PHONE_APPEARANCE_SKIN", "count": 6},
		{"id": "body", "key": &"PHONE_APPEARANCE_BODY", "count": 3},
		{"id": "hair", "key": &"PHONE_APPEARANCE_HAIR", "count": 4},
		{"id": "hair_color", "key": &"PHONE_APPEARANCE_HAIR_COLOR", "count": 4},
		{"id": "face", "key": &"PHONE_APPEARANCE_FACE", "count": 3},
	]:
		var option := OptionButton.new()
		for index: int in int(descriptor["count"]):
			option.add_item("%s %d" % [tr(&"PHONE_PRESET"), index + 1])
		option.select(clampi(int(preset.get(String(descriptor["id"]), 0)), 0, int(descriptor["count"]) - 1))
		options[String(descriptor["id"])] = option
		# Retain legacy preset values for old save compatibility. The visible
		# editor is the shared 3D character creator, not numbered preset menus.
		var legacy_field: Control = _field(StringName(descriptor["key"]), option)
		legacy_field.hide()
		_content.add_child(legacy_field)
		option.item_selected.connect(func(_index: int) -> void:
			_registration_avatar.set_appearance(_appearance_from(options))
			_cache_registration_draft(surname, given_name, year, month, day, gender, options)
		)
	_registration_options = options
	_registration_avatar.set_appearance(get_appearance_data())
	for edit: LineEdit in [surname, given_name]:
		edit.text_changed.connect(func(_text: String) -> void: _cache_registration_draft(surname, given_name, year, month, day, gender, options))
	for spin: SpinBox in [year, month, day]:
		spin.value_changed.connect(func(_value: float) -> void: _cache_registration_draft(surname, given_name, year, month, day, gender, options))
	gender.item_selected.connect(func(_index: int) -> void: _cache_registration_draft(surname, given_name, year, month, day, gender, options))
	var appearance_edit := _button(tr(&"PHONE_APPEARANCE_EDIT"), 0.0)
	appearance_edit.icon = UiIcons.icon(&"scan-face")
	appearance_edit.custom_minimum_size.y = 44.0
	appearance_edit.pressed.connect(func() -> void: appearance_edit_requested.emit())
	_content.add_child(appearance_edit)
	var submit := _button(tr(&"PHONE_REGISTER_SUBMIT"), 0.0)
	submit.custom_minimum_size.y = 44.0
	submit.pressed.connect(func() -> void:
		_cache_registration_draft(surname, given_name, year, month, day, gender, options)
		var submission := {
			"surname": surname.text.strip_edges(),
			"given_name": given_name.text.strip_edges(),
			"birth_date": {"year": roundi(year.value), "month": roundi(month.value), "day": roundi(day.value)},
			"gender_id": [&"male", &"female", &"unspecified"][gender.selected],
			"appearance_preset": _appearance_from(options),
			"appearance": get_appearance_data(),
		}
		profile_submitted.emit(submission)
	)
	_fixed_content.add_child(submit)


func _appearance_from(options: Dictionary) -> Dictionary:
	return {
		"skin": (options.get("skin") as OptionButton).selected,
		"body": (options.get("body") as OptionButton).selected,
		"hair": (options.get("hair") as OptionButton).selected,
		"hair_color": (options.get("hair_color") as OptionButton).selected,
		"face": (options.get("face") as OptionButton).selected,
	}


func _cache_registration_draft(surname: LineEdit, given_name: LineEdit, year: SpinBox, month: SpinBox, day: SpinBox, gender: OptionButton, options: Dictionary) -> void:
	_registration_draft = {
		"surname": surname.text,
		"given_name": given_name.text,
		"birth_date": {"year": roundi(year.value), "month": roundi(month.value), "day": roundi(day.value)},
		"gender_id": [&"male", &"female", &"unspecified"][gender.selected],
		"appearance_preset": _appearance_from(options),
	}


func _begin_page(page: StringName, title_key: StringName) -> void:
	_refresh_status()
	_page = page
	_title.text = tr(title_key)
	_clear_content()
	set_notice("")


func _clear_content() -> void:
	_clock_display = null
	_chat_send = null
	_camera_capture = null
	_camera_preview = null
	_registration_avatar = null
	_registration_options = {}
	_photo_buttons.clear()
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for child: Node in _fixed_content.get_children():
		_fixed_content.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0


func _on_back() -> void:
	if _page == &"home":
		close_requested.emit()
	elif _page == &"browser_detail":
		_show_browser()
	elif _page == &"chat_detail":
		_show_chat()
	elif _page == &"registration":
		_show_workspace()
	else:
		_show_home()


func _on_phone_changed() -> void:
	_refresh_status()
	if _page == &"chat":
		_show_chat()
	elif _page == &"chat_detail":
		_show_chat_detail(_chat_conversation)
	elif _page == &"maps":
		_show_maps()


func _refresh_status() -> void:
	if not is_instance_valid(_status_charge):
		return
	var percent: int = 0
	if is_instance_valid(_charge) and _charge.maximum > 0.0:
		percent = roundi(_charge.current / _charge.maximum * 100.0)
	_status_charge.text = "%d%%" % clampi(percent, 0, 100)
	_status_network.text = tr(&"PHONE_STATUS_OFFLINE") if is_instance_valid(_phone) and _phone.offline else tr(&"PHONE_STATUS_LOCAL")


func _has_charge() -> bool:
	return is_instance_valid(_charge) and _charge.current > 0.0


func _label(text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _wrapped(text: String, muted: bool = false) -> Label:
	var label := _label(text, &"PhoneMutedLabel" if muted else &"")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _section_title(text: String) -> Label:
	var label := _label(text, &"PhoneTitle")
	label.add_theme_font_size_override(&"font_size", 18)
	return label


func _button(text: String, minimum_width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(minimum_width, 38.0)
	button.focus_mode = Control.FOCUS_ALL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


func _icon_button(icon_id: StringName, tooltip: String, minimum_width: float) -> Button:
	var button := _button("", minimum_width)
	button.icon = UiIcons.icon(icon_id)
	button.expand_icon = true
	button.tooltip_text = tooltip
	return button


func _style_system_nav_button(button: Button) -> void:
	for style_name: StringName in [&"normal", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(style_name, _flat_box(Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override(&"hover", _flat_box(Color(1, 1, 1, 0.08), 8))
	button.add_theme_stylebox_override(&"pressed", _flat_box(Color(1, 1, 1, 0.14), 8))
	for color_name: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.94, 0.96, 0.98))


func _app_button(app_id: StringName, label_text: String, color: Color) -> Button:
	var button := _button("", 0.0)
	button.custom_minimum_size = Vector2(72.0, 96.0)
	button.add_theme_stylebox_override(&"normal", _flat_box(Color.TRANSPARENT, 12))
	button.add_theme_stylebox_override(&"hover", _flat_box(Color(0.1, 0.16, 0.22, 0.06), 12))
	button.add_theme_stylebox_override(&"pressed", _flat_box(Color(0.1, 0.16, 0.22, 0.12), 12))
	button.tooltip_text = label_text
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(62, 62)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override(&"panel", _flat_box(color, 17))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tile)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiIcons.icon(app_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	var label := _label(label_text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	return button

func _avatar_letter(display_name: String) -> PanelContainer:
	var avatar := PanelContainer.new()
	avatar.theme_type_variation = &"PhoneAvatar"
	avatar.custom_minimum_size = Vector2(38, 38)
	var initial := _label(display_name.left(1), &"PhoneAvatarLabel")
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	return avatar


func _chat_bubble(text: String, outgoing: bool) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.theme_type_variation = &"PhoneBubbleOutgoing" if outgoing else &"PhoneBubbleIncoming"
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if outgoing else Control.SIZE_SHRINK_BEGIN
	bubble.custom_minimum_size.x = 208.0
	bubble.add_child(_wrapped(text, false))
	return bubble


func _flat_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_right = radius
	box.corner_radius_bottom_left = radius
	return box


func _line_edit(placeholder_key: StringName) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = tr(placeholder_key)
	edit.max_length = 20
	edit.custom_minimum_size.y = 38.0
	return edit


func _field(label_key: StringName, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.add_child(_label(tr(label_key), &"PhoneMutedLabel"))
	box.add_child(control)
	return box


func _spin(minimum: int, maximum: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.custom_minimum_size.y = 38.0
	return spin

