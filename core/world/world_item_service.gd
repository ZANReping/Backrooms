class_name WorldItemService
extends Node3D

signal notice_requested(key: StringName)

var inventory: InventoryModel
var world: WorldData
var catalog: ItemCatalog
var level_id: StringName
var _proxies: Dictionary[String, PickupInteractable] = {}


func configure(model: InventoryModel, data: WorldData, definitions: ItemCatalog) -> void:
	inventory = model
	world = data
	catalog = definitions


func enter_room(room: FoundationRoom, id: StringName) -> void:
	for proxy: PickupInteractable in _proxies.values():
		remove_child(proxy)
		proxy.queue_free()
	_proxies.clear()
	level_id = id
	if not world.initialized_rooms.has(id):
		world.initialized_rooms.append(id)
		for spawn: ItemSpawn in room.get_item_spawns():
			var item: ItemInstance = inventory.add_item(catalog.find(spawn.definition_id))
			if item != null:
				world.world_items[item.uid] = {"level_id": String(id), "transform": spawn.global_transform}
	refresh()


func refresh() -> void:
	for uid: String in _proxies.keys():
		if not world.world_items.has(uid) or inventory.is_owned(uid):
			var proxy: PickupInteractable = _proxies[uid]
			remove_child(proxy)
			proxy.queue_free()
			_proxies.erase(uid)
	for uid: String in world.world_items:
		var row: Dictionary = world.world_items[uid]
		if StringName(row["level_id"]) != level_id or _proxies.has(uid) or inventory.is_owned(uid):
			continue
		var item: ItemInstance = inventory.get_item(uid)
		if item == null:
			continue
		var proxy: PickupInteractable = PickupInteractable.new()
		proxy.name = "Item_" + uid
		proxy.item = item
		proxy.collision_layer = 4
		proxy.collision_mask = 3
		proxy.add_child(ItemVisual.create(item.definition))
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = item.definition.world_size.max(Vector3(0.14, 0.14, 0.14))
		collision.shape = shape
		proxy.add_child(collision)
		add_child(proxy)
		proxy.global_transform = row["transform"]
		_proxies[uid] = proxy


func pickup(uid: String) -> bool:
	if not world.world_items.has(uid) or StringName(world.world_items[uid]["level_id"]) != level_id:
		return false
	var item: ItemInstance = inventory.get_item(uid)
	if item == null or inventory.is_owned(uid):
		return false
	var accepted: bool = false
	if item.definition.equip_slots.has(&"back") and inventory.get_back_container().is_empty():
		accepted = inventory.equip(uid, &"back")
	elif not inventory.get_back_container().is_empty():
		accepted = inventory.auto_place(uid, inventory.get_back_container())
	elif inventory.equipment.get(&"primary_hand", "").is_empty():
		accepted = inventory.equip(uid, &"primary_hand")
	if not accepted:
		notice_requested.emit(&"ERR_NO_SPACE")
		return false
	world.world_items.erase(uid)
	refresh()
	notice_requested.emit(&"NOTICE_PICKED_UP")
	return true


func drop(uid: String, at: Transform3D) -> bool:
	if not inventory.is_owned(uid) or not DataValidation.safe_transform(at):
		return false
	if not inventory.drop(uid):
		return false
	world.world_items[uid] = {"level_id": String(level_id), "transform": at}
	refresh()
	return true


func find_drop_transform(uid: String, player: PlayerController) -> Transform3D:
	var item: ItemInstance = inventory.get_item(uid)
	var start: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.global_basis.z
	var end: Vector3 = start + forward * 0.85
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 5, [player.get_rid()])
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var obstacle: Dictionary = space.intersect_ray(query)
	if not obstacle.is_empty():
		end = Vector3(obstacle["position"]) - forward * (item.definition.world_size.z * 0.5 + 0.12)
	query.from = end
	query.to = end + Vector3.DOWN * 4.0
	var floor_hit: Dictionary = space.intersect_ray(query)
	if not floor_hit.is_empty():
		end = Vector3(floor_hit["position"]) + Vector3.UP * (item.definition.world_size.y * 0.5 + 0.01)
	else:
		end.y = player.global_position.y + item.definition.world_size.y * 0.5
	return Transform3D(Basis.IDENTITY, end)
