class_name PlayerTraversal
extends Node

## Short authored first-person movement, swept through the normal player shape.
## The caller owns modal state and scene transitions; this component only moves.
var player: PlayerController
var _generation: int = 0
var _step_distance: float = 0.0


func cancel() -> void:
	_generation += 1
	if is_instance_valid(player):
		player.scripted_locomotion_speed = -1.0


func align_view() -> void:
	var forward: Vector3 = -player.camera.global_basis.z
	var transform: Transform3D = player.global_transform
	transform.basis = Basis.from_euler(Vector3(0, atan2(-forward.x, -forward.z), 0))
	player.restore_transform(transform)
	player.apply_look(Vector2(0, -asin(clampf(forward.y, -1.0, 1.0)) / player.config.mouse_sensitivity))


func turn_towards(target: Vector3, duration: float = 0.35) -> bool:
	var generation: int = _generation
	var direction: Vector3 = target - player.global_position
	var yaw: float = atan2(-direction.x, -direction.z)
	var remaining: float = duration
	while remaining > 0.0 and generation == _generation and is_inside_tree():
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		var fraction: float = minf(1.0, delta / maxf(delta, remaining))
		var difference: float = wrapf(yaw - player.rotation.y, -PI, PI)
		player.apply_look(Vector2(-difference, player.camera_pivot.rotation.x) * fraction / player.config.mouse_sensitivity)
		remaining -= delta
	return generation == _generation


func walk_to(target: Vector3, speed: float = 1.15) -> bool:
	var generation: int = _generation
	var seconds: float = 0.0
	var current_speed: float = 0.0
	var blocked_seconds: float = 0.0
	while seconds < 8.0 and generation == _generation and is_inside_tree():
		await get_tree().physics_frame
		var direction: Vector3 = target - player.global_position
		direction.y = 0.0
		var distance: float = direction.length()
		if distance < 0.035:
			player.scripted_locomotion_speed = 0.0
			return true
		var delta: float = get_physics_process_delta_time()
		seconds += delta
		current_speed = move_toward(current_speed, minf(speed, maxf(0.15, distance * 2.8)), delta * 3.0)
		var before: Vector3 = player.global_position
		player.move_and_collide(direction.normalized() * minf(distance, current_speed * delta))
		var moved: float = player.global_position.distance_to(before)
		player.scripted_locomotion_speed = moved / maxf(delta, 0.0001)
		blocked_seconds = blocked_seconds + delta if moved < 0.0005 else 0.0
		_step_distance += moved
		if _step_distance >= 0.53:
			_step_distance = 0.0
			player.stepped.emit(&"concrete")
		if blocked_seconds > 0.65:
			break
	player.scripted_locomotion_speed = -1.0
	return false
