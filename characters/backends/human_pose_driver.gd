class_name HumanPoseDriver
extends RefCounted

## Model-space pose authoring avoids depending on the imported bones' roll axes.
## Geometry, lengths and bind transforms stay unchanged. The feet use a simple
## two-bone solve with distinct contact and swing phases on level ground.
var skeleton: Skeleton3D
var _ids: Dictionary[StringName, int] = {}
var _rest: Dictionary[int, Transform3D] = {}
var _local_rest: Dictionary[int, Quaternion] = {}
var _phase: float = 0.0
var _blend: float = 0.0
var _interaction_remaining: float = 0.0


func configure(value: Skeleton3D) -> void:
	skeleton = value
	for index: int in skeleton.get_bone_count():
		_ids[skeleton.get_bone_name(index)] = index
		_rest[index] = skeleton.get_bone_global_rest(index)
		_local_rest[index] = skeleton.get_bone_pose_rotation(index)
	update(0.0, false, 0.0)


func update(speed: float, crouched: bool, delta: float) -> void:
	if not is_instance_valid(skeleton):
		return
	_blend = move_toward(_blend, clampf(speed / 0.75, 0.0, 1.0), delta * 4.0)
	var cadence: float = clampf(speed / 1.1, 0.8, 1.65)
	_phase = fmod(_phase + delta * TAU * cadence * _blend, TAU)
	for id: StringName in _ids:
		if String(id).begins_with("upper_arm") or String(id).begins_with("forearm") or String(id).begins_with("hand") or String(id).begins_with("thigh") or String(id).begins_with("shin") or String(id).begins_with("foot") or String(id).begins_with("f_") or String(id).begins_with("thumb"):
			skeleton.set_bone_pose_rotation(_ids[id], _local_rest[_ids[id]])
	for side: String in ["L", "R"]:
		var sign_value: float = 1.0 if side == "L" else -1.0
		var cycle: float = fposmod(_phase + (0.0 if side == "L" else PI), TAU) / TAU
		var arm_swing: float = -cos(cycle * TAU) * 0.065 * _blend
		aim_bone(StringName("upper_arm." + side), StringName("forearm." + side), Vector3(sign_value * 0.035, -0.24, arm_swing + 0.007))
		aim_bone(StringName("forearm." + side), StringName("hand." + side), Vector3(sign_value * 0.018, -0.235, 0.03 + arm_swing * 0.25))
		var palm := Basis(Vector3(0, 0, -sign_value), Vector3.DOWN, Vector3(-sign_value, 0, 0))
		set_model_basis(StringName("hand." + side), palm.rotated(Vector3.RIGHT, -arm_swing * 1.5))
		# Relaxed fingers, with progressively more curl towards the little finger.
		for finger: String in ["index", "middle", "ring", "pinky"]:
			var curl: float = 0.10 + ["index", "middle", "ring", "pinky"].find(finger) * 0.045
			for segment: int in [1, 2, 3]:
				var id := StringName("f_%s.0%d.%s" % [finger, segment, side])
				if _ids.has(id):
					var pose: Transform3D = skeleton.get_bone_global_pose(_ids[id])
					set_model_basis(id, pose.basis.rotated(palm.x, curl))
		if _blend > 0.001 or crouched:
			var ankle_id := StringName("foot." + side)
			var ankle: Vector3 = _rest[_ids[ankle_id]].origin
			var stride: float = clampf(speed / cadence, 0.0, 1.8) * 0.52
			var lift: float = 0.0
			if cycle < 0.62:
				ankle.z += lerpf(stride * 0.5, -stride * 0.5, cycle / 0.62) * _blend
			else:
				var swing_t: float = (cycle - 0.62) / 0.38
				ankle.z += lerpf(-stride * 0.5, stride * 0.5, smoothstep(0.0, 1.0, swing_t)) * _blend
				lift = sin(swing_t * PI) * 0.072 * _blend
			ankle.y += lift + 0.025 * _blend + (0.36 if crouched else 0.0)
			solve_limb(StringName("thigh." + side), StringName("shin." + side), ankle_id, ankle, Vector3.FORWARD * -1.0)
			set_model_basis(ankle_id, _rest[_ids[ankle_id]].basis.rotated(Vector3.RIGHT, -lift * 1.5))
	_update_interaction(delta)


func play_interaction() -> void:
	_interaction_remaining = 0.75


func _update_interaction(delta: float) -> void:
	if _interaction_remaining <= 0.0:
		return
	_interaction_remaining = maxf(0.0, _interaction_remaining - delta)
	var amount: float = sin((1.0 - _interaction_remaining / 0.75) * PI)
	amount = smoothstep(0.0, 1.0, amount)
	var hand: Transform3D = skeleton.get_bone_global_pose(_ids[&"hand.R"])
	var target: Vector3 = hand.origin.lerp(Vector3(-0.19, 1.23, 0.39), amount)
	solve_limb(&"upper_arm.R", &"forearm.R", &"hand.R", target, Vector3(-1.0, -0.4, 0.0))
	var palm := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	set_model_basis(&"hand.R", Basis(hand.basis.get_rotation_quaternion().slerp(palm.get_rotation_quaternion(), amount)))


func body_offset(crouched: bool) -> Vector3:
	return Vector3(0.0, (-0.36 if crouched else 0.0) - 0.025 * _blend, 0.0)


func aim_bone(id: StringName, child_id: StringName, direction: Vector3) -> void:
	if not _ids.has(id) or not _ids.has(child_id) or direction.length_squared() < 0.00001:
		return
	var at: Transform3D = skeleton.get_bone_global_pose(_ids[id])
	var child: Transform3D = skeleton.get_bone_global_pose(_ids[child_id])
	var from: Vector3 = (child.origin - at.origin).normalized()
	set_model_basis(id, Basis(Quaternion(from, direction.normalized())) * at.basis)


func set_model_basis(id: StringName, basis: Basis) -> void:
	if not _ids.has(id):
		return
	var index: int = _ids[id]
	var parent: int = skeleton.get_bone_parent(index)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * basis).orthonormalized().get_rotation_quaternion())


func solve_limb(upper: StringName, lower: StringName, end: StringName, target: Vector3, bend_hint: Vector3) -> void:
	if not _ids.has(upper) or not _ids.has(lower) or not _ids.has(end):
		return
	var origin: Vector3 = skeleton.get_bone_global_pose(_ids[upper]).origin
	var length_a: float = _rest[_ids[upper]].origin.distance_to(_rest[_ids[lower]].origin)
	var length_b: float = _rest[_ids[lower]].origin.distance_to(_rest[_ids[end]].origin)
	var direction: Vector3 = (target - origin).normalized()
	var distance: float = clampf(origin.distance_to(target), absf(length_a - length_b) + 0.0001, length_a + length_b - 0.0001)
	var bend: Vector3 = (bend_hint - direction * bend_hint.dot(direction)).normalized()
	var cosine: float = clampf((distance * distance + length_a * length_a - length_b * length_b) / (2.0 * distance * length_a), -1.0, 1.0)
	var joint: Vector3 = origin + direction * length_a * cosine + bend * length_a * sqrt(maxf(0.0, 1.0 - cosine * cosine))
	aim_bone(upper, lower, joint - origin)
	aim_bone(lower, end, origin + direction * distance - joint)
