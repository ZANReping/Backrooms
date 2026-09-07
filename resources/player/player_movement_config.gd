class_name PlayerMovementConfig
extends Resource

@export_group("Speed")
@export var walk_speed: float = 3.6
@export var sprint_speed: float = 5.8
@export var crouch_speed: float = 1.8
@export var ground_acceleration: float = 18.0
@export var ground_deceleration: float = 22.0
@export var air_acceleration: float = 4.0

@export_group("Vertical")
@export var gravity: float = 18.0
@export var jump_velocity: float = 3.8
@export var fall_out_y: float = -40.0

@export_group("View")
@export var mouse_sensitivity: float = 0.002
@export_range(30.0, 89.0, 1.0) var pitch_limit_degrees: float = 82.0
@export var standing_camera_height: float = 1.62
@export var crouching_camera_height: float = 1.12
@export var crouch_transition_speed: float = 7.0
@export var headbob_frequency: float = 8.0
@export var headbob_horizontal_amplitude: float = 0.012
@export var headbob_vertical_amplitude: float = 0.018

@export_group("Body")
@export var standing_capsule_height: float = 1.8
@export var crouching_capsule_height: float = 1.2
@export var capsule_radius: float = 0.34
@export var step_distance: float = 1.8
@export var sprint_resume_stamina: float = 15.0
@export_range(0.1, 1.0, 0.05) var overloaded_speed_multiplier: float = 0.55
