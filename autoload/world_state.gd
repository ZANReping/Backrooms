extends Node

var data: WorldData = WorldData.new()
## Presentation flow controls which modes advance time; the M1 default is unchanged.
var clock_modes: Array[StringName] = [&"play"]


func _process(delta: float) -> void:
	if GameState.mode in clock_modes:
		data.clock_seconds += delta * data.time_scale


func clock_text() -> String:
	var total_minutes: int = int(data.clock_seconds) / 60
	return "%02d:%02d" % [(total_minutes / 60) % 24, total_minutes % 60]
