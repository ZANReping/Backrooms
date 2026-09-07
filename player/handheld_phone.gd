class_name HandheldPhone
extends Node3D

const PHONE_SCENE_PATH: String = "res://art/prologue/props/phone.tscn"
const PHONE_LAYER: int = 1 << 19
const SCREEN_VIEWPORT_SIZE := Vector2i(360, 640)
const CAMERA_VIEWPORT_SIZE := Vector2i(640, 480)
const SCREEN_SIZE := Vector2(0.075375, 0.134)
const SHOWN_POSITION := Vector3(0.05, -0.012, -0.29)
const HIDDEN_POSITION := Vector3(0.09, -0.115, -0.21)
const SHOWN_ROTATION := Vector3(deg_to_rad(2.0), deg_to_rad(-2.0), deg_to_rad(1.0))
const TRANSITION_SECONDS: float = 0.2

var view: DiegeticPhoneView
var camera_viewport: SubViewport

var _main_camera: Camera3D
var _capture_camera: Camera3D
var _screen_viewport: SubViewport
var _screen_mesh: MeshInstance3D
var _screen_material: StandardMaterial3D
var _phone_model: Node3D
var _transition: Tween
var _original_fov: float = 75.0
var _shown: bool = false
var _capture_elapsed: float = 0.0


func configure(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or is_instance_valid(_main_camera):
		return
	if is_inside_tree() and get_parent() != camera:
		reparent(camera, false)
	# Reparenting emits _exit_tree; acquire dependencies after that boundary.
	_main_camera = camera
	_original_fov = camera.fov
	_build_screen_viewport()
	_build_camera_viewport()
	_build_physical_phone()
	position = HIDDEN_POSITION
	rotation = SHOWN_ROTATION + Vector3(deg_to_rad(5.0), 0.0, deg_to_rad(3.0))
	scale = Vector3.ONE * 0.94
	visible = false
	set_process(true)
	set_process_unhandled_input(true)


func show_phone(phone: PhoneState, charge: ChargeState, profile: CharacterProfile) -> void:
	if not is_instance_valid(_main_camera):
		return
	_shown = true
	visible = true
	_apply_hand_skin(profile)
	view.bind_state(phone, charge, profile)
	_screen_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_start_transition(true)


func hide_phone() -> void:
	if not is_instance_valid(_main_camera):
		visible = false
		return
	if not _shown and not visible:
		return
	_shown = false
	_screen_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_start_transition(false)


func set_world_fov(value: float) -> void:
	_original_fov = value
	if not is_instance_valid(_main_camera):
		return
	if _transition != null and _transition.is_running():
		_start_transition(_shown)
	else:
		_main_camera.fov = 36.0 if _shown else _original_fov


func capture_image(target_size: Vector2i = CAMERA_VIEWPORT_SIZE) -> Image:
	if not is_instance_valid(camera_viewport):
		return null
	if DisplayServer.get_name() == "headless":
		return null
	var ratio: float = minf(1.0, 1280.0 / maxf(target_size.x, target_size.y))
	camera_viewport.size = Vector2i(maxi(16, int(target_size.x * ratio)), maxi(16, int(target_size.y * ratio)))
	_capture_camera.fov = _main_camera.fov if target_size != CAMERA_VIEWPORT_SIZE else 60.0
	_sync_capture_camera()
	camera_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image: Image = camera_viewport.get_texture().get_image()
	return image


func _process(delta: float) -> void:
	if not _shown or not is_instance_valid(camera_viewport):
		return
	_capture_elapsed += delta
	if _capture_elapsed < 0.2:
		return
	_capture_elapsed = 0.0
	if is_instance_valid(view):
		view.refresh_charge()
	if is_instance_valid(view) and StringName(view.get("_page")) == &"camera":
		_sync_capture_camera()
		camera_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _unhandled_input(event: InputEvent) -> void:
	if not _shown or not visible or not is_instance_valid(_screen_viewport):
		return
	var game_state: Node = get_tree().root.get_node_or_null("GameState")
	if game_state == null or StringName(game_state.get("mode")) != &"phone":
		return
	if event is InputEventKey:
		_screen_viewport.push_input(event.duplicate(), true)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	var local_position: Variant = _event_to_screen_position(event.position)
	if not local_position is Vector2:
		return
	var forwarded: InputEvent = event.duplicate()
	forwarded.position = local_position
	forwarded.global_position = local_position
	_screen_viewport.push_input(forwarded, true)
	get_viewport().set_input_as_handled()


func _build_screen_viewport() -> void:
	_screen_viewport = SubViewport.new()
	_screen_viewport.name = "PhoneScreenViewport"
	_screen_viewport.size = SCREEN_VIEWPORT_SIZE
	_screen_viewport.transparent_bg = false
	_screen_viewport.gui_disable_input = false
	_screen_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_screen_viewport)
	var scene: PackedScene = load("res://ui/phone/diegetic_phone_view.tscn")
	view = scene.instantiate() as DiegeticPhoneView
	_screen_viewport.add_child(view)


func _build_camera_viewport() -> void:
	camera_viewport = SubViewport.new()
	camera_viewport.name = "PhoneCameraViewport"
	camera_viewport.size = CAMERA_VIEWPORT_SIZE
	camera_viewport.transparent_bg = false
	camera_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera_viewport.world_3d = _main_camera.get_world_3d()
	add_child(camera_viewport)
	_capture_camera = Camera3D.new()
	_capture_camera.name = "CaptureCamera"
	_capture_camera.fov = 60.0
	_capture_camera.cull_mask = 1
	_capture_camera.current = true
	camera_viewport.add_child(_capture_camera)
	view.set_camera_texture(camera_viewport.get_texture())


func _build_physical_phone() -> void:
	if ResourceLoader.exists(PHONE_SCENE_PATH, "PackedScene"):
		var packed := load(PHONE_SCENE_PATH) as PackedScene
		if packed != null:
			_phone_model = packed.instantiate() as Node3D
	if not is_instance_valid(_phone_model):
		_phone_model = Node3D.new()
		_phone_model.name = "PhoneModelMissing"
	add_child(_phone_model)
	var old_screen := _phone_model.get_node_or_null("DynamicScreenArea") as GeometryInstance3D
	if old_screen != null:
		old_screen.visible = false
	_set_render_layer_recursive(_phone_model)

	_screen_mesh = MeshInstance3D.new()
	_screen_mesh.name = "InteractiveScreen"
	_screen_mesh.position = Vector3(0.0, 0.002, 0.0057)
	_screen_mesh.layers = PHONE_LAYER
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	quad.orientation = PlaneMesh.FACE_Z
	_screen_mesh.mesh = quad
	_screen_material = StandardMaterial3D.new()
	_screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen_material.albedo_texture = _screen_viewport.get_texture()
	_screen_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_screen_material.cull_mode = BaseMaterial3D.CULL_BACK
	_screen_mesh.material_override = _screen_material
	add_child(_screen_mesh)
	_build_hand()


func _build_hand() -> void:
	var hand := SkinnedPhoneHand.new()
	hand.name = "HoldingHand"
	add_child(hand)


func _apply_hand_skin(profile: CharacterProfile) -> void:
	var hand := get_node_or_null("HoldingHand") as SkinnedPhoneHand
	if hand != null and profile != null:
		hand.apply_appearance(profile.appearance)

func _set_render_layer_recursive(node: Node) -> void:
	var geometry := node as GeometryInstance3D
	if geometry != null:
		geometry.layers = PHONE_LAYER
	for child: Node in node.get_children():
		_set_render_layer_recursive(child)


func _start_transition(showing: bool) -> void:
	if is_instance_valid(_transition):
		_transition.kill()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if showing else Tween.EASE_IN)
	_transition.tween_property(self, ^"position", SHOWN_POSITION if showing else HIDDEN_POSITION, TRANSITION_SECONDS)
	_transition.tween_property(self, ^"rotation", SHOWN_ROTATION if showing else SHOWN_ROTATION + Vector3(deg_to_rad(5.0), 0.0, deg_to_rad(3.0)), TRANSITION_SECONDS)
	_transition.tween_property(self, ^"scale", Vector3.ONE if showing else Vector3.ONE * 0.94, TRANSITION_SECONDS)
	_transition.tween_property(_main_camera, ^"fov", clampf(36.0, 33.0, 38.0) if showing else _original_fov, TRANSITION_SECONDS)
	if not showing:
		_transition.chain().tween_callback(_finish_hiding)


func _finish_hiding() -> void:
	if not _shown:
		visible = false


func _sync_capture_camera() -> void:
	if is_instance_valid(_capture_camera) and is_instance_valid(_main_camera):
		_capture_camera.global_transform = _main_camera.global_transform


func _event_to_screen_position(viewport_position: Vector2) -> Variant:
	if not is_instance_valid(_main_camera) or not is_instance_valid(_screen_mesh):
		return null
	var origin: Vector3 = _main_camera.project_ray_origin(viewport_position)
	var direction: Vector3 = _main_camera.project_ray_normal(viewport_position)
	var normal: Vector3 = _screen_mesh.global_basis.z.normalized()
	var denominator: float = direction.dot(normal)
	if absf(denominator) < 0.00001:
		return null
	var distance: float = (_screen_mesh.global_position - origin).dot(normal) / denominator
	if distance <= 0.0:
		return null
	var local: Vector3 = _screen_mesh.to_local(origin + direction * distance)
	if absf(local.x) > SCREEN_SIZE.x * 0.5 or absf(local.y) > SCREEN_SIZE.y * 0.5:
		return null
	return Vector2(
		(local.x / SCREEN_SIZE.x + 0.5) * SCREEN_VIEWPORT_SIZE.x,
		(0.5 - local.y / SCREEN_SIZE.y) * SCREEN_VIEWPORT_SIZE.y
	)


func _exit_tree() -> void:
	if is_instance_valid(_transition):
		_transition.kill()
	if is_instance_valid(view):
		view.clear_external_textures()
	if is_instance_valid(_screen_material):
		_screen_material.albedo_texture = null
	if is_instance_valid(_screen_mesh):
		_screen_mesh.material_override = null
	if is_instance_valid(_screen_viewport):
		_screen_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(camera_viewport):
		camera_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		camera_viewport.world_3d = null
	view = null
	_capture_camera = null
	_screen_material = null
	_screen_mesh = null
	_screen_viewport = null
	camera_viewport = null
	_phone_model = null
	_main_camera = null
