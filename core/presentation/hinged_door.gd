class_name HingedDoor
extends Node3D

signal motion_finished(open: bool)

@export var pivot_path: NodePath = ^"Pivot"
@export var handle_path: NodePath
@export_range(-179.0, 179.0, 0.1) var open_angle: float = 90.0
@export_range(0.05, 5.0, 0.01) var duration: float = 0.55

var _pivot: Node3D
var _handle: Node3D
var _closed_pivot_rotation: Vector3
var _closed_handle_rotation: Vector3
var _open := false
var _moving := false
var _motion: Tween
var _initialized := false


func _ready() -> void:
	_initialize_nodes()


func set_open(open: bool, instant: bool = false) -> void:
	_initialize_nodes()
	if _pivot == null:
		push_error("HingedDoor requires a valid pivot_path")
		return
	if not instant and open == _open:
		return
	if is_instance_valid(_motion):
		_motion.kill()
		_motion = null
	_open = open
	var target_rotation := _closed_pivot_rotation
	target_rotation.y += deg_to_rad(open_angle) if open else 0.0
	if instant:
		_pivot.rotation = target_rotation
		if _handle != null:
			_handle.rotation = _closed_handle_rotation
		_moving = false
		motion_finished.emit(_open)
		return
	_moving = true
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if open and _handle != null:
		var pressed := _closed_handle_rotation
		pressed.x -= deg_to_rad(24.0)
		_motion.tween_property(_handle, ^"rotation", pressed, duration * 0.18)
		_motion.tween_property(_handle, ^"rotation", _closed_handle_rotation, duration * 0.14)
	_motion.tween_property(_pivot, ^"rotation", target_rotation, duration * (0.68 if open and _handle != null else 1.0))
	_motion.finished.connect(_finish_motion.bind(open))


func is_open() -> bool:
	return _open


func is_moving() -> bool:
	return _moving


func _initialize_nodes() -> void:
	if _initialized:
		return
	_initialized = true
	_pivot = get_node_or_null(pivot_path) as Node3D
	_handle = get_node_or_null(handle_path) as Node3D if not handle_path.is_empty() else null
	if _pivot != null:
		_closed_pivot_rotation = _pivot.rotation
	if _handle != null:
		_closed_handle_rotation = _handle.rotation


func _finish_motion(expected_open: bool) -> void:
	if expected_open != _open:
		return
	_moving = false
	_motion = null
	motion_finished.emit(_open)


func _exit_tree() -> void:
	if is_instance_valid(_motion):
		_motion.kill()
	_motion = null
	_moving = false
