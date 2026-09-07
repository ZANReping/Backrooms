class_name FactionAppearanceProfile
extends Resource

@export var id: StringName = &"civilian"
@export var hair_ids: Array[StringName] = [&"short", &"crop", &"bob", &"tied"]
@export var hair_weights: Array[float] = [1.0, 1.0, 1.0, 1.0]
@export var skin_palette: Array[Color] = [Color("f2d5c1"), Color("e6bd9d"), Color("cf9670"), Color("a86e4c"), Color("79503b"), Color("4e342d")]
@export var clothing_colors: Array[Color] = [Color("6f7c80"), Color("59666b"), Color("7a6657"), Color("596651"), Color("6f5964")]
@export_range(0.0, 1.0, 0.01) var morph_variation: float = 0.18
@export var preset_only: bool = false
