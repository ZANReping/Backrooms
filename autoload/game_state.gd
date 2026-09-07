extends Node

signal mode_changed(mode: StringName)

enum State { BOOT, MAIN_MENU, PLAYING, PAUSED, TRANSITION, DEAD }
const MODES: Array[StringName] = [&"menu", &"play", &"pause", &"inventory", &"phone", &"camera", &"appearance", &"debug", &"transition", &"dead"]

var state: State = State.BOOT
var mode: StringName = &"menu"


func set_mode(value: StringName) -> void:
	if not MODES.has(value):
		return
	if value == &"debug" and not OS.is_debug_build():
		return
	mode = value
	match mode:
		&"menu": state = State.MAIN_MENU
		&"play": state = State.PLAYING
		&"transition": state = State.TRANSITION
		&"dead": state = State.DEAD
		_: state = State.PAUSED
	mode_changed.emit(mode)
