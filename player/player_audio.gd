class_name PlayerAudio
extends Node

@export var profiles: Array[AudioProfile] = []
@export var player_path: NodePath = ^"AudioStreamPlayer3D"

var last_surface_id: StringName = &""
var playback_requests: int = 0
var _streams: Dictionary[StringName, AudioStreamWAV] = {}
@onready var audio_player: AudioStreamPlayer3D = get_node(player_path)

func _ready() -> void:
	_initialize_streams()

func _exit_tree() -> void:
	# Release the active playback before the synthesized streams leave the tree.
	if is_instance_valid(audio_player):
		audio_player.stop()
		audio_player.stream = null
	_streams.clear()

func play_step(surface_id: StringName) -> void:
	if _streams.is_empty():
		_initialize_streams()
	var resolved := surface_id if _streams.has(surface_id) else &"concrete"
	if not _streams.has(resolved):
		return
	var profile := _find_profile(resolved)
	last_surface_id = resolved
	playback_requests += 1
	audio_player.stream = _streams[resolved]
	audio_player.volume_db = profile.volume_db if profile != null else -18.0
	audio_player.pitch_scale = 1.0
	audio_player.play()

func get_stream(surface_id: StringName) -> AudioStreamWAV:
	if _streams.is_empty():
		_initialize_streams()
	return _streams.get(surface_id) as AudioStreamWAV

func _initialize_streams() -> void:
	if not _streams.is_empty():
		return
	for profile: AudioProfile in profiles:
		if profile != null and not profile.surface_id.is_empty() and not _streams.has(profile.surface_id):
			_streams[profile.surface_id] = synthesize(profile)

func _find_profile(surface_id: StringName) -> AudioProfile:
	for profile: AudioProfile in profiles:
		if profile != null and profile.surface_id == surface_id:
			return profile
	return null

static func synthesize(profile: AudioProfile) -> AudioStreamWAV:
	var frame_count := maxi(1, int(profile.sample_rate * profile.duration_seconds))
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = profile.seed
	for frame: int in frame_count:
		var time := float(frame) / float(profile.sample_rate)
		var progress := float(frame) / float(frame_count)
		var envelope := exp(-profile.decay * progress) * sin(PI * minf(progress * 12.0, 1.0))
		var body := sin(TAU * profile.body_frequency_hz * time)
		var noise := random.randf_range(-1.0, 1.0)
		var sample := clampf((body * (1.0 - profile.noise_amount) + noise * profile.noise_amount) * envelope * 0.55, -1.0, 1.0)
		var value := int(sample * 32767.0)
		pcm.encode_s16(frame * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = profile.sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream
