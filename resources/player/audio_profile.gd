class_name AudioProfile
extends Resource

@export var surface_id: StringName = &"default"
@export_range(8000, 48000, 1000) var sample_rate: int = 22050
@export_range(0.03, 0.5, 0.01) var duration_seconds: float = 0.14
@export_range(20.0, 800.0, 1.0) var body_frequency_hz: float = 105.0
@export_range(0.0, 1.0, 0.01) var noise_amount: float = 0.45
@export_range(0.1, 8.0, 0.1) var decay: float = 4.5
@export var seed: int = 1701
@export_range(-40.0, 0.0, 0.5) var volume_db: float = -18.0
