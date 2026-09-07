extends SceneTree

## Offline, reproducible set dressing. Generated scenes contain editable static
## meshes, colliders and lights; the gameplay room does no procedural building.
const ROOT_PATH: String = "res://levels/prologue/"
const HingedDoorScript := preload("res://core/presentation/hinged_door.gd")
var room: FoundationRoom
var plaster: Material
var wood: StandardMaterial3D
var cream: StandardMaterial3D
var dark_wood: StandardMaterial3D
var metal: StandardMaterial3D
var fabric: StandardMaterial3D
var glass: StandardMaterial3D
var _serial: int = 0


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT_PATH))
	plaster = _surface("white_plaster_02", "white_plaster_02_diff_2k.jpg", Color(0.78, 0.77, 0.70), 0.14, 1.6, 0.10)
	wood = _pbr("wood_floor", "wood_floor_diff_2k.jpg", Color(0.73, 0.69, 0.62), 0.58)
	wood.uv1_scale = Vector3.ONE * 0.6
	cream = _mat(Color(0.65, 0.64, 0.56), 0.58)
	dark_wood = _mat(Color(0.16, 0.085, 0.042), 0.48)
	metal = _mat(Color(0.45, 0.47, 0.44), 0.32, 0.8)
	fabric = _pbr("fabric_pattern_07", "fabric_pattern_07_col_1_1k.jpg", Color(0.30, 0.34, 0.32), 0.92)
	glass = _mat(Color(0.41, 0.47, 0.46), 0.13, 0.45)
	_build_apartment()
	_build_arrival()
	print("PASS: apartment / arrival scenes generated")
	quit()


func _new_room(name_text: String, title: StringName) -> void:
	room = FoundationRoom.new()
	room.name = name_text
	room.title_key = title
	root.add_child(room)


func _build_apartment() -> void:
	_new_room("Apartment", &"PRO_APARTMENT_TITLE")
	_environment(false)
	_box("ParquetFloor", Vector3(8.2, 0.16, 7.4), Vector3(0, -0.08, 0), wood, true)
	_box("Ceiling", Vector3(8.2, 0.12, 7.4), Vector3(0, 2.74, 0), plaster, true)
	_wall("West", Vector3(-4.08, 1.35, 0), Vector3(0.16, 2.7, 7.4))
	_wall("South", Vector3(0, 1.35, 3.68), Vector3(8.2, 2.7, 0.16))
	# North wall has a real window opening. No light-occluding pane is placed in it.
	_wall("WindowApron", Vector3(0, 0.48, -3.68), Vector3(8.2, 0.96, 0.16))
	_wall("WindowHeader", Vector3(0, 2.6, -3.68), Vector3(8.2, 0.2, 0.16))
	_wall("NorthLeft", Vector3(-3.4, 1.73, -3.68), Vector3(1.4, 1.54, 0.16))
	_wall("NorthRight", Vector3(1.9, 1.73, -3.68), Vector3(4.4, 1.54, 0.16))
	# Keep the real window opening and exterior view, but prevent the player from
	# climbing or jumping through the non-playable facade.
	_boundary("BoundaryApartmentWindow", Vector3(-1.49, 1.83, -3.64), Vector3(2.52, 1.74, 0.12))
	_wall("EntryEastLong", Vector3(4.08, 1.35, -0.96), Vector3(0.16, 2.7, 5.28))
	_wall("EntryEastEnd", Vector3(4.08, 1.35, 3.16), Vector3(0.16, 2.7, 1.04))
	_wall("EntryLintel", Vector3(4.08, 2.43, 2.17), Vector3(0.16, 0.54, 1.02))
	for x: float in [-2.68, -1.49, -0.30]:
		_box("WindowUpright", Vector3(0.048, 1.58, 0.07), Vector3(x, 1.73, -3.59), cream)
	for y: float in [0.99, 1.81, 2.47]:
		_box("WindowRail", Vector3(2.46, 0.045, 0.07), Vector3(-1.49, y, -3.59), cream)
	_box("WindowSill", Vector3(2.58, 0.065, 0.29), Vector3(-1.49, 0.97, -3.52), cream)
	# Exterior is physical relief, not a black window rectangle.
	_exterior_view()
	_curtain(-2.87)
	_curtain(-0.1)
	_box("CurtainRail", Vector3(3.24, 0.024, 0.035), Vector3(-1.49, 2.56, -3.39), metal)
	_skirts()
	_bed()
	_study()
	_kitchen()
	_hallway()
	_misc_details()
	_entrance(Vector3(-1.80, 0.03, 1.35), 0.0)
	_spawn("PhoneOnBedside", &"phone", Vector3(-3.35, 0.57, -0.27), Vector3(-PI / 2.0, 0.1, 0))
	_spawn("WorkBag", &"commuter_bag", Vector3(0.45, 0.225, -2.5))
	_spawn("KeysOnCabinet", &"keys", Vector3(3.48, 0.91, 2.99), Vector3(-PI / 2.0, 0, 0))
	_spawn("WalletOnCabinet", &"wallet", Vector3(3.43, 0.91, 3.22))
	_action("BedroomAlarm", &"alarm", &"PRO_ALARM_STOP", Vector3(-3.35, 0.68, -0.27), Vector3(0.30, 0.17, 0.28))
	_save("apartment.tscn")


func _study() -> void:
	_import_prop("metal_office_desk", Vector3(-1.34, 0, -2.91), PI)
	_import_prop("plastic_monobloc_chair_01", Vector3(-1.0, 0.015, -1.82), 0.3)
	_import_prop("desk_lamp_arm_01", Vector3(-2.05, 0.77, -2.92), 0.7, 0.53)
	# Closed work laptop is seeded into the physical bag, not duplicated on a desk.
	_box("PaperStack", Vector3(0.22, 0.013, 0.29), Vector3(-0.58, 0.78, -3.03), _mat(Color(0.77, 0.75, 0.66), 0.9))
	for index: int in 5:
		_box("FileOnDesk", Vector3(0.018, 0.23, 0.18), Vector3(-2.17 + index * 0.028, 0.89, -3.17), _mat(Color(0.25 + index * 0.05, 0.27, 0.24), 0.8))
	_cylinder("CoffeeMug", 0.038, 0.095, Vector3(-0.5, 0.825, -2.74), _mat(Color(0.65, 0.67, 0.57), 0.25))
	_cylinder("ColdCoffee", 0.031, 0.002, Vector3(-0.5, 0.87, -2.74), _mat(Color(0.055, 0.027, 0.008), 0.14))
	_box("DeskCalendar", Vector3(0.16, 0.16, 0.024), Vector3(-1.86, 0.87, -3.16), cream)
	_label("CalendarPrint", "2026\n10 / 18   SUN", Vector3(-1.86, 0.882, -3.141), 0.0018, 22, Color(0.2, 0.22, 0.21))
	# A warm desk spill supplements bounced daylight, with no added shadow map.
	_omni("DeskBounce", Vector3(-1.45, 1.7, -2.7), Color(0.83, 0.87, 0.96), 0.7, 4.2)


func _bed() -> void:
	_box("BedBase", Vector3(1.50, 0.28, 2.04), Vector3(-3.08, 0.20, 1.5), dark_wood, true)
	_box("Mattress", Vector3(1.47, 0.16, 2.0), Vector3(-3.08, 0.42, 1.5), _mat(Color(0.61, 0.60, 0.52), 0.9))
	_box("Headboard", Vector3(1.52, 0.60, 0.075), Vector3(-3.08, 0.67, 2.56), dark_wood)
	# Folded bands and a sloping duvet edge catch daylight instead of a flat cuboid.
	for index: int in 8:
		var fold: MeshInstance3D = _box("DuvetFold", Vector3(1.5, 0.09, 0.18), Vector3(-3.08, 0.54 + sin(index * 0.7) * 0.025, 0.81 + index * 0.15), fabric)
		fold.rotation.z = sin(index) * 0.025
	_box("DuvetOverhang", Vector3(0.055, 0.27, 1.25), Vector3(-2.31, 0.4, 1.35), fabric)
	var pillow: MeshInstance3D = _box("Pillow", Vector3(0.63, 0.12, 0.40), Vector3(-3.02, 0.59, 2.10), _mat(Color(0.65, 0.65, 0.56), 0.95))
	pillow.rotation.y = -0.07
	_box("BedsideCabinet", Vector3(0.53, 0.52, 0.46), Vector3(-3.36, 0.26, -0.22), dark_wood, true)
	for y: float in [0.20, 0.40]:
		_box("DrawerSeam", Vector3(0.45, 0.009, 0.008), Vector3(-3.36, y, 0.015), metal)
		_box("DrawerPull", Vector3(0.10, 0.012, 0.024), Vector3(-3.36, y - 0.07, 0.025), metal)
	_box("BedsideMat", Vector3(0.28, 0.008, 0.30), Vector3(-3.36, 0.525, -0.24), fabric)
	for x: float in [-2.0, -1.77]:
		_box("Slipper", Vector3(0.115, 0.045, 0.255), Vector3(x, 0.027, 1.78), _mat(Color(0.27, 0.25, 0.21), 0.9))


func _kitchen() -> void:
	var cabinet: StandardMaterial3D = _mat(Color(0.48, 0.51, 0.43), 0.6)
	_box("KitchenBase", Vector3(2.1, 0.84, 0.62), Vector3(2.73, 0.42, -3.23), cabinet, true)
	_box("CounterStone", Vector3(2.18, 0.045, 0.70), Vector3(2.73, 0.87, -3.19), cream)
	for x: float in [1.93, 2.47, 3.01, 3.55]:
		_box("KitchenDoor", Vector3(0.50, 0.70, 0.025), Vector3(x, 0.44, -2.906), cabinet)
		_box("CupboardPull", Vector3(0.12, 0.012, 0.032), Vector3(x, 0.72, -2.875), metal)
	_box("SinkRim", Vector3(0.58, 0.016, 0.45), Vector3(2.85, 0.90, -3.17), metal)
	_box("SinkBasin", Vector3(0.47, 0.013, 0.35), Vector3(2.85, 0.908, -3.17), _mat(Color(0.14, 0.17, 0.15), 0.29, 0.7))
	_cylinder("TapUpright", 0.015, 0.26, Vector3(2.84, 1.04, -3.40), metal)
	_box("TapSpout", Vector3(0.028, 0.024, 0.19), Vector3(2.84, 1.16, -3.32), metal)
	_box("Fridge", Vector3(0.64, 1.67, 0.65), Vector3(3.58, 0.835, -1.83), _mat(Color(0.65, 0.65, 0.58), 0.45), true)
	_box("FridgeDoorSeam", Vector3(0.63, 0.012, 0.016), Vector3(3.58, 1.20, -1.498), metal)
	_box("FridgeHandle", Vector3(0.018, 0.33, 0.04), Vector3(3.34, 0.98, -1.475), cream)
	_box("FridgeNote", Vector3(0.14, 0.19, 0.003), Vector3(3.61, 1.0, -1.49), _mat(Color(0.69, 0.66, 0.48), 0.9))
	_label("ShoppingList", "牛奶\n鸡蛋\n洗衣液", Vector3(3.61, 1.015, -1.487), 0.00165, 18, Color(0.27, 0.26, 0.21))
	_box("UpperCupboard", Vector3(1.60, 0.57, 0.32), Vector3(2.55, 2.04, -3.43), cabinet)
	for x: float in [1.98, 2.4, 2.82, 3.24]:
		_box("UpperDoor", Vector3(0.39, 0.52, 0.018), Vector3(x, 2.04, -3.258), cabinet)
	_cylinder("RiceCooker", 0.12, 0.21, Vector3(1.96, 1.00, -3.12), cream)
	_cylinder("RiceCookerLid", 0.124, 0.03, Vector3(1.96, 1.12, -3.12), metal)
	_box("KitchenTowel", Vector3(0.24, 0.025, 0.28), Vector3(2.25, 0.91, -2.95), fabric)
	_box("DiningTable", Vector3(0.85, 0.04, 0.78), Vector3(1.26, 0.74, -0.1), wood, true)
	for x: float in [0.9, 1.62]:
		for z: float in [-0.42, 0.22]:
			_box("TableLeg", Vector3(0.045, 0.72, 0.045), Vector3(x, 0.36, z), dark_wood)
	_import_prop("plastic_monobloc_chair_01", Vector3(1.17, 0, 0.72), -0.1)
	_cylinder("BreakfastPlate", 0.11, 0.016, Vector3(1.19, 0.775, -0.04), cream)
	_box("Newspaper", Vector3(0.23, 0.005, 0.28), Vector3(1.4, 0.767, -0.13), _mat(Color(0.61, 0.60, 0.52), 0.9))


func _hallway() -> void:
	# A modest residential corridor with unique, mundane door numbers.
	_box("HallFloor", Vector3(2.42, 0.15, 10.6), Vector3(5.2, -0.075, -1.35), _pbr("terrazzo_tiles", "terrazzo_tiles_diff_2k.jpg", Color(0.58, 0.61, 0.56), 0.82), true)
	_box("HallCeiling", Vector3(2.42, 0.13, 10.6), Vector3(5.2, 2.67, -1.35), plaster, true)
	_box("HallOutsideWall", Vector3(0.16, 2.7, 10.6), Vector3(6.47, 1.35, -1.35), plaster, true)
	_box("HallEndWall", Vector3(2.42, 2.7, 0.15), Vector3(5.2, 1.35, 3.95), plaster, true)
	_box("HallEndReturn", Vector3(2.42, 2.7, 0.15), Vector3(5.2, 1.35, -6.65), plaster, true)
	_wall("HallInnerExtension", Vector3(4.08, 1.35, -4.3), Vector3(0.16, 2.7, 1.25))
	_wall("ExitLandingInnerWall", Vector3(4.08, 1.35, -5.78), Vector3(0.16, 2.7, 1.72))
	_hinged_door("ApartmentDoorMotion", Vector3(4.0, 0.0, 2.63), Vector3(0.052, 2.07, 0.92), Vector3(0.0, 1.04, -0.46), Vector3(-0.05, 1.03, -0.77), dark_wood, -90.0)
	for z: float in [-2.8, -0.1]:
		_box("NeighborDoor", Vector3(0.07, 2.06, 0.92), Vector3(6.35, 1.03, z), _mat(Color(0.21, 0.18, 0.14), 0.7))
		var label_node: Label3D = _label("DoorNumber", "302" if z < -1 else "303", Vector3(6.30, 1.78, z), 0.0026, 26, Color(0.54, 0.54, 0.47))
		label_node.rotation.y = -PI / 2.0
	for z: float in [-3.0, 1.7]:
		_box("HallLightHousing", Vector3(0.18, 0.055, 0.80), Vector3(5.2, 2.57, z), cream)
		_box("HallLightDiffuser", Vector3(0.13, 0.017, 0.69), Vector3(5.2, 2.535, z), _emissive(Color(0.86, 0.87, 0.73), 1.8))
		_omni("HallLight", Vector3(5.2, 2.36, z), Color(0.87, 0.88, 0.75), 0.7, 4.0)
	var exit_door: Node3D = _hinged_door("BuildingExitMotion", Vector3(4.55, 0.0, -4.79), Vector3(1.51, 2.06, 0.03), Vector3(0.755, 1.03, 0.0), Vector3(1.18, 1.03, 0.035), glass, 90.0)
	var exit_label: Label3D = _label("ExitLettering", "出  口", Vector3(5.31, 1.69, -4.75), 0.004, 22, Color(0.68, 0.71, 0.62))
	exit_label.reparent(exit_door.get_node("Pivot"), true)
	for x: float in [4.55, 6.09]:
		_box("ExitMullion", Vector3(0.045, 2.2, 0.06), Vector3(x, 1.1, -4.75), metal)
	_marker("ExitApproach", Vector3(5.32, 0.02, -3.55))
	_marker("ExitCrossing", Vector3(5.32, 0.02, -5.55))
	_box("MailBoxes", Vector3(0.17, 0.71, 1.2), Vector3(6.27, 1.1, 2.48), cream)
	for z: float in [2.05, 2.45, 2.85]:
		for y: float in [0.91, 1.24]:
			_box("MailSlot", Vector3(0.005, 0.023, 0.28), Vector3(6.177, y, z), dark_wood)


func _misc_details() -> void:
	_box("EntryCabinet", Vector3(0.62, 0.86, 0.78), Vector3(3.57, 0.43, 3.11), dark_wood, true)
	_box("EntryCabinetTop", Vector3(0.69, 0.028, 0.83), Vector3(3.57, 0.875, 3.11), cream)
	_box("Wardrobe", Vector3(1.18, 2.1, 0.58), Vector3(0.3, 1.05, 3.29), _mat(Color(0.40, 0.34, 0.25), 0.65), true)
	_box("WardrobeSeam", Vector3(0.006, 2.02, 0.013), Vector3(0.3, 1.07, 2.987), dark_wood)
	for x: float in [0.22, 0.38]:
		_box("WardrobePull", Vector3(0.013, 0.19, 0.03), Vector3(x, 1.08, 2.967), metal)
	for x: float in [-2.8, 0.8, 3.7]:
		_box("Socket", Vector3(0.077, 0.077, 0.015), Vector3(x, 0.35, -3.58), cream)
		for dx: float in [-0.012, 0.012]:
			_box("SocketHole", Vector3(0.004, 0.017, 0.003), Vector3(x + dx, 0.35, -3.57), dark_wood)
	_box("Switch", Vector3(0.015, 0.08, 0.075), Vector3(3.987, 1.32, 1.48), cream)
	_box("CeilingMount", Vector3(0.16, 0.045, 0.16), Vector3(0, 2.65, 0), cream)
	_cylinder("PendantShade", 0.19, 0.15, Vector3(0, 2.49, 0), cream)
	_omni("RoomBounce", Vector3(0.1, 2.2, 0.25), Color(0.88, 0.82, 0.65), 0.6, 5.0)
	_box("WallPicture", Vector3(0.68, 0.45, 0.027), Vector3(-1.15, 1.77, 3.574), dark_wood)
	_box("PicturePaper", Vector3(0.60, 0.38, 0.01), Vector3(-1.15, 1.77, 3.55), _mat(Color(0.53, 0.53, 0.41), 0.85))


func _skirts() -> void:
	for z: float in [-3.57, 3.57]:
		_box("Skirting", Vector3(8, 0.085, 0.03), Vector3(0, 0.046, z), dark_wood)
	_box("SkirtingWest", Vector3(0.03, 0.085, 7.1), Vector3(-3.97, 0.046, 0), dark_wood)
	_box("SkirtingEast", Vector3(0.03, 0.085, 5.2), Vector3(3.97, 0.046, -0.94), dark_wood)


func _curtain(x: float) -> void:
	var cloth: StandardMaterial3D = _pbr("fabric_pattern_07", "fabric_pattern_07_col_1_1k.jpg", Color(0.48, 0.48, 0.36), 0.95)
	for index: int in 9:
		_cylinder("CurtainFold", 0.039, 1.83, Vector3(x + index * 0.04 - 0.15, 1.61, -3.32 + sin(index * PI / 2.0) * 0.04), cloth)


func _exterior_view() -> void:
	var facade: StandardMaterial3D = _mat(Color(0.47, 0.50, 0.49), 0.88)
	_box("OppositeBuilding", Vector3(18, 18, 5), Vector3(-2, 0, -19), facade)
	for x: int in range(-8, 8, 3):
		for y: int in range(-6, 9, 3):
			_box("OppositeWindowFrame", Vector3(1.5, 1.5, 0.09), Vector3(x, y, -16.45), cream)
			_box("OppositeWindow", Vector3(1.37, 1.37, 0.03), Vector3(x, y, -16.37), glass)
			_box("OppositeWindowRail", Vector3(0.045, 1.37, 0.035), Vector3(x, y, -16.34), cream)
			_box("AirConditioner", Vector3(0.70, 0.43, 0.33), Vector3(x + 0.8, y - 1.02, -16.23), cream)


func _build_arrival() -> void:
	_new_room("Level0Arrival", &"PRO_ARRIVAL_TITLE")
	_environment(true)
	var paper: Material = _surface("decrepit_wallpaper", "decrepit_wallpaper_diff_2k.jpg", Color(0.78, 0.71, 0.44), 0.58, 0.65, 0.10)
	var carpet: Material = _surface("dirty_carpet", "dirty_carpet_diff_2k.jpg", Color(0.57, 0.50, 0.31), 0.60, 1.67, 0.20)
	var floor_node: MeshInstance3D = _box("DampCarpet", Vector3(18, 0.15, 20), Vector3(0, -0.075, -4), carpet, true)
	floor_node.get_child(0).set_meta("surface_id", &"carpet")
	_box("AcousticCeiling", Vector3(18, 0.12, 20), Vector3(0, 2.85, -4), plaster, true)
	for x: float in [-9, 9]:
		_box("OuterWall", Vector3(0.16, 2.85, 20), Vector3(x, 1.425, -4), paper, true)
	for z: float in [-14, 6]:
		_box("OuterWall", Vector3(18, 2.85, 0.16), Vector3(0, 1.425, z), paper, true)
	for entry: Vector3 in [Vector3(-2, 1.425, -2), Vector3(3.6, 1.425, -4.7), Vector3(-2.8, 1.425, -9.4), Vector3(6.4, 1.425, 0.5)]:
		_box("Partition", Vector3(0.24, 2.85, 5.4), entry, paper, true)
		_box("RubberSkirt", Vector3(0.27, 0.10, 5.43), Vector3(entry.x, 0.05, entry.z), dark_wood)
	for x: float in [-6, 0, 6]:
		for z: float in [-10, -4, 2]:
			_box("FluorescentTray", Vector3(1.24, 0.07, 0.35), Vector3(x, 2.74, z), cream)
			_box("FluorescentDiffuser", Vector3(1.15, 0.022, 0.29), Vector3(x, 2.692, z), _emissive(Color(0.80, 0.83, 0.65), 2.2))
			_omni("FluorescentSpill", Vector3(x, 2.44, z), Color(0.83, 0.83, 0.62), 1.05, 4.2)
	for x: float in range(-9, 10):
		_box("CeilingTBar", Vector3(0.014, 0.018, 20), Vector3(x, 2.775, -4), cream)
	for z: float in range(-14, 7):
		_box("CeilingTBar", Vector3(18, 0.018, 0.014), Vector3(0, 2.775, z), cream)
	_entrance(Vector3(0, 0.02, 2.6), 0.0)
	_save("arrival.tscn")


func _environment(arrival: bool) -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.name = "RoomEnvironment"
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.43, 0.55, 0.65)
	sky_mat.sky_horizon_color = Color(0.65, 0.66, 0.62)
	sky_mat.ground_horizon_color = Color(0.53, 0.54, 0.50)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.77, 0.79, 0.72) if arrival else Color(0.69, 0.75, 0.82)
	env.ambient_light_energy = 0.32 if arrival else 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.35
	env.ssao_intensity = 1.1
	env.ssil_enabled = true
	env.ssil_radius = 1.1
	env.ssil_intensity = 0.45
	env.glow_enabled = false
	environment_node.environment = env
	_add(environment_node)
	if not arrival:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.name = "OctoberSun"
		sun.rotation_degrees = Vector3(-28, -146, 0)
		sun.light_color = Color(1.0, 0.89, 0.72)
		sun.light_energy = 1.7
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 45.0
		sun.directional_shadow_blend_splits = true
		_add(sun)
	# These mostly rough surfaces use the environment reflection. A local box
	# probe created visible dark capture boundaries on the long partition walls.


func _surface(id: String, diffuse: String, tint: Color, amount: float, repeats: float, normal_strength: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://art/prologue/surfaces.gdshader") as Shader
	var base: String = "res://assets/third_party/polyhaven/textures/" + id + "/"
	material.set_shader_parameter("surface_color", load(base + diffuse))
	material.set_shader_parameter("surface_normal", load(base + id + "_nor_gl_1k.jpg"))
	material.set_shader_parameter("surface_arm", load(base + id + "_arm_1k.jpg"))
	material.set_shader_parameter("pigment", tint)
	material.set_shader_parameter("texture_amount", amount)
	material.set_shader_parameter("repeats_per_meter", repeats)
	material.set_shader_parameter("relief", normal_strength)
	material.set_shader_parameter("roughness_base", 0.91)
	return material


func _pbr(id: String, diffuse: String, tint: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _mat(tint, roughness)
	var base: String = "res://assets/third_party/polyhaven/textures/" + id + "/"
	material.albedo_texture = load(base + diffuse) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(base + id + "_nor_gl_1k.jpg") as Texture2D
	material.normal_scale = 0.65
	material.roughness_texture = load(base + id + "_arm_1k.jpg") as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = true
	material.ao_texture = material.roughness_texture
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _mat(color, 0.7)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _wall(label_text: String, pos: Vector3, dimensions: Vector3) -> void:
	_box(label_text, dimensions, pos, plaster, true)


func _boundary(label_text: String, pos: Vector3, dimensions: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = label_text
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	_add(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	body.add_child(shape_node)
	shape_node.owner = room


func _hinged_door(label_text: String, hinge: Vector3, dimensions: Vector3, leaf_center: Vector3, handle_position: Vector3, material: Material, angle: float) -> Node3D:
	var motion: Node3D = HingedDoorScript.new()
	motion.name = label_text
	motion.position = hinge
	motion.pivot_path = ^"Pivot"
	motion.handle_path = ^"Pivot/DoorHandle"
	motion.open_angle = angle
	motion.duration = 0.55
	_add(motion)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	motion.add_child(pivot)
	pivot.owner = room
	var leaf := MeshInstance3D.new()
	leaf.name = "ApartmentDoorLeaf" if label_text == "ApartmentDoorMotion" else "ExitGlass"
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = dimensions
	leaf.mesh = leaf_mesh
	leaf.material_override = material
	leaf.position = leaf_center
	pivot.add_child(leaf)
	leaf.owner = room
	var body := PrologueAction.new()
	body.name = "ApartmentDoor" if label_text == "ApartmentDoorMotion" else "BuildingExit"
	body.action_id = &"leave_apartment" if label_text == "ApartmentDoorMotion" else &"leave_building"
	body.prompt_key = &"PRO_LEAVE" if label_text == "ApartmentDoorMotion" else &"PRO_BUILDING_EXIT"
	body.collision_layer = 5
	body.collision_mask = 1
	body.position = leaf_center
	pivot.add_child(body)
	body.owner = room
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = dimensions
	collision.shape = box
	body.add_child(collision)
	collision.owner = room
	var handle := MeshInstance3D.new()
	handle.name = "DoorHandle"
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.05, 0.02, 0.13)
	handle.mesh = handle_mesh
	handle.material_override = metal
	handle.position = handle_position
	pivot.add_child(handle)
	handle.owner = room
	return motion


func _marker(label_text: String, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label_text
	marker.position = pos
	_add(marker)


func _box(label_text: String, dimensions: Vector3, pos: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	if not collision and dimensions.min_axis_index() >= 0 and dimensions[dimensions.min_axis_index()] > 0.06:
		instance.mesh = RoundedBoxMesh.create(dimensions, minf(0.024, dimensions[dimensions.min_axis_index()] * 0.22), 2)
	else:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = dimensions
		instance.mesh = mesh
	instance.material_override = material
	instance.name = label_text + str(_serial)
	_serial += 1
	instance.position = pos
	_add(instance)
	if collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Solid"
		instance.add_child(body)
		body.owner = room
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = dimensions
		shape_node.shape = shape
		body.add_child(shape_node)
		shape_node.owner = room
	return instance


func _cylinder(label_text: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	instance.mesh = mesh
	instance.material_override = material
	instance.name = label_text + str(_serial)
	_serial += 1
	instance.position = pos
	_add(instance)
	return instance


func _label(label_text: String, words: String, pos: Vector3, pixel: float, font_size: int, color: Color) -> Label3D:
	var node: Label3D = Label3D.new()
	node.name = label_text
	node.text = words
	node.position = pos
	node.pixel_size = pixel
	node.font_size = font_size
	node.outline_size = 0
	node.modulate = color
	node.no_depth_test = false
	node.shaded = true
	node.double_sided = false
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "sans-serif"])
	node.font = font
	_add(node)
	return node


func _omni(label_text: String, pos: Vector3, color: Color, energy: float, distance: float) -> void:
	var node: OmniLight3D = OmniLight3D.new()
	node.name = label_text + str(_serial)
	_serial += 1
	node.position = pos
	node.light_color = color
	node.light_energy = energy
	node.omni_range = distance
	node.omni_attenuation = 1.6
	node.shadow_enabled = false
	_add(node)


func _import_prop(id: String, pos: Vector3, yaw: float, scale_factor: float = 1.0) -> void:
	var path: String = "res://assets/third_party/polyhaven/models/%s/%s_1k.gltf" % [id, id]
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return
	var node: Node3D = packed.instantiate() as Node3D
	node.name = id + str(_serial)
	_serial += 1
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_factor
	_add(node)
	# Coarse primitives keep collision cheap and predictable.
	if id == "metal_office_desk":
		var collider: MeshInstance3D = _box("DeskCollision", Vector3(1.9, 0.76, 0.7), pos + Vector3(0, 0.38, 0), cream, true)
		collider.visible = false
	elif id == "plastic_monobloc_chair_01":
		var collider: MeshInstance3D = _box("ChairCollision", Vector3(0.5, 0.84, 0.5), pos + Vector3(0, 0.42, 0), cream, true)
		collider.visible = false


func _entrance(pos: Vector3, yaw: float) -> void:
	var node: RoomEntrance = RoomEntrance.new()
	node.name = "DefaultEntrance"
	node.entrance_id = &"default"
	node.position = pos
	node.rotation.y = yaw
	_add(node)


func _spawn(label_text: String, id: StringName, pos: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var node: ItemSpawn = ItemSpawn.new()
	node.name = label_text
	node.definition_id = id
	node.position = pos
	node.rotation = rotation
	_add(node)


func _action(label_text: String, id: StringName, prompt: StringName, pos: Vector3, dimensions: Vector3) -> void:
	var node: PrologueAction = PrologueAction.new()
	node.name = label_text
	node.action_id = id
	node.prompt_key = prompt
	node.position = pos
	node.collision_layer = 5 if id in [&"leave_apartment", &"leave_building"] else 4
	_add(node)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = dimensions
	shape.shape = box_shape
	node.add_child(shape)
	shape.owner = room


func _add(node: Node) -> void:
	room.add_child(node)
	node.owner = room


func _save(filename: String) -> void:
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(room) == OK)
	assert(ResourceSaver.save(packed, ROOT_PATH + filename) == OK)
	room.free()
