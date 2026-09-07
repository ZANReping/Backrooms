class_name InteractionContext
extends RefCounted

signal pickup_requested(uid: String)
signal travel_requested(level_id: StringName, entrance_id: StringName)
signal notice_requested(message_key: StringName)

var inventory: InventoryModel
