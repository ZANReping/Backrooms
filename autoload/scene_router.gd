extends Node

signal travel_started(level_id: StringName)
signal travel_finished(level_id: StringName)
signal travel_failed(message_key: StringName)

var catalog: RouteCatalog
var current_room: FoundationRoom
var current_id: StringName
var current_entrance: StringName = &"default"
var busy: bool = false
var _host: Node3D


func configure(host: Node3D, routes: RouteCatalog) -> void:
	_host = host
	catalog = routes


func travel_to(level_id: StringName, entrance_id: StringName = &"default") -> bool:
	if busy or _host == null or catalog == null:
		return false
	var route: RouteDefinition = catalog.find(level_id)
	if route == null or route.scene_path.is_empty() or not ResourceLoader.exists(route.scene_path, "PackedScene"):
		travel_failed.emit(&"ERR_ROUTE")
		return false
	busy = true
	travel_started.emit(level_id)
	var error: Error = ResourceLoader.load_threaded_request(route.scene_path, "PackedScene")
	if error != OK:
		return _fail()
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(route.scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(route.scene_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return _fail()
	var packed: PackedScene = ResourceLoader.load_threaded_get(route.scene_path) as PackedScene
	if packed == null:
		return _fail()
	var node: Node = packed.instantiate()
	var candidate: FoundationRoom = node as FoundationRoom
	if candidate == null:
		node.free()
		return _fail()
	if candidate.get_entrance(entrance_id) == null:
		candidate.free()
		return _fail()
	# Only release old content once the requested scene and entrance are valid.
	if is_instance_valid(current_room):
		_host.remove_child(current_room)
		current_room.queue_free()
	current_room = candidate
	_host.add_child(current_room)
	current_id = level_id
	current_entrance = entrance_id
	busy = false
	travel_finished.emit(level_id)
	return true


func reload_current_level() -> bool:
	return await travel_to(current_id, current_entrance)


func _fail() -> bool:
	busy = false
	travel_failed.emit(&"ERR_ROUTE")
	return false
