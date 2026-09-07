extends SceneTree


func _initialize() -> void:
	var directory: String = "res://resources/prologue/items/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var catalog: ItemCatalog = ItemCatalog.new()
	var original: ItemCatalog = load("res://resources/items/catalog.tres") as ItemCatalog
	var model_names: Dictionary[StringName, String] = {&"commuter_bag": "backpack", &"phone": "phone", &"water": "water_bottle"}
	for source: ItemDefinition in original.definitions:
		var definition: ItemDefinition = source.duplicate(true)
		if model_names.has(source.id):
			_visual(definition, model_names[source.id])
			if source.id == &"commuter_bag":
				definition.world_size = Vector3(0.30, 0.43, 0.17)
			elif source.id == &"phone":
				definition.world_size = Vector3(0.081, 0.146, 0.009)
			else:
				definition.world_size = Vector3(0.065, 0.225, 0.065)
		assert(ResourceSaver.save(definition, directory + String(source.id) + ".tres") == OK)
		catalog.definitions.append(definition)
	for id: StringName in [&"work_laptop", &"keys", &"wallet"]:
		var item: ItemDefinition = ItemDefinition.new()
		item.id = id
		item.display_name = "PRO_ITEM_" + String(id).to_upper()
		item.description_key = StringName(item.display_name + "_DESC")
		item.frontrooms_keepsake = true
		item.weight_kg = 2.7 if id == &"work_laptop" else (0.16 if id == &"wallet" else 0.08)
		item.inventory_shape.clear()
		var dimensions: Vector2i = Vector2i(4, 3) if id == &"work_laptop" else Vector2i(2, 1)
		for y: int in dimensions.y:
			for x: int in dimensions.x:
				item.inventory_shape.append(Vector2i(x, y))
		item.world_size = Vector3(0.36, 0.022, 0.25) if id == &"work_laptop" else Vector3(0.11, 0.025, 0.085)
		_visual(item, "laptop" if id == &"work_laptop" else String(id))
		if id == &"work_laptop":
			for flag: StringName in [&"frontrooms", &"arrived", &"survived"]:
				var rule: ItemDescriptionRule = ItemDescriptionRule.new()
				rule.required_world_flag = StringName("laptop_" + String(flag))
				rule.text_key = StringName("PRO_LAPTOP_" + String(flag).to_upper())
				item.description_rules.append(rule)
		assert(item.is_valid())
		assert(ResourceSaver.save(item, directory + String(id) + ".tres") == OK)
		catalog.definitions.append(item)
	assert(ResourceSaver.save(catalog, "res://resources/prologue/catalog.tres") == OK)
	var routes: RouteCatalog = RouteCatalog.new()
	var route_scenes: Dictionary[StringName, String] = {&"prologue_apartment": "apartment", &"prologue_commute": "commute", &"level0_arrival": "arrival"}
	for id: StringName in route_scenes:
		var route: RouteDefinition = RouteDefinition.new()
		route.id = id
		route.scene_path = "res://levels/prologue/" + route_scenes[id] + ".tscn"
		route.time_scale = 24.0 if id == &"level0_arrival" else 1.0
		routes.routes.append(route)
	# Legacy M1 routes remain loadable through the same composition root.
	var legacy: RouteCatalog = load("res://resources/world/test_routes.tres") as RouteCatalog
	for route: RouteDefinition in legacy.routes:
		routes.routes.append(route)
	assert(ResourceSaver.save(routes, "res://resources/prologue/routes.tres") == OK)
	print("PASS: prologue catalog and routes generated")
	quit()


func _visual(definition: ItemDefinition, model_name: String) -> void:
	definition.world_scene = load("res://art/prologue/props/" + model_name + ".tscn") as PackedScene
	definition.icon = load("res://assets/prologue/icons/" + model_name + ".png") as Texture2D
