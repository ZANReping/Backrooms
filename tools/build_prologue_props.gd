extends SceneTree

const RoundedBox := preload("res://core/presentation/rounded_box_mesh.gd")
const PROP_DIR := "res://art/prologue/props"
const MATERIAL_DIR := "res://art/prologue/materials"
const ICON_DIR := "res://assets/prologue/icons"
const FABRIC_ALBEDO := "res://assets/third_party/polyhaven/textures/fabric_pattern_07/fabric_pattern_07_col_1_1k.jpg"
const FABRIC_NORMAL := "res://assets/third_party/polyhaven/textures/fabric_pattern_07/fabric_pattern_07_nor_gl_1k.jpg"
const FABRIC_ARM := "res://assets/third_party/polyhaven/textures/fabric_pattern_07/fabric_pattern_07_arm_1k.jpg"
const LEATHER_ALBEDO := "res://assets/third_party/polyhaven/textures/brown_leather/brown_leather_albedo_1k.jpg"
const LEATHER_NORMAL := "res://assets/third_party/polyhaven/textures/brown_leather/brown_leather_nor_gl_1k.jpg"
const LEATHER_ARM := "res://assets/third_party/polyhaven/textures/brown_leather/brown_leather_arm_1k.jpg"

var materials: Dictionary[StringName, StandardMaterial3D] = {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROP_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	_create_materials()
	var builders: Dictionary[String, Callable] = {
		"phone": _build_phone,
		"laptop": _build_laptop,
		"backpack": _build_backpack,
		"wallet": _build_wallet,
		"keys": _build_keys,
		"water_bottle": _build_water_bottle,
	}
	for prop_name: String in builders:
		if "--phone-only" in OS.get_cmdline_user_args() and prop_name != "phone":
			continue
		var root: Node3D = builders[prop_name].call()
		_validate_prop(prop_name, root)
		_save_scene(root, "%s/%s.tscn" % [PROP_DIR, prop_name])
		await _render_icon(prop_name, root)
		root.queue_free()
	print("PROLOGUE_PROPS_BUILT")
	quit()


func _validate_prop(prop_name: String, root: Node3D) -> void:
	var mesh_nodes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var mesh_count: int = mesh_nodes.size()
	assert(root.position.is_equal_approx(Vector3.ZERO), "%s root must remain at the origin" % prop_name)
	assert(mesh_count <= 40, "%s exceeds the 40 mesh budget" % prop_name)
	for node: Node in mesh_nodes:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh is ArrayMesh:
			var format: int = mesh_node.mesh.surface_get_format(0)
			assert((format & Mesh.ARRAY_FORMAT_TANGENT) != 0, "%s/%s lacks tangent data" % [prop_name, mesh_node.name])
	var bounds: AABB = _visual_bounds(root)
	print("PROP %s meshes=%d bounds=%s center=%s" % [prop_name, mesh_count, bounds.size, bounds.get_center()])
	if prop_name == "phone":
		var screen := root.get_node("DynamicScreenArea") as MeshInstance3D
		assert(screen != null)
		assert(screen.position.is_equal_approx(Vector3(0.0, 0.002, 0.0055)))
		assert(screen.get_aabb().size.is_equal_approx(Vector3(0.075375, 0.134, 0.0004)))


func _create_materials() -> void:
	_material(&"phone_frame", Color("25272a"), 0.18, 0.72)
	_material(&"glass", Color("071016"), 0.08, 0.25)
	_material(&"dark_plastic", Color("171819"), 0.0, 0.5)
	_material(&"aluminum", Color("a9aaab"), 0.72, 0.28)
	_material(&"dark_metal", Color("313438"), 0.78, 0.25)
	_material(&"canvas", Color("413b35"), 0.0, 0.93)
	_material(&"canvas_light", Color("5a5148"), 0.0, 0.9)
	_material(&"leather", Color("4b3024"), 0.0, 0.72)
	_material(&"thread", Color("b18a65"), 0.0, 0.9)
	_material(&"steel", Color("a7adb0"), 0.9, 0.2)
	_material(&"steel_dark", Color("555b5e"), 0.85, 0.3)
	_material(&"fabric_red", Color("6d2e2a"), 0.0, 0.92)
	_material(&"bottle", Color(0.72, 0.86, 0.9, 0.62), 0.0, 0.18, BaseMaterial3D.TRANSPARENCY_ALPHA)
	_material(&"water", Color(0.52, 0.76, 0.83, 0.48), 0.0, 0.12, BaseMaterial3D.TRANSPARENCY_ALPHA)
	_material(&"cap_blue", Color("1b5f88"), 0.0, 0.38)
	_material(&"label", Color("e4dfd2"), 0.0, 0.82)
	_material(&"label_blue", Color("4b7184"), 0.0, 0.7)
	_apply_surface_maps(materials[&"canvas"], FABRIC_ALBEDO, FABRIC_NORMAL, FABRIC_ARM, Color("56504a"), 7.0, 0.82)
	_apply_surface_maps(materials[&"canvas_light"], FABRIC_ALBEDO, FABRIC_NORMAL, FABRIC_ARM, Color("716960"), 7.0, 0.78)
	_apply_surface_maps(materials[&"fabric_red"], FABRIC_ALBEDO, FABRIC_NORMAL, FABRIC_ARM, Color("743934"), 8.0, 0.76)
	_apply_surface_maps(materials[&"leather"], LEATHER_ALBEDO, LEATHER_NORMAL, LEATHER_ARM, Color("785544"), 5.0, 0.58)
	for key: StringName in [&"canvas", &"canvas_light", &"fabric_red", &"leather"]:
		ResourceSaver.save(materials[key], "%s/%s.tres" % [MATERIAL_DIR, key])


func _material(key: StringName, color: Color, metallic: float, roughness: float, transparency: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_DISABLED) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = String(key)
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.transparency = transparency
	if transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = mat
	ResourceSaver.save(mat, "%s/%s.tres" % [MATERIAL_DIR, key])


func _apply_surface_maps(mat: StandardMaterial3D, albedo_path: String, normal_path: String, arm_path: String, tint: Color, texture_scale: float, roughness_floor: float) -> void:
	var albedo := load(albedo_path) as Texture2D
	var normal := load(normal_path) as Texture2D
	var arm := load(arm_path) as Texture2D
	assert(albedo != null and normal != null and arm != null, "Surface texture import missing")
	mat.albedo_texture = albedo
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = normal
	mat.normal_scale = 0.7
	mat.ao_enabled = true
	mat.ao_texture = arm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness_texture = arm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = roughness_floor
	mat.metallic_texture = arm
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = 0.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * texture_scale


func _root(prop_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = prop_name.to_pascal_case()
	return node


func _mesh(parent: Node3D, name_: String, mesh_: Mesh, mat: StringName, position := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh_
	node.material_override = materials[mat]
	node.position = position
	node.rotation = rotation
	parent.add_child(node)
	return node


func _box(parent: Node3D, name_: String, size: Vector3, radius: float, mat: StringName, position := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
	return _mesh(parent, name_, RoundedBox.create(size, radius, 2), mat, position, rotation)


func _cylinder(parent: Node3D, name_: String, radius: float, height: float, mat: StringName, position := Vector3.ZERO, rotation := Vector3.ZERO, sides: int = 20) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = sides
	return _mesh(parent, name_, shape, mat, position, rotation)


func _torus(parent: Node3D, name_: String, inner: float, outer: float, mat: StringName, position := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = inner
	shape.outer_radius = outer
	shape.rings = 24
	shape.ring_segments = 10
	return _mesh(parent, name_, shape, mat, position, rotation)


func _build_phone() -> Node3D:
	var root := _root("phone")
	_box(root, "BeveledFrame", Vector3(0.081, 0.146, 0.009), 0.0045, &"phone_frame")
	_box(root, "FrontGlass", Vector3(0.0775, 0.138, 0.0012), 0.002, &"glass", Vector3(0.0, 0.002, 0.0051))
	_box(root, "DynamicScreenArea", Vector3(0.075375, 0.134, 0.0004), 0.001, &"glass", Vector3(0.0, 0.002, 0.0055))
	_box(root, "Earpiece", Vector3(0.014, 0.001, 0.0008), 0.0004, &"dark_metal", Vector3(0.0, 0.0706, 0.0058))
	_cylinder(root, "CameraDot", 0.0008, 0.0007, &"dark_metal", Vector3(-0.016, 0.0706, 0.0058), Vector3(PI * 0.5, 0.0, 0.0), 12)
	return root


func _build_laptop() -> Node3D:
	var root := _root("laptop")
	_box(root, "LowerShell", Vector3(0.36, 0.011, 0.25), 0.006, &"aluminum", Vector3(0.0, -0.0055, 0.0))
	_box(root, "UpperLid", Vector3(0.352, 0.009, 0.244), 0.006, &"aluminum", Vector3(0.0, 0.0065, -0.002))
	_box(root, "LidSeam", Vector3(0.344, 0.0015, 0.238), 0.004, &"dark_metal", Vector3(0.0, 0.0007, -0.002))
	_cylinder(root, "LeftHinge", 0.006, 0.075, &"dark_metal", Vector3(-0.105, 0.0, -0.119), Vector3(0.0, 0.0, PI * 0.5))
	_cylinder(root, "RightHinge", 0.006, 0.075, &"dark_metal", Vector3(0.105, 0.0, -0.119), Vector3(0.0, 0.0, PI * 0.5))
	for x: float in [-0.09, -0.06, -0.03, 0.0, 0.03, 0.06, 0.09]:
		_box(root, "Vent", Vector3(0.019, 0.0015, 0.002), 0.0004, &"dark_metal", Vector3(x, -0.0112, -0.095))
	_box(root, "UsbPortLeft", Vector3(0.022, 0.0035, 0.006), 0.0005, &"dark_plastic", Vector3(-0.1695, -0.003, 0.035))
	_box(root, "UsbPortRight", Vector3(0.022, 0.0035, 0.006), 0.0005, &"dark_plastic", Vector3(0.1695, -0.003, -0.025))
	return root


func _build_backpack() -> Node3D:
	var root := _root("backpack")
	_box(root, "MainCompartment", Vector3(0.30, 0.43, 0.17), 0.055, &"canvas", Vector3(0.0, 0.0, 0.0))
	_box(root, "LeatherBase", Vector3(0.285, 0.105, 0.17), 0.035, &"leather", Vector3(0.0, -0.158, 0.0))
	_box(root, "FrontPocket", Vector3(0.23, 0.16, 0.04), 0.019, &"canvas_light", Vector3(0.0, -0.07, 0.064))
	_box(root, "FrontPocketFlap", Vector3(0.235, 0.045, 0.008), 0.0035, &"leather", Vector3(0.0, 0.012, 0.080), Vector3(0.08, 0.0, 0.0))
	_box(root, "MainZipper", Vector3(0.25, 0.008, 0.008), 0.003, &"steel_dark", Vector3(0.0, 0.175, 0.068), Vector3(0.18, 0.0, 0.0))
	for x: float in [-0.085, 0.085]:
		_box(root, "ShoulderStrap", Vector3(0.065, 0.33, 0.024), 0.012, &"canvas_light", Vector3(x, -0.005, -0.072), Vector3(0.0, 0.0, x * 0.2))
	_box(root, "HandleTop", Vector3(0.105, 0.022, 0.02), 0.009, &"leather", Vector3(0.0, 0.203, -0.015))
	_box(root, "HandleLeft", Vector3(0.018, 0.052, 0.018), 0.007, &"leather", Vector3(-0.045, 0.184, -0.015), Vector3(0.0, 0.0, -0.25))
	_box(root, "HandleRight", Vector3(0.018, 0.052, 0.018), 0.007, &"leather", Vector3(0.045, 0.184, -0.015), Vector3(0.0, 0.0, 0.25))
	return root


func _build_wallet() -> Node3D:
	var root := _root("wallet")
	_box(root, "FoldedLeather", Vector3(0.11, 0.018, 0.085), 0.008, &"leather")
	_box(root, "FoldEdge", Vector3(0.007, 0.019, 0.072), 0.003, &"thread", Vector3(-0.049, 0.0, 0.0))
	for z: float in [-0.035, 0.035]:
		_box(root, "Stitch", Vector3(0.09, 0.001, 0.0012), 0.0004, &"thread", Vector3(0.005, 0.0096, z))
	return root


func _build_keys() -> Node3D:
	var root := _root("keys")
	_torus(root, "KeyRing", 0.017, 0.020, &"steel", Vector3(-0.025, 0.025, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	for i: int in 2:
		var x: float = -0.006 + i * 0.025
		_box(root, "KeyBlade", Vector3(0.012, 0.055, 0.003), 0.001, &"steel", Vector3(x, -0.018 - i * 0.006, 0.0), Vector3(0.0, 0.0, -0.18 + i * 0.3))
		_torus(root, "KeyBow", 0.007, 0.011, &"steel", Vector3(x - 0.006, 0.010 - i * 0.006, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
		_box(root, "KeyTooth", Vector3(0.008, 0.009, 0.003), 0.0007, &"steel", Vector3(x + 0.006, -0.045 - i * 0.006, 0.0))
	_box(root, "FabricLanyard", Vector3(0.018, 0.105, 0.006), 0.006, &"fabric_red", Vector3(-0.052, -0.027, 0.003), Vector3(0.0, 0.0, 0.5))
	return root


func _build_water_bottle() -> Node3D:
	var root := _root("water_bottle")
	_cylinder(root, "Water", 0.029, 0.165, &"water", Vector3(0.0, -0.018, 0.0), Vector3.ZERO, 24)
	_cylinder(root, "BottleBody", 0.0325, 0.178, &"bottle", Vector3(0.0, -0.014, 0.0), Vector3.ZERO, 24)
	_cylinder(root, "Shoulder", 0.027, 0.025, &"bottle", Vector3(0.0, 0.085, 0.0), Vector3.ZERO, 24)
	_cylinder(root, "Neck", 0.016, 0.022, &"bottle", Vector3(0.0, 0.103, 0.0), Vector3.ZERO, 20)
	_cylinder(root, "BlueCap", 0.019, 0.017, &"cap_blue", Vector3(0.0, 0.108, 0.0), Vector3.ZERO, 20)
	_cylinder(root, "PaperLabel", 0.033, 0.058, &"label", Vector3(0.0, -0.014, 0.0), Vector3.ZERO, 24)
	var label_text := Label3D.new()
	label_text.name = "ChinesePaperLabel"
	label_text.text = "饮用水"
	label_text.font_size = 20
	label_text.pixel_size = 0.001
	label_text.modulate = Color("365f73")
	label_text.outline_size = 2
	label_text.outline_modulate = Color(0.92, 0.9, 0.84, 0.8)
	label_text.position = Vector3(0.0, -0.012, 0.0334)
	root.add_child(label_text)
	for y: float in [-0.086, -0.068, 0.052, 0.067]:
		_torus(root, "BottleRib", 0.030, 0.0323, &"bottle", Vector3(0.0, y, 0.0), Vector3.ZERO)
	return root


func _save_scene(root: Node3D, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_error: Error = packed.pack(root)
	if pack_error != OK:
		push_error("Could not pack %s: %s" % [path, error_string(pack_error)])
		return
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("Could not save %s: %s" % [path, error_string(save_error)])


func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		_set_owner_recursive(child, owner_root)


func _render_icon(prop_name: String, source: Node3D) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.world_3d = World3D.new()
	get_root().add_child(viewport)
	var instance: Node3D = source.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	viewport.add_child(instance)
	var bounds: AABB = _visual_bounds(instance)
	var extent: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	instance.position = -bounds.get_center()
	match prop_name:
		"laptop", "wallet":
			instance.rotation = Vector3(-0.82, 0.45, 0.12)
		"water_bottle":
			instance.rotation = Vector3(-0.08, 0.35, -0.12)
		"keys":
			instance.rotation = Vector3(-0.25, 0.3, -0.25)
		_:
			instance.rotation = Vector3(-0.2, 0.55, 0.08)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent * 1.55
	camera.position = Vector3(0.0, extent * 0.12, extent * 2.2)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	viewport.add_child(camera)
	camera.current = true
	_add_light(viewport, Vector3(-1.5, 2.0, 2.4), Color(1.0, 0.92, 0.82), 3.2, extent)
	_add_light(viewport, Vector3(1.8, 0.5, 1.3), Color(0.62, 0.76, 1.0), 1.8, extent)
	_add_light(viewport, Vector3(0.3, 1.7, -2.0), Color(1.0, 0.86, 0.7), 2.2, extent)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ICON_DIR, prop_name]))
	viewport.queue_free()


func _add_light(viewport: SubViewport, position: Vector3, color: Color, energy: float, extent: float) -> void:
	var light := OmniLight3D.new()
	light.position = position * extent
	light.light_color = color
	light.light_energy = energy
	light.omni_range = extent * 5.0
	light.shadow_enabled = true
	viewport.add_child(light)


func _visual_bounds(root: Node3D) -> AABB:
	var first := true
	var result := AABB()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var local_bounds: AABB = mesh_node.transform * mesh_node.get_aabb()
		if first:
			result = local_bounds
			first = false
		else:
			result = result.merge(local_bounds)
	return result
