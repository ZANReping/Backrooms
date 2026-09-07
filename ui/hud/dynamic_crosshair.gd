class_name DynamicCrosshair
extends Control

var movement_speed: float = 0.0
var focused: bool = false
var _radius: float = 1.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	visible = Settings.dynamic_crosshair
	_radius = lerpf(_radius, 2.8 if focused else 1.4 + minf(movement_speed, 5.0) * 0.35, 1.0 - exp(-12.0 * delta))
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, _radius + 1.0, Color(0, 0, 0, 0.38))
	if focused:
		draw_arc(center, _radius, 0.0, TAU, 20, Color(0.86, 0.84, 0.74, 0.85), 1.0, true)
	else:
		draw_circle(center, _radius, Color(0.88, 0.86, 0.81, 0.55))
