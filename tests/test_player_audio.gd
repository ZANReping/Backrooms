extends SceneTree

func _initialize() -> void:
	var scene := load("res://player/player.tscn") as PackedScene
	_assert(scene != null, "player scene loads")
	var first := scene.instantiate() as PlayerController
	var second := scene.instantiate() as PlayerController
	root.add_child(first)
	root.add_child(second)
	await process_frame
	_assert(first.collision_shape.shape != second.collision_shape.shape, "each player owns an independent collision shape")
	var first_capsule := first.collision_shape.shape as CapsuleShape3D
	var second_capsule := second.collision_shape.shape as CapsuleShape3D
	first_capsule.height = 1.25
	_assert(not is_equal_approx(first_capsule.height, second_capsule.height), "mutating one capsule does not affect another player")
	first.apply_look(Vector2(30.0, 20.0))
	var saved := Transform3D(Basis.from_euler(Vector3(0.0, 0.9, 0.0)), Vector3(2.0, 3.0, 4.0))
	first.restore_transform(saved)
	_assert(is_equal_approx(first.rotation.y, 0.9) and first.camera_pivot.rotation.is_zero_approx() and first.camera.rotation.is_zero_approx(), "restore synchronizes yaw and resets local pitch")
	var concrete := first.player_audio.get_stream(&"concrete")
	var carpet := first.player_audio.get_stream(&"carpet")
	_assert(concrete != null and carpet != null, "concrete and carpet PCM streams are generated")
	_assert(concrete.data != carpet.data, "surface profiles produce different PCM")
	var before := first.player_audio.playback_requests
	first.stepped.emit(&"carpet")
	_assert(first.player_audio.playback_requests == before + 1 and first.player_audio.last_surface_id == &"carpet", "stepped signal triggers matching playback")
	first.queue_free()
	second.queue_free()
	print("PASS: player audio and instance isolation")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	quit(1)
