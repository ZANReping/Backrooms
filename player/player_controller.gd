class_name PlayerController
extends CharacterBody3D

signal stepped(surface_id: StringName)
signal fell_out_of_world

@export var config: PlayerMovementConfig
@export var input_enabled: bool = false
var look_enabled: bool = false
var look_sensitivity_multiplier: float = 1.0
var invert_look_y: bool = false
@export var headbob_enabled: bool = true
@export var load_ratio: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var interaction_origin: Node3D = $CameraPivot/Camera3D/InteractionOrigin
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var stand_clearance: ShapeCast3D = $StandClearance
@onready var interaction_animation: AnimationPlayer = $BodyVisual/InteractionAnimation
@onready var player_audio: PlayerAudio = $PlayerAudio
@onready var primary_hand_mount: Node3D = $BodyVisual/RightArm/RightHand
@onready var secondary_hand_mount: Node3D = $BodyVisual/LeftArm/LeftHand
@onready var back_mount: Node3D = $BodyVisual/EquipmentMounts/Back

var stats: PlayerStats
var human_visual: HumanCharacter
var _pitch: float = 0.0
var _yaw: float = 0.0
var _is_crouching: bool = false
var _bob_time: float = 0.0
var _distance_since_step: float = 0.0
var _fall_signal_emitted: bool = false
var _sprint_ready: bool = true
var scripted_locomotion_speed: float = -1.0

func _ready() -> void:
	look_enabled = input_enabled
	if config == null:
		config = PlayerMovementConfig.new()
	else:
		config = config.duplicate(true)
	_yaw = rotation.y
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate(true)
	stand_clearance.add_exception(self)
	_apply_capsule_height(config.standing_capsule_height)
	camera_pivot.position.y = config.standing_camera_height
	if not stepped.is_connected(player_audio.play_step):
		stepped.connect(player_audio.play_step)

func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)

func apply_look(relative: Vector2) -> void:
	var sensitivity: float = config.mouse_sensitivity * look_sensitivity_multiplier
	_yaw -= relative.x * sensitivity
	_pitch = clampf(_pitch - relative.y * sensitivity * (-1.0 if invert_look_y else 1.0), -deg_to_rad(config.pitch_limit_degrees), deg_to_rad(config.pitch_limit_degrees))
	rotation.y = _yaw
	camera_pivot.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	_update_human(delta)
	if global_position.y < config.fall_out_y:
		if not _fall_signal_emitted:
			_fall_signal_emitted = true
			fell_out_of_world.emit()
	else:
		_fall_signal_emitted = false
	if not input_enabled:
		if scripted_locomotion_speed >= 0.0:
			velocity = Vector3.ZERO
			_update_headbob(delta, scripted_locomotion_speed > 0.02)
		else:
			reset_motion()
		return
	var wants_crouch := Input.is_action_pressed(&"crouch")
	if not wants_crouch and _is_crouching and stand_clearance.is_colliding():
		wants_crouch = true
	_set_crouching(wants_crouch, delta)
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := (global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var sprint_requested := Input.is_action_pressed(&"sprint") and not _is_crouching and direction != Vector3.ZERO
	var sprinting := sprint_requested and _sprint_ready and load_ratio <= 1.0
	if stats != null:
		if stats.get_value(&"stamina") <= 0.0:
			_sprint_ready = false
		elif stats.get_value(&"stamina") >= config.sprint_resume_stamina:
			_sprint_ready = true
		sprinting = sprinting and stats.get_value(&"stamina") > 0.0
		stats.tick(delta, sprinting, load_ratio)
	var speed := config.crouch_speed if _is_crouching else (config.sprint_speed if sprinting else config.walk_speed)
	if load_ratio > 1.0:
		speed *= config.overloaded_speed_multiplier
	var acceleration := config.ground_acceleration if is_on_floor() else config.air_acceleration
	var target := direction * speed
	if direction == Vector3.ZERO and is_on_floor():
		acceleration = config.ground_deceleration
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_on_floor():
		if Input.is_action_just_pressed(&"jump") and not _is_crouching:
			velocity.y = config.jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= config.gravity * delta
	var previous_position := global_position
	move_and_slide()
	_update_steps(previous_position, direction)
	_update_headbob(delta, direction != Vector3.ZERO and is_on_floor())


func _update_human(delta: float) -> void:
	if not is_instance_valid(human_visual):
		return
	var visual_speed: float = scripted_locomotion_speed if scripted_locomotion_speed >= 0.0 else (Vector2(velocity.x, velocity.z).length() if input_enabled else 0.0)
	human_visual.set_locomotion(visual_speed, _is_crouching, delta)
	for pair: Array in [[&"hand_right", primary_hand_mount], [&"hand_left", secondary_hand_mount], [&"back", back_mount]]:
		var socket: Node3D = human_visual.get_socket(pair[0])
		var mount: Node3D = pair[1]
		if socket != null:
			mount.global_transform = socket.global_transform

func bind_stats(value: PlayerStats) -> void:
	stats = value

func set_control_enabled(enabled: bool) -> void:
	input_enabled = enabled
	look_enabled = enabled
	if not enabled:
		reset_motion()

func get_save_transform() -> Transform3D:
	return global_transform

func restore_transform(value: Transform3D) -> void:
	global_transform = value
	_yaw = global_transform.basis.get_euler().y
	_pitch = 0.0
	rotation.y = _yaw
	camera_pivot.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	reset_motion()
	_fall_signal_emitted = false

func play_interaction() -> void:
	if is_instance_valid(human_visual):
		human_visual.play_interaction()
	if interaction_animation.has_animation(&"interact"):
		interaction_animation.stop()
		interaction_animation.play(&"interact")

func reset_motion() -> void:
	velocity = Vector3.ZERO
	_bob_time = 0.0
	camera.position = camera.position.lerp(Vector3.ZERO, 0.35)

func _set_crouching(crouching: bool, delta: float) -> void:
	_is_crouching = crouching
	var capsule_height := config.crouching_capsule_height if crouching else config.standing_capsule_height
	_apply_capsule_height(capsule_height)
	var camera_height := config.crouching_camera_height if crouching else config.standing_camera_height
	camera_pivot.position.y = move_toward(camera_pivot.position.y, camera_height, config.crouch_transition_speed * delta)

func _apply_capsule_height(height: float) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null:
		capsule.height = height
		capsule.radius = config.capsule_radius
		collision_shape.position.y = height * 0.5

func _update_headbob(delta: float, moving: bool) -> void:
	var target := Vector3.ZERO
	if moving and headbob_enabled:
		_bob_time += delta * config.headbob_frequency
		target.x = cos(_bob_time * 0.5) * config.headbob_horizontal_amplitude
		target.y = sin(_bob_time) * config.headbob_vertical_amplitude
	else:
		_bob_time = 0.0
	camera.position = camera.position.lerp(target, clampf(delta * 10.0, 0.0, 1.0))

func _update_steps(previous_position: Vector3, moving_direction: Vector3) -> void:
	if not is_on_floor() or moving_direction == Vector3.ZERO:
		return
	var traveled := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z).length()
	_distance_since_step += traveled
	if _distance_since_step < config.step_distance:
		return
	_distance_since_step = 0.0
	var surface_id: StringName = &"default"
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().dot(Vector3.UP) < 0.7:
			continue
		var collider := collision.get_collider()
		if collider is Object:
			var metadata: Variant = collider.get_meta(&"surface_id", &"default")
			if metadata is StringName:
				surface_id = metadata
			elif metadata is String:
				surface_id = StringName(metadata)
		break
	stepped.emit(surface_id)
