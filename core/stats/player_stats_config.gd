class_name PlayerStatsConfig
extends Resource

@export_group("Stamina")
@export var sprint_drain_per_second: float = 14.0
@export var high_stamina_threshold_ratio: float = 0.85
@export var high_stamina_drain_multiplier: float = 1.25
@export var recovery_per_second: float = 9.0
@export var reduced_recovery_min_ratio: float = 0.60
@export var reduced_recovery_max_ratio: float = 0.85
@export var reduced_recovery_multiplier: float = 0.7
@export var overload_drain_multiplier_per_ratio: float = 1.0

@export_group("Survival")
@export var hunger_drain_per_second: float = 0.015
@export var thirst_drain_per_second: float = 0.04
@export var fatigue_gain_per_second: float = 0.01
