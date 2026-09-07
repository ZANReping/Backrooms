class_name PhoneAvatarPreview
extends Control

var appearance: Dictionary = {}
var _viewport: SubViewport
var _picture: TextureRect
var _human: HumanCharacter

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 220)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d7dce0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.5
	world.environment = environment
	_viewport.add_child(world)
	var light := OmniLight3D.new()
	light.position = Vector3(-1, 2.5, -1.5)
	light.light_energy = 1.8
	_viewport.add_child(light)
	_human = HumanCharacter.new()
	_viewport.add_child(_human)
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	camera.position = Vector3(0, 1.52, -0.9)
	camera.look_at(Vector3(0, 1.52, 0), Vector3.UP)
	camera.fov = 28.0
	_picture = TextureRect.new()
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture = _viewport.get_texture()
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	set_appearance(appearance)

func set_appearance(value: Dictionary) -> void:
	appearance = value.duplicate(true)
	if _human == null:
		return
	var draft := CharacterAppearance.new()
	if not draft.load_data(value):
		draft = CharacterAppearance.from_legacy(value)
	_human.apply_appearance(draft)
	_refresh.call_deferred()

func _refresh() -> void:
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _exit_tree() -> void:
	if _picture != null:
		_picture.texture = null
	if _viewport != null:
		_viewport.world_3d = null
