class_name PrologueAudio
extends Node

## All source sounds are offline-generated PCM synthesis. They are not field recordings.

const AUDIO_ROOT := "res://assets/prologue/audio"
const AMBIENCE_PATHS: Dictionary[StringName, String] = {
	&"apartment": AUDIO_ROOT + "/apartment_morning.wav",
	&"commute": AUDIO_ROOT + "/commute_morning.wav",
	&"arrival": AUDIO_ROOT + "/arrival_hum.wav",
}

var _ambience := AudioStreamPlayer.new()
var _transition := AudioStreamPlayer.new()
var _alarm := AudioStreamPlayer.new()
var _hint := AudioStreamPlayer.new()
var _location: StringName = &""
var _silence_serial: int = 0
var _base_ambience_db: float = -25.0
var _mode_paused: bool = false
var _owned_tweens: Array[Tween] = []
var _environment_tween: Tween
var _environment_generation: int = 0
var _stream_cache: Dictionary[String, AudioStreamWAV] = {}
var _audio_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_audio_enabled = DisplayServer.get_name() != "headless"
	_setup_player(_ambience, &"Ambience")
	_setup_player(_transition, &"TransitionAmbience")
	_setup_player(_alarm, &"MorningAlarm")
	_setup_player(_hint, &"FluorescentHint")
	if _audio_enabled:
		_hint.stream = _load_pcm(AUDIO_ROOT + "/hum_hint.wav", false)
	_alarm.volume_db = -22.0
	_hint.volume_db = -27.0
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state != null:
		var mode_callback := Callable(self, "_on_mode_changed")
		if not game_state.is_connected(&"mode_changed", mode_callback):
			game_state.connect(&"mode_changed", mode_callback)
		_on_mode_changed(StringName(game_state.get(&"mode")))


func _exit_tree() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	var mode_callback := Callable(self, "_on_mode_changed")
	if game_state != null and game_state.is_connected(&"mode_changed", mode_callback):
		game_state.disconnect(&"mode_changed", mode_callback)
	_environment_generation += 1
	if _environment_tween != null and _environment_tween.is_valid():
		_environment_tween.kill()
	_environment_tween = null
	for tween: Tween in _owned_tweens:
		if tween.is_valid():
			tween.kill()
	_owned_tweens.clear()
	for player: AudioStreamPlayer in [_ambience, _transition, _alarm, _hint]:
		player.stop()
		player.stream_paused = false
		player.stream = null
		if player.get_parent() == self:
			remove_child(player)
		player.free()
	_stream_cache.clear()


func set_location(location_id: StringName) -> void:
	if not AMBIENCE_PATHS.has(location_id) or location_id == _location:
		return
	var generation: int = _begin_environment_intent()
	_location = location_id
	_base_ambience_db = -24.0 if location_id == &"arrival" else -27.0
	if not _audio_enabled:
		return
	_transition.stop()
	_transition.stream = _load_pcm(AMBIENCE_PATHS[location_id], true)
	if _transition.stream == null:
		return
	_transition.volume_db = -60.0
	_transition.play()
	_transition.stream_paused = _mode_paused
	var old_player: AudioStreamPlayer = _ambience
	var new_player: AudioStreamPlayer = _transition
	var fade: Tween = _make_tween(true)
	_environment_tween = fade
	fade.tween_property(old_player, ^"volume_db", -60.0, 1.6)
	fade.tween_property(new_player, ^"volume_db", _base_ambience_db, 1.6)
	fade.finished.connect(_commit_environment_transition.bind(generation, old_player, new_player), CONNECT_ONE_SHOT)


func _commit_environment_transition(generation: int, old_player: AudioStreamPlayer, new_player: AudioStreamPlayer) -> void:
	if generation != _environment_generation or new_player != _transition:
		return
	old_player.stop()
	old_player.stream = null
	var swap: AudioStreamPlayer = _ambience
	_ambience = _transition
	_transition = swap
	_environment_tween = null


func set_alarm(enabled: bool) -> void:
	if not _audio_enabled:
		return
	if enabled:
		if _alarm.stream == null:
			_alarm.stream = _load_pcm(AUDIO_ROOT + "/gentle_alarm.wav", true)
		if not _alarm.playing:
			_alarm.play()
		_alarm.stream_paused = _mode_paused
	else:
		_alarm.stop()
		_alarm.stream = null
		_stream_cache.erase(AUDIO_ROOT + "/gentle_alarm.wav")


func silence_for(seconds: float) -> void:
	if not _audio_enabled:
		return
	_silence_serial += 1
	var serial: int = _silence_serial
	var fade_out: Tween = _make_tween(true)
	for player: AudioStreamPlayer in [_ambience, _transition, _alarm, _hint]:
		fade_out.tween_property(player, ^"volume_db", -60.0, 0.08)
	var hold: Tween = _make_tween()
	hold.tween_interval(maxf(seconds, 0.0))
	await hold.finished
	if serial != _silence_serial:
		return
	var fade_in: Tween = _make_tween(true)
	fade_in.tween_property(_ambience, ^"volume_db", _base_ambience_db, 0.22)
	if _alarm.playing:
		fade_in.tween_property(_alarm, ^"volume_db", -22.0, 0.22)


func hum_hint() -> void:
	if not _audio_enabled:
		return
	_hint.stop()
	_hint.volume_db = -32.0
	_hint.play()
	_hint.stream_paused = _mode_paused
	_make_tween().tween_property(_hint, ^"volume_db", -25.0, 0.18)


func begin_fall() -> void:
	set_alarm(false)
	_begin_environment_intent()
	if not _audio_enabled:
		return
	_transition.stop()
	_transition.stream = _load_pcm(AMBIENCE_PATHS[&"arrival"], true)
	_transition.volume_db = -60.0
	_transition.play()
	_transition.stream_paused = _mode_paused
	var fade: Tween = _make_tween(true)
	_environment_tween = fade
	fade.tween_property(_ambience, ^"volume_db", -60.0, 1.15)
	fade.tween_property(_transition, ^"volume_db", -34.0, 1.15)


func arrive() -> void:
	set_alarm(false)
	_begin_environment_intent()
	_location = &"arrival"
	_base_ambience_db = -24.0
	if not _audio_enabled:
		return
	if _transition.playing and _transition.stream != null:
		_ambience.stop()
		_ambience.stream = null
		var swap: AudioStreamPlayer = _ambience
		_ambience = _transition
		_transition = swap
	else:
		_ambience.stop()
		_ambience.stream = _load_pcm(AMBIENCE_PATHS[&"arrival"], true)
		_ambience.play()
		_ambience.stream_paused = _mode_paused
	var fade: Tween = _make_tween()
	_environment_tween = fade
	fade.tween_property(_ambience, ^"volume_db", _base_ambience_db, 0.8)
	fade.finished.connect(_clear_environment_tween.bind(_environment_generation, fade), CONNECT_ONE_SHOT)


func _setup_player(player: AudioStreamPlayer, player_name: StringName) -> void:
	player.name = player_name
	player.bus = &"Effects" if player_name == &"MorningAlarm" else &"Ambience"
	player.volume_db = -60.0
	add_child(player)
	player.stream_paused = _mode_paused


func _on_mode_changed(mode: StringName) -> void:
	_mode_paused = mode in [&"pause", &"debug", &"dead", &"menu"]
	for player: AudioStreamPlayer in [_ambience, _transition, _alarm, _hint]:
		player.stream_paused = _mode_paused
	for tween: Tween in _owned_tweens:
		if not tween.is_valid():
			continue
		if _mode_paused:
			tween.pause()
		else:
			tween.play()


func _make_tween(parallel: bool = false) -> Tween:
	var tween: Tween = create_tween()
	tween.bind_node(self)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if parallel:
		tween.set_parallel(true)
	_owned_tweens.append(tween)
	tween.finished.connect(_forget_tween.bind(tween), CONNECT_ONE_SHOT)
	if _mode_paused:
		tween.pause()
	return tween


func _begin_environment_intent() -> int:
	_environment_generation += 1
	if _environment_tween != null and _environment_tween.is_valid():
		_owned_tweens.erase(_environment_tween)
		_environment_tween.kill()
	_environment_tween = null
	return _environment_generation


func _clear_environment_tween(generation: int, tween: Tween) -> void:
	if generation == _environment_generation and tween == _environment_tween:
		_environment_tween = null


func _forget_tween(tween: Tween) -> void:
	_owned_tweens.erase(tween)


func _load_pcm(path: String, looping: bool) -> AudioStreamWAV:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var source := load(path) as AudioStreamWAV
	if source == null:
		push_error("Prologue audio missing: %s" % path)
		return null
	source.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	source.loop_begin = 0
	source.loop_end = int(round(source.get_length() * source.mix_rate))
	_stream_cache[path] = source
	return source
