class_name FoundationRoom
extends Node3D

@export var title_key: StringName


func get_entrance(id: StringName) -> RoomEntrance:
	for node: Node in find_children("*", "Marker3D", true, false):
		if node is RoomEntrance and node.entrance_id == id:
			return node
	return null


func get_item_spawns() -> Array[ItemSpawn]:
	var result: Array[ItemSpawn] = []
	for node: Node in find_children("*", "Marker3D", true, false):
		if node is ItemSpawn:
			result.append(node)
	return result
