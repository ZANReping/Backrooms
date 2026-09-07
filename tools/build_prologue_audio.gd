extends SceneTree

## Offline PCM synthesizer for understated ambience. No output is a field recording.

const OUTPUT_DIR := "res://assets/prologue/audio"
const SAMPLE_RATE := 22050
const MAX_PEAK := 0.5

var _noise_state: int = 0x13579B


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_loop("apartment_morning.wav", 8.0, _apartment_sample)
	_build_loop("commute_morning.wav", 8.0, _commute_sample)
	_build_loop("arrival_hum.wav", 8.0, _arrival_sample)
	_build_loop("gentle_alarm.wav", 4.0, _alarm_sample)
	_build_one_shot("hum_hint.wav", 1.2, _hint_sample)
	await _runtime_smoke()
	print("PROLOGUE_AUDIO_BUILT")
	quit()


func _runtime_smoke() -> void:
	var audio_script := load("res://core/prologue/prologue_audio.gd") as GDScript
	assert(audio_script != null, "PrologueAudio script could not load")
	var component := audio_script.new() as Node
	assert(component != null, "PrologueAudio could not instantiate")
	get_root().add_child(component)
	await process_frame
	var mode_callback := Callable(component, "_on_mode_changed")
	var game_state: Node = get_root().get_node("GameState")
	assert(game_state.is_connected(&"mode_changed", mode_callback), "PrologueAudio did not connect GameState.mode_changed")
	component.call("set_location", &"apartment")
	component.call("set_alarm", true)
	game_state.call("set_mode", &"pause")
	for child: Node in component.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			assert((child as AudioStreamPlayer).stream_paused, "pause mode did not pause prologue audio")
	component.call("set_location", &"commute")
	component.call("set_alarm", true)
	for child: Node in component.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			assert((child as AudioStreamPlayer).stream_paused, "play request cleared paused state")
	game_state.call("set_mode", &"phone")
	for child: Node in component.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			assert(not (child as AudioStreamPlayer).stream_paused, "phone mode did not resume prologue audio")
	game_state.call("set_mode", &"inventory")
	game_state.call("set_mode", &"transition")
	component.call("hum_hint")
	component.call("silence_for", 0.01)
	component.call("begin_fall")
	component.call("arrive")
	game_state.call("set_mode", &"dead")
	for child: Node in component.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			assert((child as AudioStreamPlayer).stream_paused, "dead mode did not pause prologue audio")
	game_state.call("set_mode", &"play")
	for child: Node in component.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			assert(not (child as AudioStreamPlayer).stream_paused, "play mode did not resume prologue audio")
	await process_frame
	for tween: Tween in get_processed_tweens():
		tween.kill()
	for child: Node in component.get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
	component.free()
	# Let the audio thread consume stop/null commands before the short-lived tool exits.
	for _frame: int in 30:
		await process_frame
	print("AUDIO_RUNTIME_SMOKE_OK")


func _build_loop(file_name: String, seconds: float, sampler: Callable) -> void:
	var samples: PackedFloat32Array = _synthesize(seconds, sampler)
	_seam_loop(samples, mini(int(SAMPLE_RATE * 0.12), samples.size() / 4))
	_validate(file_name, samples, true)
	_write_wav(file_name, samples)


func _build_one_shot(file_name: String, seconds: float, sampler: Callable) -> void:
	var samples: PackedFloat32Array = _synthesize(seconds, sampler)
	var fade_count: int = int(SAMPLE_RATE * 0.04)
	for i: int in fade_count:
		var gain: float = float(i) / fade_count
		samples[i] *= gain
		samples[samples.size() - 1 - i] *= gain
	_validate(file_name, samples, false)
	_write_wav(file_name, samples)


func _synthesize(seconds: float, sampler: Callable) -> PackedFloat32Array:
	_noise_state = 0x13579B
	var count: int = int(seconds * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var filtered_noise: float = 0.0
	for i: int in count:
		var t: float = float(i) / SAMPLE_RATE
		filtered_noise = lerpf(filtered_noise, _white_noise(), 0.035)
		samples[i] = clampf(float(sampler.call(t, seconds, filtered_noise)), -MAX_PEAK, MAX_PEAK)
	return samples


func _apartment_sample(t: float, length: float, noise: float) -> float:
	var fridge: float = sin(TAU * 58.0 * t) * 0.055 + sin(TAU * 116.0 * t) * 0.014
	var compressor: float = 0.76 + 0.24 * sin(TAU * t / length)
	var distant_traffic: float = noise * 0.055 + sin(TAU * 37.0 * t) * 0.012
	return fridge * compressor + distant_traffic


func _commute_sample(t: float, length: float, noise: float) -> float:
	var traffic_swell: float = 0.6 + 0.25 * sin(TAU * t / length) + 0.15 * sin(TAU * 3.0 * t / length)
	var traffic: float = (noise * 0.14 + sin(TAU * 43.0 * t) * 0.018) * traffic_swell
	var bird_gate: float = pow(maxf(sin(TAU * 2.0 * t / length), 0.0), 12.0)
	var birds: float = sin(TAU * (1760.0 + 160.0 * sin(TAU * 9.0 * t)) * t) * bird_gate * 0.012
	return traffic + birds


func _arrival_sample(t: float, length: float, noise: float) -> float:
	var mains: float = sin(TAU * 50.0 * t) * 0.045 + sin(TAU * 100.0 * t) * 0.014
	var ballast: float = sin(TAU * 150.0 * t) * 0.008
	var air: float = noise * (0.085 + 0.012 * sin(TAU * t / length))
	return mains + ballast + air


func _alarm_sample(t: float, length: float, _noise: float) -> float:
	var phase: float = fmod(t, 2.0)
	var first: float = _soft_chime(phase, 0.20)
	var second: float = _soft_chime(phase, 0.72)
	return (first + second) * 0.18


func _hint_sample(t: float, _length: float, noise: float) -> float:
	var envelope: float = sin(PI * clampf(t / 1.2, 0.0, 1.0))
	return (sin(TAU * 50.0 * t) * 0.13 + sin(TAU * 100.0 * t) * 0.035 + noise * 0.04) * envelope


func _soft_chime(t: float, start: float) -> float:
	var local: float = t - start
	if local < 0.0 or local > 0.46:
		return 0.0
	var envelope: float = sin(PI * local / 0.46) * exp(-local * 2.4)
	return (sin(TAU * 660.0 * local) + sin(TAU * 880.0 * local) * 0.42) * envelope


func _white_noise() -> float:
	_noise_state = int((_noise_state * 1103515245 + 12345) & 0x7fffffff)
	return float(_noise_state) / 1073741824.0 - 1.0


func _seam_loop(samples: PackedFloat32Array, crossfade: int) -> void:
	for i: int in crossfade:
		var mix_value: float = float(i) / maxf(crossfade - 1, 1)
		var start_value: float = samples[i]
		var end_value: float = samples[samples.size() - crossfade + i]
		var blended: float = lerpf(end_value, start_value, mix_value)
		samples[i] = blended
		samples[samples.size() - crossfade + i] = blended
	samples[samples.size() - 1] = samples[0]


func _validate(file_name: String, samples: PackedFloat32Array, looping: bool) -> void:
	var peak: float = 0.0
	var sum: float = 0.0
	for sample: float in samples:
		peak = maxf(peak, absf(sample))
		sum += sample
	var dc: float = sum / samples.size()
	var seam: float = absf(samples[0] - samples[samples.size() - 1]) if looping else 0.0
	assert(peak <= MAX_PEAK + 0.0001, "%s peak exceeds limit" % file_name)
	assert(absf(dc) < 0.01, "%s has excessive DC offset" % file_name)
	assert(seam < 0.001, "%s has a loop seam discontinuity" % file_name)
	print("AUDIO %s seconds=%.2f peak=%.4f dc=%.6f seam=%.6f" % [file_name, float(samples.size()) / SAMPLE_RATE, peak, dc, seam])


func _write_wav(file_name: String, samples: PackedFloat32Array) -> void:
	var path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write %s" % path)
	var data_size: int = samples.size() * 2
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data_size)
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(SAMPLE_RATE)
	file.store_32(SAMPLE_RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_size)
	for sample: float in samples:
		file.store_16(int(round(sample * 32767.0)) & 0xffff)
