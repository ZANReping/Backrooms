class_name PlayerStats
extends Resource

signal stat_changed(stat_id: StringName, value: float, maximum: float)
signal died(cause: StringName)

const STAT_IDS: Array[StringName] = [&"health", &"stamina", &"hunger", &"thirst", &"sanity", &"fatigue"]
const DEFAULT_MAXIMUMS: Dictionary[StringName, float] = {
	&"health": 100.0,
	&"stamina": 100.0,
	&"hunger": 100.0,
	&"thirst": 100.0,
	&"sanity": 100.0,
	&"fatigue": 100.0,
}

@export var carry_capacity_kg: float = 20.0
@export var config: PlayerStatsConfig
var values: Dictionary[StringName, float] = {}
var _base_maximums: Dictionary[StringName, float] = DEFAULT_MAXIMUMS.duplicate()
var _modifiers: Dictionary[StringName, StatModifier] = {}
var _death_emitted: bool = false

func _init() -> void:
	if config == null:
		config = PlayerStatsConfig.new()
	reset()

func get_value(id: StringName) -> float:
	return values.get(id, 0.0)

func get_maximum(id: StringName) -> float:
	if not _base_maximums.has(id):
		return 0.0
	var result: float = _base_maximums[id]
	var multiplier: float = 1.0
	for modifier: StatModifier in _modifiers.values():
		if modifier.stat_id != id:
			continue
		if modifier.operation == StatModifier.Operation.ADD_MAXIMUM:
			result += modifier.amount
		elif modifier.operation == StatModifier.Operation.MULTIPLY_MAXIMUM:
			multiplier *= modifier.amount
	return maxf(0.0, result * multiplier)

func change_value(id: StringName, delta: float) -> float:
	if not values.has(id) or not is_finite(delta):
		return get_value(id)
	var maximum := get_maximum(id)
	var next_value := clampf(values[id] + delta, 0.0, maximum)
	if not is_equal_approx(next_value, values[id]):
		values[id] = next_value
		stat_changed.emit(id, next_value, maximum)
	if id == &"health" and next_value <= 0.0 and not _death_emitted:
		_death_emitted = true
		died.emit(&"health_depleted")
	return next_value

func reset() -> void:
	values.clear()
	for id: StringName in STAT_IDS:
		values[id] = 0.0 if id == &"fatigue" else get_maximum(id)
	_death_emitted = false

func tick(delta: float, sprinting: bool, load_ratio: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	if sprinting:
		var stamina_ratio := get_value(&"stamina") / maxf(get_maximum(&"stamina"), 0.001)
		var high_multiplier := config.high_stamina_drain_multiplier if stamina_ratio >= config.high_stamina_threshold_ratio else 1.0
		var overload_multiplier := 1.0 + maxf(0.0, load_ratio - 1.0) * config.overload_drain_multiplier_per_ratio
		change_value(&"stamina", -config.sprint_drain_per_second * high_multiplier * overload_multiplier * delta)
	else:
		var stamina_ratio := get_value(&"stamina") / maxf(get_maximum(&"stamina"), 0.001)
		var recovery_multiplier := config.reduced_recovery_multiplier if stamina_ratio >= config.reduced_recovery_min_ratio and stamina_ratio < config.reduced_recovery_max_ratio else 1.0
		change_value(&"stamina", config.recovery_per_second * recovery_multiplier * delta)
	change_value(&"hunger", -config.hunger_drain_per_second * delta)
	change_value(&"thirst", -config.thirst_drain_per_second * delta)
	change_value(&"fatigue", config.fatigue_gain_per_second * delta)

func add_modifier(modifier: StatModifier) -> bool:
	if modifier == null or not modifier.is_valid() or not values.has(modifier.stat_id):
		return false
	var previous_stat: StringName = &""
	if _modifiers.has(modifier.source_id):
		previous_stat = _modifiers[modifier.source_id].stat_id
	_modifiers[modifier.source_id] = modifier.duplicate(true)
	if previous_stat != &"" and previous_stat != modifier.stat_id:
		_clamp_and_emit(previous_stat)
	_clamp_and_emit(modifier.stat_id)
	return true

func remove_modifier(source_id: StringName) -> bool:
	if not _modifiers.has(source_id):
		return false
	var stat_id: StringName = _modifiers[source_id].stat_id
	_modifiers.erase(source_id)
	_clamp_and_emit(stat_id)
	return true

func remove_modifiers_by_source_prefix(prefix: String) -> int:
	var removed := 0
	var affected: Dictionary[StringName, bool] = {}
	for source_id: StringName in _modifiers.keys():
		if String(source_id).begins_with(prefix):
			affected[_modifiers[source_id].stat_id] = true
			_modifiers.erase(source_id)
			removed += 1
	for stat_id: StringName in affected:
		_clamp_and_emit(stat_id)
	return removed

func to_data() -> Dictionary:
	var serialized_values: Dictionary = {}
	for id: StringName in STAT_IDS:
		serialized_values[String(id)] = values[id]
	var serialized_modifiers: Array[Dictionary] = []
	for modifier: StatModifier in _modifiers.values():
		serialized_modifiers.append(modifier.to_data())
	return {
		"values": serialized_values,
		"carry_capacity_kg": carry_capacity_kg,
		"modifiers": serialized_modifiers,
	}

func load_data(data: Dictionary) -> bool:
	if not data.has("values") or not data["values"] is Dictionary:
		return false
	if not data.has("carry_capacity_kg") or not (data["carry_capacity_kg"] is float or data["carry_capacity_kg"] is int):
		return false
	var candidate_capacity := float(data["carry_capacity_kg"])
	if not is_finite(candidate_capacity) or candidate_capacity <= 0.0:
		return false
	var raw_values: Dictionary = data["values"]
	var candidate_values: Dictionary[StringName, float] = {}
	for id: StringName in STAT_IDS:
		var key := String(id)
		if not raw_values.has(key) or not (raw_values[key] is float or raw_values[key] is int):
			return false
		var value := float(raw_values[key])
		if not is_finite(value) or value < 0.0:
			return false
		candidate_values[id] = value
	var candidate_modifiers: Dictionary[StringName, StatModifier] = {}
	var raw_modifiers: Variant = data.get("modifiers", [])
	if not raw_modifiers is Array:
		return false
	for raw_modifier: Variant in raw_modifiers:
		if not raw_modifier is Dictionary:
			return false
		var modifier := StatModifier.from_data(raw_modifier)
		if modifier == null or candidate_modifiers.has(modifier.source_id) or not candidate_values.has(modifier.stat_id):
			return false
		candidate_modifiers[modifier.source_id] = modifier
	var previous_modifiers := _modifiers
	_modifiers = candidate_modifiers
	for id: StringName in STAT_IDS:
		if candidate_values[id] > get_maximum(id):
			_modifiers = previous_modifiers
			return false
	carry_capacity_kg = candidate_capacity
	values = candidate_values
	_death_emitted = values[&"health"] <= 0.0
	for id: StringName in STAT_IDS:
		stat_changed.emit(id, values[id], get_maximum(id))
	return true

func _clamp_and_emit(stat_id: StringName) -> void:
	values[stat_id] = clampf(values[stat_id], 0.0, get_maximum(stat_id))
	stat_changed.emit(stat_id, values[stat_id], get_maximum(stat_id))
