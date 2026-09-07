class_name HumanCharacter
extends Node3D

## Gameplay-facing human. Backend resources never enter the session/save model.
@export var appearance: CharacterAppearance
@export var first_person: bool = false
@export var npc_seed: int = 0
var backend: CharacterBackend


func _ready() -> void:
	if appearance == null:
		appearance = AppearanceGenerator.generate(npc_seed, preload("res://characters/resources/civilian_profile.tres")) if npc_seed != 0 else CharacterAppearance.new()
	backend = load("res://characters/backends/gd_human_backend.gd").new() as CharacterBackend
	backend.name = "Backend"
	add_child(backend)
	backend.apply_appearance(appearance)
	backend.set_first_person(first_person)


func apply_appearance(value: CharacterAppearance) -> void:
	if value == null:
		return
	appearance = value.copy()
	if is_instance_valid(backend):
		backend.apply_appearance(appearance)


func get_socket(id: StringName) -> Node3D:
	return backend.get_socket(id) if is_instance_valid(backend) else null


func set_first_person(enabled: bool) -> void:
	first_person = enabled
	if is_instance_valid(backend):
		backend.set_first_person(enabled)


func set_locomotion(speed: float, crouched: bool, delta: float) -> void:
	if is_instance_valid(backend):
		backend.set_locomotion(speed, crouched, delta)


func play_interaction() -> void:
	if is_instance_valid(backend):
		backend.play_interaction()
