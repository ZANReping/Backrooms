extends SceneTree

const PlayerStatsScript := preload("res://core/stats/player_stats.gd")
const StatModifierScript := preload("res://core/stats/stat_modifier.gd")

func _initialize() -> void:
	var stats: PlayerStats = PlayerStatsScript.new()
	_assert(is_equal_approx(stats.get_value(&"health"), 100.0), "reset initializes health")
	_assert(is_equal_approx(stats.get_value(&"fatigue"), 0.0), "reset initializes fatigue as no fatigue")
	stats.change_value(&"health", -25.0)
	_assert(is_equal_approx(stats.get_value(&"health"), 75.0), "change_value applies and clamps")
	var modifier: StatModifier = StatModifierScript.new()
	modifier.source_id = &"equipment:test"
	modifier.stat_id = &"stamina"
	modifier.operation = StatModifier.Operation.ADD_MAXIMUM
	modifier.amount = 20.0
	_assert(stats.add_modifier(modifier), "modifier accepted")
	_assert(is_equal_approx(stats.get_maximum(&"stamina"), 120.0), "modifier changes maximum")
	var replacement: StatModifier = StatModifierScript.new()
	replacement.source_id = &"equipment:test"
	replacement.stat_id = &"health"
	replacement.operation = StatModifier.Operation.ADD_MAXIMUM
	replacement.amount = 10.0
	_assert(stats.add_modifier(replacement), "same source modifier can move to another stat")
	_assert(is_equal_approx(stats.get_maximum(&"stamina"), 100.0) and is_equal_approx(stats.get_maximum(&"health"), 110.0), "modifier replacement updates old and new stats")
	stats.change_value(&"stamina", -30.0)
	var stamina_before := stats.get_value(&"stamina")
	stats.tick(1.0, false, 0.0)
	_assert(is_equal_approx(stats.get_value(&"stamina") - stamina_before, stats.config.recovery_per_second * stats.config.reduced_recovery_multiplier), "mid-band stamina recovery is reduced")
	var fatigue_before := stats.get_value(&"fatigue")
	stats.tick(1.0, false, 0.0)
	_assert(stats.get_value(&"fatigue") > fatigue_before, "fatigue increases over time")
	var saved := stats.to_data()
	var restored: PlayerStats = PlayerStatsScript.new()
	_assert(restored.load_data(saved), "valid snapshot loads")
	_assert(is_equal_approx(restored.get_value(&"health"), 75.0), "snapshot preserves values")
	var before := restored.to_data()
	var invalid := saved.duplicate(true)
	invalid["values"]["health"] = -1.0
	_assert(not restored.load_data(invalid), "invalid snapshot rejected")
	_assert(restored.to_data() == before, "failed load is transactional")
	var player_scene := load("res://player/player.tscn") as PackedScene
	_assert(player_scene != null, "player scene loads")
	var player := player_scene.instantiate() as PlayerController
	_assert(player != null, "player scene instantiates as PlayerController")
	root.add_child(player)
	await process_frame
	_assert(player.camera != null and player.interaction_origin != null, "player exposes camera and interaction origin")
	player.bind_stats(restored)
	player.set_control_enabled(false)
	player.queue_free()
	print("PASS: player stats")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	quit(1)
