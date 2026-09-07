@tool
extends SceneTree

const OUTPUT := "res://levels/prologue/commute.tscn"
const PREVIEW := "res://art/prologue/commute/preview.png"
const FoundationRoomScript := preload("res://core/world/foundation_room.gd")
const RoomEntranceScript := preload("res://core/world/room_entrance.gd")
const AmbientWalkerScript := preload("res://characters/ambient_walker.gd")
const HumanCharacterScript := preload("res://characters/human_character.gd")

var scene_root: Node3D
var mats: Dictionary = {}


func _init() -> void:
	build_scene()
	await validate_walk_route()
	if "--render" in OS.get_cmdline_user_args():
		await render_preview()
	quit()


func mat(name: String, color: Color, roughness := 0.82, metallic := 0.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	mats[name] = m
	return m


func plaster() -> ShaderMaterial:
	if mats.has("WhitePlaster02"):
		return mats["WhitePlaster02"]
	var m := ShaderMaterial.new()
	m.resource_name = "WhitePlaster02"
	m.shader = load("res://art/prologue/commute/wall.gdshader")
	m.set_shader_parameter("plaster_albedo", load("res://assets/third_party/polyhaven/textures/white_plaster_02/white_plaster_02_diff_2k.jpg"))
	m.set_shader_parameter("plaster_normal", load("res://assets/third_party/polyhaven/textures/white_plaster_02/white_plaster_02_nor_gl_1k.jpg"))
	m.set_shader_parameter("plaster_arm", load("res://assets/third_party/polyhaven/textures/white_plaster_02/white_plaster_02_arm_1k.jpg"))
	m.set_shader_parameter("texture_strength", 0.19)
	m.set_shader_parameter("normal_strength", 0.10)
	mats["WhitePlaster02"] = m
	return m


func terrazzo() -> ShaderMaterial:
	if mats.has("Terrazzo"):
		return mats["Terrazzo"]
	var m := ShaderMaterial.new()
	m.resource_name = "TerrazzoTiles"
	m.shader = load("res://art/prologue/commute/ground.gdshader")
	m.set_shader_parameter("tile_albedo", load("res://assets/third_party/polyhaven/textures/terrazzo_tiles/terrazzo_tiles_diff_2k.jpg"))
	m.set_shader_parameter("tile_normal", load("res://assets/third_party/polyhaven/textures/terrazzo_tiles/terrazzo_tiles_nor_gl_1k.jpg"))
	m.set_shader_parameter("tile_arm", load("res://assets/third_party/polyhaven/textures/terrazzo_tiles/terrazzo_tiles_arm_1k.jpg"))
	mats["Terrazzo"] = m
	return m


func add_box(parent: Node, name: String, pos: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_node.mesh = mesh
	mesh_node.position = pos
	parent.add_child(mesh_node)
	mesh_node.owner = scene_root
	if collision:
		var body := StaticBody3D.new()
		body.name = name + "Body"
		parent.add_child(body)
		body.owner = scene_root
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		shape_node.position = pos
		body.add_child(shape_node)
		shape_node.owner = scene_root
	return mesh_node


func add_boundary(parent: Node, name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)
	body.owner = scene_root
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	shape_node.owner = scene_root


func add_cylinder(parent: Node, name: String, pos: Vector3, radius: float, height: float, material: Material, sides := 12) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	node.owner = scene_root
	return node


func add_capsule(parent: Node, name: String, pos: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	node.rotation = rotation
	parent.add_child(node)
	node.owner = scene_root
	return node


func add_leaf_crown(parent: Node, name: String, pos: Vector3, scale: Vector3, material: Material, rotation := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 9
	mesh.rings = 5
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.rotation = rotation
	parent.add_child(node)
	node.owner = scene_root


func add_leaf_cluster(parent: Node, name: String, pos: Vector3, variant: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var crown_centers := [Vector3(-0.16, 0.10, -0.08), Vector3(0.18, 0.02, 0.10), Vector3(0.02, 0.30, 0.0)]
	for leaf_i in range(30):
		var crown: Vector3 = crown_centers[leaf_i % crown_centers.size()]
		var angle := float(leaf_i * 2.399 + variant * 0.71)
		var ring := 0.10 + float((leaf_i * 7) % 11) * 0.022
		var center := crown + Vector3(cos(angle) * ring, float((leaf_i * 5) % 9) * 0.035, sin(angle) * ring)
		var length := 0.18 + float((leaf_i * 3) % 7) * 0.018
		var width := 0.045 + float((leaf_i * 11) % 5) * 0.008
		var basis := Basis.from_euler(Vector3(-0.75 + float(leaf_i % 6) * 0.24, angle, -0.38 + float(leaf_i % 5) * 0.19))
		var base := vertices.size()
		var local_points := [Vector3(0, -length * 0.5, 0), Vector3(-width, -length * 0.05, 0), Vector3(0, length * 0.5, 0), Vector3(width, -length * 0.05, 0)]
		var normal := basis * Vector3(0, 0, 1)
		for point: Vector3 in local_points:
			vertices.append(center + basis * point)
			normals.append(normal)
		uvs.append(Vector2(0.5, 1.0))
		uvs.append(Vector2(0.0, 0.52))
		uvs.append(Vector2(0.5, 0.0))
		uvs.append(Vector2(1.0, 0.52))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = Color("4b6544")
	leaf_material.roughness = 0.88
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, leaf_material)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	node.owner = scene_root


func add_label(parent: Node, name: String, text: String, pos: Vector3, rotation_y: float, size := 54, color := Color(0.82, 0.78, 0.66)) -> void:
	var label := Label3D.new()
	label.name = name
	label.text = text
	label.font_size = size
	label.modulate = color
	label.outline_size = 5
	label.position = pos
	label.rotation.y = rotation_y
	label.pixel_size = 0.006
	label.no_depth_test = false
	label.double_sided = false
	parent.add_child(label)
	label.owner = scene_root


func add_window_grid(parent: Node, prefix: String, x: float, z: float, facing_x: bool) -> void:
	var wall_mat := plaster()
	var frame := mat("WindowFrame", Color("4b5050"), 0.64, 0.2)
	var glass_dark := mat("WindowInteriorDark", Color("273338"), 0.46, 0.02)
	var glass_cool := mat("WindowInteriorCool", Color("405158"), 0.40, 0.03)
	var curtain := mat("Curtain", Color("a19b89"), 0.94)
	for floor_i in range(6):
		for bay in range(4):
			var y := 2.0 + floor_i * 2.65
			var lateral := -4.5 + bay * 3.0
			var p := Vector3(x, y, z + lateral) if facing_x else Vector3(lateral, y, z)
			var sz := Vector3(0.08, 1.25, 1.55) if facing_x else Vector3(1.55, 1.25, 0.08)
			var glass_mat: Material = glass_dark if (floor_i * 3 + bay) % 4 != 0 else glass_cool
			add_box(parent, prefix + "Window_%d_%d" % [floor_i, bay], p, sz, glass_mat)
			var sill_p := p + Vector3(0.0, -0.72, 0.0)
			var sill_s := Vector3(0.18, 0.10, 1.82) if facing_x else Vector3(1.82, 0.10, 0.18)
			add_box(parent, prefix + "Sill_%d_%d" % [floor_i, bay], sill_p, sill_s, wall_mat)
			var mullion_s := Vector3(0.10, 1.30, 0.07) if facing_x else Vector3(0.07, 1.30, 0.10)
			var jamb_s := Vector3(0.11, 1.43, 0.08) if facing_x else Vector3(0.08, 1.43, 0.11)
			var front_offset := Vector3(0.055, 0, 0) if facing_x else Vector3(0, 0, 0.055)
			add_box(parent, prefix + "Mullion_%d_%d" % [floor_i, bay], p + front_offset, mullion_s, frame)
			var side_axis := Vector3(0, 0, 0.76) if facing_x else Vector3(0.76, 0, 0)
			add_box(parent, prefix + "JambA_%d_%d" % [floor_i, bay], p + front_offset - side_axis, jamb_s, frame)
			add_box(parent, prefix + "JambB_%d_%d" % [floor_i, bay], p + front_offset + side_axis, jamb_s, frame)
			if (floor_i + bay) % 3 == 1:
				var curtain_p := p - front_offset * 0.5 + (Vector3(0, 0, 0.38) if facing_x else Vector3(0.38, 0, 0))
				var curtain_s := Vector3(0.035, 1.10, 0.60) if facing_x else Vector3(0.60, 1.10, 0.035)
				add_box(parent, prefix + "Curtain_%d_%d" % [floor_i, bay], curtain_p, curtain_s, curtain)
			if (floor_i + bay) % 3 == 0:
				var ac_p := p + (Vector3(-0.12, -1.25, 1.1) if facing_x else Vector3(1.1, -1.25, -0.12))
				var ac_s := Vector3(0.42, 0.52, 0.88) if facing_x else Vector3(0.88, 0.52, 0.42)
				add_box(parent, prefix + "AC_%d_%d" % [floor_i, bay], ac_p, ac_s, mat("ACMetal", Color("aaa99d"), 0.78, 0.2))


func add_car(parent: Node, name: String, pos: Vector3, color: Color, rot_y := 0.0) -> void:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	n.owner = scene_root
	var paint := mat(name + "Paint", color, 0.42, 0.12)
	add_box(n, "Body", Vector3(0, 0.55, 0), Vector3(1.75, 0.62, 4.05), paint)
	add_box(n, "Cabin", Vector3(0, 1.05, -0.15), Vector3(1.55, 0.72, 2.05), mat("CarGlass", Color("27363b"), 0.28, 0.1))
	for sx in [-0.88, 0.88]:
		for sz in [-1.3, 1.3]:
			var wheel := add_cylinder(n, "Wheel", Vector3(sx, 0.34, sz), 0.32, 0.18, mat("Rubber", Color("17191a"), 0.94), 12)
			wheel.rotation.z = PI * 0.5


func add_person(parent: Node, name: String, pos: Vector3, clothes: Color, waypoints: PackedVector3Array, speed: float, initial_wait: float) -> void:
	var walker := CharacterBody3D.new()
	walker.name = name
	walker.position = pos
	walker.set_script(AmbientWalkerScript)
	walker.set("walk_speed", speed)
	walker.set("local_waypoints", waypoints)
	walker.set("start_waypoint", 1)
	walker.set("initial_wait_seconds", initial_wait)
	walker.set("waypoint_wait_seconds", 0.8)
	walker.collision_layer = 8
	walker.collision_mask = 11
	walker.floor_snap_length = 0.18
	parent.add_child(walker)
	walker.owner = scene_root
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.86
	walker.add_child(collision)
	collision.owner = scene_root
	var human := Node3D.new()
	human.name = "HumanCharacter"
	human.set_script(HumanCharacterScript)
	var seed_value: int = absi(name.hash())
	var appearance := AppearanceGenerator.generate(seed_value, preload("res://characters/resources/civilian_profile.tres"))
	appearance.clothing_colors[&"top"] = clothes
	human.set("appearance", appearance)
	human.set("npc_seed", seed_value)
	walker.add_child(human)
	human.owner = scene_root

func build_scene() -> void:
	scene_root = Node3D.new()
	scene_root.name = "PrologueCommute"
	scene_root.set_script(FoundationRoomScript)
	scene_root.set("title_key", &"PRO_COMMUTE_TITLE")

	var env_node := WorldEnvironment.new()
	env_node.name = "MorningEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("8297a4")
	sky_mat.sky_horizon_color = Color("d5cbbb")
	sky_mat.ground_bottom_color = Color("565d59")
	sky_mat.ground_horizon_color = Color("b7afa1")
	sky_mat.sun_angle_max = 22.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.48
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.25
	env_node.environment = env
	scene_root.add_child(env_node)
	env_node.owner = scene_root
	var sun := DirectionalLight3D.new()
	sun.name = "MorningSun"
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color("ffe0b6")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65.0
	scene_root.add_child(sun)
	sun.owner = scene_root

	var entrance := Marker3D.new()
	entrance.name = "RoomEntrance"
	entrance.position = Vector3(0, 0, 3)
	entrance.set_script(RoomEntranceScript)
	entrance.set("entrance_id", &"default")
	scene_root.add_child(entrance)
	entrance.owner = scene_root
	var markers := {
		"WaterVending": [Vector3(3.26, 0.9, -11.0), "prologue_action", "buy_water"],
		"NoclipPoint": [Vector3(8.0, 0.0, -20.0), "prologue_trigger", "noclip"],
		"QuietPoint": [Vector3(1.0, 1.0, -9.0), "prologue_trigger", "quiet"],
		"HumPoint": [Vector3(0.0, 1.0, -12.0), "prologue_trigger", "hum"],
	}
	for marker_name: String in markers:
		var marker := Marker3D.new()
		marker.name = marker_name
		marker.position = markers[marker_name][0]
		marker.set_meta(markers[marker_name][1], markers[marker_name][2])
		scene_root.add_child(marker)
		marker.owner = scene_root

	var geo := Node3D.new()
	geo.name = "EnvironmentGeometry"
	scene_root.add_child(geo)
	geo.owner = scene_root
	var concrete := mat("SidewalkConcrete", Color("777873"), 0.94)
	var asphalt := mat("RoadAsphalt", Color("303433"), 0.98)
	var curb := mat("CurbConcrete", Color("9a978d"), 0.93)
	add_box(geo, "WalkableGround", Vector3(0, -0.14, -10), Vector3(9.5, 0.28, 37), terrazzo(), true)
	add_box(geo, "RoadLeft", Vector3(-8.3, -0.22, -10), Vector3(6.5, 0.24, 42), asphalt)
	add_box(geo, "RoadRight", Vector3(9.3, -0.22, -7), Vector3(8.0, 0.24, 44), asphalt)
	add_box(geo, "LeftCurb", Vector3(-4.9, 0.02, -9), Vector3(0.35, 0.28, 39), curb, true)
	# Keep the authored right turn open for the full player capsule, including curb collision.
	add_box(geo, "RightCurbNorth", Vector3(4.9, 0.02, -7.0), Vector3(0.35, 0.28, 22.0), curb, true)
	add_box(geo, "RightCurbSouth", Vector3(4.9, 0.02, -25.0), Vector3(0.35, 0.28, 6.0), curb, true)
	for z in [-23.5, -18.0, -12.5, -7.0, -1.5, 4.0]:
		add_box(geo, "PavingJoint", Vector3(0, 0.008, z), Vector3(9.2, 0.012, 0.022), mat("Joint", Color("5d625e"), 0.98))
	add_box(geo, "DrainLine", Vector3(-4.55, 0.018, -9), Vector3(0.10, 0.016, 36), mat("DrainStain", Color("46504a"), 0.99))
	for patch_data in [[Vector3(-2.6, 0.011, -4.0), Vector3(1.4, 0.012, 2.7)], [Vector3(2.2, 0.011, -14.0), Vector3(1.1, 0.012, 3.2)], [Vector3(-1.1, 0.011, -21.5), Vector3(1.8, 0.012, 1.2)]]:
		add_box(geo, "WornPaving", patch_data[0], patch_data[1], mat("WornTerrazzo", Color("777971"), 0.97))

	# Residential glass-door lobby at the starting end.
	add_box(geo, "LobbyFloor", Vector3(0, 0.02, 5.35), Vector3(6.2, 0.12, 4.5), terrazzo(), true)
	add_box(geo, "LobbyLeftWall", Vector3(-3.0, 1.65, 5.2), Vector3(0.25, 3.3, 4.7), plaster(), true)
	add_box(geo, "LobbyRightWall", Vector3(3.0, 1.65, 5.2), Vector3(0.25, 3.3, 4.7), plaster(), true)
	add_box(geo, "LobbyCeiling", Vector3(0, 3.25, 5.2), Vector3(6.2, 0.20, 4.7), plaster())
	var glass := mat("LobbyGlass", Color("718c91"), 0.22, 0.05)
	add_box(geo, "GlassDoorLeft", Vector3(-0.78, 1.15, 2.94), Vector3(1.45, 2.3, 0.06), glass)
	add_box(geo, "GlassDoorRight", Vector3(0.78, 1.15, 2.94), Vector3(1.45, 2.3, 0.06), glass)
	for x in [-1.55, 0.0, 1.55]:
		add_box(geo, "DoorMullion", Vector3(x, 1.25, 2.90), Vector3(0.08, 2.5, 0.12), mat("DarkMetal", Color("343b3c"), 0.55, 0.65))
	add_box(geo, "DoorLintel", Vector3(0, 2.45, 2.90), Vector3(3.25, 0.10, 0.12), mats["DarkMetal"])
	add_label(geo, "LobbyNotice", "文明楼道  随手关门", Vector3(-2.82, 1.55, 4.7), PI * 0.5, 36, Color("d8d4c4"))

	# Planters and ordinary protective railings define the playable strip.
	for side in [-1.0, 1.0]:
		for z in [-3.0, -8.0, -15.5]:
			var x: float = side * 4.15
			add_box(geo, "Planter", Vector3(x, 0.36, z), Vector3(1.05, 0.72, 2.2), mat("PlanterBrick", Color("765c4b"), 0.93), true)
			add_box(geo, "PlanterSoil", Vector3(x, 0.74, z), Vector3(0.86, 0.08, 1.95), mat("Soil", Color("3d3328"), 1.0))
			var branch_mat := mat("ShrubBranch", Color("554638"), 0.96)
			for plant_i in range(2):
				var plant_z: float = z - 0.42 + plant_i * 0.84
				var lean: float = -0.16 if plant_i == 0 else 0.13
				add_capsule(geo, "ShrubBranch", Vector3(x, 1.02, plant_z), 0.035, 0.66, branch_mat, Vector3(lean, 0, lean * 0.6))
				add_capsule(geo, "ShrubTwig", Vector3(x + lean * 0.5, 1.22, plant_z + 0.12), 0.025, 0.42, branch_mat, Vector3(0.55, 0.2, lean))
				add_leaf_cluster(geo, "LeafCluster", Vector3(x, 1.27, plant_z), plant_i + int((z + 16.0) * 2.0))
	for side in [-1.0, 1.0]:
		var x: float = side * 4.72
		for z in range(-25, 2, 3):
			if side > 0.0 and z >= -22 and z <= -19:
				continue
			add_cylinder(geo, "RailPost", Vector3(x, 0.48, z), 0.045, 0.96, mats["DarkMetal"], 8)
		if side < 0.0:
			add_box(geo, "RailTop", Vector3(x, 0.88, -12), Vector3(0.07, 0.07, 27), mats["DarkMetal"], true)
			add_box(geo, "RailMid", Vector3(x, 0.48, -12), Vector3(0.055, 0.055, 27), mats["DarkMetal"])
		else:
			add_box(geo, "RailTopNorth", Vector3(x, 0.88, -8.5), Vector3(0.07, 0.07, 19.0), mats["DarkMetal"], true)
			add_box(geo, "RailMidNorth", Vector3(x, 0.48, -8.5), Vector3(0.055, 0.055, 19.0), mats["DarkMetal"])
			add_box(geo, "RailTopSouth", Vector3(x, 0.88, -24.0), Vector3(0.07, 0.07, 4.0), mats["DarkMetal"], true)
			add_box(geo, "RailMidSouth", Vector3(x, 0.48, -24.0), Vector3(0.055, 0.055, 4.0), mats["DarkMetal"])

	# Six-storey residential slabs with windows, sills, awnings and external AC units.
	add_box(geo, "LeftApartmentBlock", Vector3(-10.3, 8.0, -8), Vector3(10.0, 16.0, 34), plaster())
	add_box(geo, "RightApartmentBlock", Vector3(11.5, 8.0, 1), Vector3(12.0, 16.0, 22), mat("AgedPlaster", Color("a9a397"), 0.95))
	add_window_grid(geo, "Left", -5.28, -9.0, true)
	add_window_grid(geo, "Right", 5.46, -1.0, true)

	# Convenience store frontage and water vending cabinet.
	add_box(geo, "ShopFront", Vector3(5.35, 1.8, -12), Vector3(0.35, 3.6, 8.2), mat("ShopTile", Color("c8c0ab"), 0.84), true)
	add_box(geo, "ShopAwning", Vector3(4.55, 2.8, -12), Vector3(1.7, 0.18, 7.7), mat("Awning", Color("566c69"), 0.78, 0.1))
	add_box(geo, "ShopWindow", Vector3(5.12, 1.4, -13.3), Vector3(0.08, 2.3, 3.1), mat("ShopGlass", Color("465d61"), 0.3))
	for shelf_y in [0.65, 1.15, 1.65]:
		add_box(geo, "ShopShelf", Vector3(4.99, shelf_y, -13.3), Vector3(0.08, 0.07, 2.75), mat("ShelfMetal", Color("4a4d49"), 0.72, 0.35))
	for item_i in range(8):
		var item_z := -14.35 + item_i * 0.30
		var item_color := Color("9b6f4e") if item_i % 3 == 0 else (Color("81906d") if item_i % 3 == 1 else Color("b09c68"))
		add_box(geo, "ShopProduct", Vector3(4.93, 0.89 + (item_i % 2) * 0.5, item_z), Vector3(0.08, 0.28, 0.18), mat("Product%d" % (item_i % 3), item_color, 0.86))
	add_box(geo, "ShopDoor", Vector3(5.10, 1.15, -9.6), Vector3(0.09, 2.3, 1.1), mat("ShopDoor", Color("303b3b"), 0.45))
	add_label(geo, "ShopSign", "社区便利店", Vector3(4.34, 3.25, -12), -PI * 0.5, 62, Color("f0d8a2"))
	add_box(geo, "WaterCabinet", Vector3(4.10, 0.95, -11.0), Vector3(0.72, 1.9, 1.02), mat("VendingBlue", Color("617c83"), 0.58, 0.15), true)
	add_box(geo, "WaterDisplay", Vector3(3.72, 1.27, -11.0), Vector3(0.025, 0.34, 0.55), mat("DisplayDark", Color("182725"), 0.32))
	add_label(geo, "WaterText", "售水  饮用水", Vector3(3.68, 1.64, -11.0), -PI * 0.5, 28, Color("dce8d8"))
	for bottle_i in range(3):
		var bottle := add_cylinder(geo, "BottleSlot", Vector3(3.70, 0.72, -11.25 + bottle_i * 0.25), 0.055, 0.28, mat("Bottle", Color("9eb7b3"), 0.33), 10)
		bottle.rotation.z = PI * 0.5
	add_box(geo, "BottleChute", Vector3(3.70, 0.36, -11.0), Vector3(0.03, 0.20, 0.48), mats["DisplayDark"])

	# Bus stop and restrained period advertising.
	add_box(geo, "BusStopPanel", Vector3(-4.2, 1.25, -17.0), Vector3(0.12, 2.5, 2.9), mat("BusFrame", Color("435354"), 0.62, 0.45))
	add_box(geo, "BusAd", Vector3(-4.12, 1.28, -17.0), Vector3(0.025, 1.9, 2.25), mat("AdPaper", Color("b9ab83"), 0.89))
	add_label(geo, "BusStopText", "社区路口\n首班 06:20", Vector3(-4.03, 1.35, -17), PI * 0.5, 30, Color("252c2d"))
	add_box(geo, "BusBench", Vector3(-3.55, 0.48, -17.0), Vector3(1.2, 0.09, 2.4), mats["DarkMetal"])

	# Right turn into a plain underpass/service arcade, giving the route a clear end.
	add_box(geo, "TurnGround", Vector3(8.2, -0.10, -20), Vector3(7.0, 0.20, 4.0), concrete, true)
	add_box(geo, "UnderpassFarWall", Vector3(8.2, 1.65, -22.0), Vector3(7.0, 3.3, 0.25), plaster(), true)
	add_box(geo, "UnderpassCeiling", Vector3(8.2, 3.25, -20), Vector3(7.0, 0.22, 4.2), mat("UnderpassConcrete", Color("85867e"), 0.96))
	add_box(geo, "UnderpassEndShade", Vector3(11.55, 1.6, -20), Vector3(0.18, 3.2, 4.0), mat("DeepShade", Color("252b2a"), 0.98), true)
	for x in [6.0, 8.0, 10.0]:
		add_box(geo, "CeilingFixture", Vector3(x, 3.08, -20), Vector3(0.75, 0.08, 0.16), mat("Fixture", Color("d9d2b8"), 0.72))

	# Invisible full-height limits reinforce the low decorative railings and the
	# open ends of authored ground. The gap at x=4.8, z=-20 remains the intended
	# right turn into the noclip route.
	add_boundary(geo, "BoundaryStreetLeft", Vector3(-4.86, 2.0, -12.75), Vector3(0.18, 4.0, 31.5))
	add_boundary(geo, "BoundaryStreetRightNorth", Vector3(4.86, 2.0, -7.5), Vector3(0.18, 4.0, 21.0))
	add_boundary(geo, "BoundaryStreetRightSouth", Vector3(4.86, 2.0, -25.25), Vector3(0.18, 4.0, 6.5))
	add_boundary(geo, "BoundaryStreetNorth", Vector3(0.0, 2.0, 7.58), Vector3(6.2, 4.0, 0.18))
	add_boundary(geo, "BoundaryStreetSouth", Vector3(0.0, 2.0, -28.58), Vector3(9.72, 4.0, 0.18))

	# A final block closes the skyline so the authored street does not dissolve into an empty plane.
	add_box(geo, "EndBackgroundBlock", Vector3(0, 6.0, -34.0), Vector3(25.0, 12.0, 3.0), mat("DistantWall", Color("777b76"), 0.95))
	for x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		for y in [2.6, 5.6, 8.6]:
			add_box(geo, "DistantWindow", Vector3(x, y, -32.46), Vector3(1.35, 1.05, 0.06), mat("DistantWindowMat", Color("334045"), 0.53))

	add_car(geo, "WhiteSedan", Vector3(9.0, 0.0, -14.8), Color("b7b6ae"), 0.08)
	add_car(geo, "BlueTaxi", Vector3(9.5, 0.0, -25.5), Color("405b63"), -0.08)
	add_car(geo, "DistantVan", Vector3(7.2, 0.0, -29.0), Color("8c8a7c"), 0.03)
	# Background walkers stay in the side lanes and never cross the player's
	# centre-line route or the authored right turn at z=-20.
	add_person(geo, "DistantCommuterA", Vector3(-2.55, 0.02, -25.5), Color("53606a"), PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 11.5)]), 0.82, 0.2)
	add_person(geo, "DistantCommuterB", Vector3(2.8, 0.02, -26.0), Color("746653"), PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 3.3)]), 1.03, 1.45)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/prologue"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/prologue/commute"))
	var packed := PackedScene.new()
	var result := packed.pack(scene_root)
	if result != OK:
		push_error("Failed to pack commute scene: %s" % result)
		return
	result = ResourceSaver.save(packed, OUTPUT)
	if result != OK:
		push_error("Failed to save commute scene: %s" % result)
	else:
		print("COMMUTE_SCENE_SAVED %s" % OUTPUT)
		validate_packed_scene()
	if "--render" not in OS.get_cmdline_user_args():
		scene_root.free()
		scene_root = null


func validate_packed_scene() -> void:
	var packed: PackedScene = load(OUTPUT)
	var instance := packed.instantiate()
	var mesh_count := instance.find_children("*", "MeshInstance3D", true, false).size()
	var static_body_count := instance.find_children("*", "StaticBody3D", true, false).size()
	var entrance := instance.get_node_or_null("RoomEntrance")
	var water := instance.get_node_or_null("WaterVending")
	var noclip := instance.get_node_or_null("NoclipPoint")
	var quiet := instance.get_node_or_null("QuietPoint")
	var hum := instance.get_node_or_null("HumPoint")
	var walker_a := instance.get_node_or_null("EnvironmentGeometry/DistantCommuterA")
	var walker_b := instance.get_node_or_null("EnvironmentGeometry/DistantCommuterB")
	assert(instance.get("title_key") == &"PRO_COMMUTE_TITLE")
	assert(entrance != null and entrance.get("entrance_id") == &"default")
	assert(water != null and water.get_meta("prologue_action") == "buy_water")
	assert(water.position == Vector3(3.26, 0.9, -11.0))
	assert(noclip != null and noclip.position == Vector3(8, 0, -20) and noclip.get_meta("prologue_trigger") == "noclip")
	assert(quiet != null and quiet.get_meta("prologue_trigger") == "quiet")
	assert(hum != null and hum.get_meta("prologue_trigger") == "hum")
	assert(walker_a is AmbientWalker and walker_b is AmbientWalker)
	assert(walker_a.get("walk_speed") >= 0.75 and walker_a.get("walk_speed") <= 1.1)
	assert(walker_b.get("walk_speed") >= 0.75 and walker_b.get("walk_speed") <= 1.1)
	assert(walker_a.get("initial_wait_seconds") != walker_b.get("initial_wait_seconds"))
	assert(walker_a.collision_layer == 8 and walker_a.collision_mask == 11)
	assert(walker_b.collision_layer == 8 and walker_b.collision_mask == 11)
	assert(mesh_count < 500)
	print("COMMUTE_VALIDATED meshes=%d static_bodies=%d markers=5" % [mesh_count, static_body_count])
	instance.free()


func validate_walk_route() -> void:
	var packed: PackedScene = load(OUTPUT)
	var instance := packed.instantiate()
	get_root().add_child(instance)
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.62
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.margin = 0.01
	var route: Array[Vector3] = []
	for z_step in range(3, -21, -1):
		route.append(Vector3(0, 1.05, float(z_step)))
	for x_step in range(1, 9):
		route.append(Vector3(float(x_step), 1.05, -20.0))
	for route_point in route:
		query.transform = Transform3D(Basis.IDENTITY, route_point)
		var hits: Array[Dictionary] = instance.get_world_3d().direct_space_state.intersect_shape(query, 8)
		assert(hits.is_empty(), "Commute route blocked at %s by %s" % [route_point, hits])
	print("COMMUTE_ROUTE_VALIDATED entrance_to_noclip samples=%d" % route.size())
	instance.free()


func render_preview() -> void:
	if scene_root != null:
		scene_root.free()
		scene_root = null
	var packed: PackedScene = load(OUTPUT)
	var scene := packed.instantiate()
	get_root().add_child(scene)
	var camera := Camera3D.new()
	camera.position = Vector3(0.2, 1.65, 1.9)
	camera.rotation_degrees = Vector3(-4.0, 1.0, 0.0)
	camera.fov = 68.0
	camera.current = true
	scene.add_child(camera)
	var viewport := get_root()
	viewport.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(PREVIEW))
	print("COMMUTE_PREVIEW_SAVED %s" % PREVIEW)
	scene.free()

