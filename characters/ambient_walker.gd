class_name AmbientWalker
extends CharacterBody3D

## Small authored-route controller for background humans. Waypoints are local
## offsets from the spawn position so a whole route can be moved with the node.
@export var active: bool = true
@export_range(0.75, 1.1, 0.01) var walk_speed: float = 0.9
@export var local_waypoints: PackedVector3Array = PackedVector3Array()
@export var loop_route: bool = false
@export_range(0, 64, 1) var start_waypoint: int = 0
@export_range(0.0, 8.0, 0.05) var initial_wait_seconds: float = 0.0
@export_range(0.0, 4.0, 0.05) var waypoint_wait_seconds: float = 0.7
@export_range(0.1, 8.0, 0.1) var acceleration: float = 2.4
@export_range(0.1, 8.0, 0.1) var deceleration: float = 3.2
@export_range(0.1, 10.0, 0.1) var turn_speed: float = 4.0
@export_range(0.05, 1.0, 0.01) var arrival_radius: float = 0.12
@export_range(0.2, 3.0, 0.05) var slowdown_distance: float = 0.9

var current_speed: float = 0.0
var actual_speed: float = 0.0
var waypoint_index: int = 0
var route_direction: int = 1
var waiting_seconds: float = 0.0

var _route_origin: Vector3
var _human: HumanCharacter


func _init() -> void:
	collision_layer = 8
	collision_mask = 11


func _ready() -> void:
	_route_origin = global_position
	waypoint_index = clampi(start_waypoint, 0, maxi(0, local_waypoints.size() - 1))
	waiting_seconds = initial_wait_seconds
	for child: Node in get_children():
		if child is HumanCharacter:
			_human = child as HumanCharacter
			break


func _physics_process(delta: float) -> void:
	if not _movement_allowed() or local_waypoints.is_empty():
		_stop(delta)
		return

	if waiting_seconds > 0.0:
		waiting_seconds = maxf(0.0, waiting_seconds - delta)
		_stop(delta)
		return

	var target := _route_origin + local_waypoints[waypoint_index]
	var to_target := target - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= arrival_radius:
		current_speed = 0.0
		actual_speed = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		_advance_waypoint()
		waiting_seconds = waypoint_wait_seconds
		_update_locomotion(delta)
		return

	var direction := to_target / distance
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	# Turn before accelerating at a route reversal, instead of walking backwards.
	var facing: float = maxf(0.0, (-global_basis.z).dot(direction))
	var target_speed := walk_speed * clampf(distance / slowdown_distance, 0.18, 1.0) * smoothstep(0.85, 0.99, facing)
	var rate := acceleration if target_speed >= current_speed else deceleration
	current_speed = move_toward(current_speed, target_speed, rate * delta)
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 18.0 * delta

	var previous := global_position
	move_and_slide()
	var displacement := global_position - previous
	displacement.y = 0.0
	actual_speed = displacement.length() / maxf(delta, 0.0001)
	_update_locomotion(delta)


func _movement_allowed() -> bool:
	if not active or get_tree().paused:
		return false
	var game_state := get_node_or_null("/root/GameState")
	return game_state == null or game_state.get("mode") in [&"play", &"phone", &"camera", &"inventory"]


func _stop(delta: float) -> void:
	current_speed = 0.0
	actual_speed = 0.0
	velocity = Vector3.ZERO
	_update_locomotion(delta)


func _advance_waypoint() -> void:
	if local_waypoints.size() < 2:
		return
	if loop_route:
		waypoint_index = wrapi(waypoint_index + 1, 0, local_waypoints.size())
		return
	if waypoint_index == local_waypoints.size() - 1:
		route_direction = -1
	elif waypoint_index == 0:
		route_direction = 1
	waypoint_index += route_direction


func _update_locomotion(delta: float) -> void:
	if is_instance_valid(_human):
		_human.set_locomotion(actual_speed, false, delta)
