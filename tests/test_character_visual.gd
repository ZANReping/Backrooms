extends Node

func _ready() -> void:
	var creator := CharacterCreator.new()
	add_child(creator)
	creator.set_supported_morphs(GdHumanBackend.SUPPORTED_MORPHS)
	creator.set_preview_character(HumanCharacter.new())
	creator.edit(CharacterAppearance.new())
	await get_tree().create_timer(0.6).timeout
	if creator._preview_character == null or (creator._preview_character as HumanCharacter).backend == null:
		push_error("FAIL: actual character backend did not initialize")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://artifacts/character_visual")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/full_body.webp")
		creator._set_view(false)
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/face.webp")
		_select_option(creator, &"CHARACTER_CREATOR_BODY_TYPE", &"female")
		_select_option(creator, &"CHARACTER_CREATOR_HAIR", &"bob")
		creator._on_morph_changed(0.8, &"eye_distance")
		creator._on_morph_changed(0.8, &"chin_width")
		creator._sync_controls()
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/face_bob_custom.webp")
		get_tree().root.content_scale_size = Vector2i.ZERO
		DisplayServer.window_set_size(Vector2i(960, 540))
		var resize_deadline: int = Time.get_ticks_msec() + 3000
		while get_viewport().get_visible_rect().size != Vector2(960, 540) and Time.get_ticks_msec() < resize_deadline:
			await get_tree().process_frame
		# Containers settle after the native window's resize event reaches the viewport.
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/minimum_960.webp")
		var confirm := creator.find_child("*", true, false)
		for node: Node in creator.find_children("*", "Button", true, false):
			var button := node as Button
			if button.text == tr(&"CHARACTER_CREATOR_CONFIRM"):
				confirm = button
		if not confirm is Button or not Rect2(Vector2.ZERO, Vector2(960, 540)).encloses((confirm as Button).get_global_rect()):
			push_error("FAIL: creator confirmation is outside the minimum window; viewport=%s confirm=%s" % [get_viewport().get_visible_rect(), (confirm as Button).get_global_rect() if confirm is Button else Rect2()])
			get_tree().quit(1)
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_webp("res://artifacts/character_visual/minimum_960.webp")
	print("PASS: character visual rendered")
	get_tree().quit()


func _select_option(creator: CharacterCreator, control_name: StringName, value: StringName) -> void:
	var option := creator.find_child(String(control_name), true, false) as OptionButton
	for index: int in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			option.item_selected.emit(index)
			return
