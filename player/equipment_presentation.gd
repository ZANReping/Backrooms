class_name EquipmentPresentation
extends Node

var inventory: InventoryModel
var player: PlayerController
var torch: SpotLight3D
var _mounts: Dictionary[StringName, Node3D] = {}
var _pickup_remaining: float = 0.0


func suppress_primary_for_pickup(duration: float = 0.75) -> void:
	_pickup_remaining = maxf(_pickup_remaining, duration)
	_apply_primary_visibility()


func _process(delta: float) -> void:
	if _pickup_remaining > 0.0:
		_pickup_remaining = maxf(0.0, _pickup_remaining - delta)
		if _pickup_remaining <= 0.0:
			_apply_primary_visibility()


func _apply_primary_visibility() -> void:
	var mount: Node3D = _mounts.get(&"primary_hand")
	if is_instance_valid(mount):
		# Hide the item only. The hand and the mode-owned mount remain independent.
		for child: Node in mount.get_children():
			if child is Node3D:
				(child as Node3D).visible = _pickup_remaining <= 0.0
	update_light()


func configure(actor: PlayerController, model: InventoryModel) -> void:
	if inventory != null and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)
	inventory = model
	player = actor
	if _mounts.is_empty():
		_mounts[&"back"] = player.back_mount
		_mounts[&"primary_hand"] = player.primary_hand_mount
		_mounts[&"secondary_hand"] = player.secondary_hand_mount
		torch = SpotLight3D.new()
		torch.spot_range = 12.0
		torch.spot_angle = 32.0
		torch.light_energy = 3.0
		torch.shadow_enabled = false
		player.camera.add_child(torch)
	inventory.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for slot: StringName in _mounts:
		var mount: Node3D = _mounts[slot]
		for child: Node in mount.get_children():
			mount.remove_child(child)
			child.queue_free()
		var item: ItemInstance = inventory.get_item(inventory.equipment.get(slot, ""))
		if item != null:
			mount.add_child(ItemVisual.create(item.definition))
	_apply_primary_visibility()
	update_light()


func update_light() -> void:
	if torch == null:
		return
	torch.visible = false
	for item: ItemInstance in active_flashlights():
		if _pickup_remaining <= 0.0 or inventory.equipment.get(&"secondary_hand", "") == item.uid:
			torch.visible = true


func active_flashlights() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for slot: StringName in [&"primary_hand", &"secondary_hand"]:
		var item: ItemInstance = inventory.get_item(inventory.equipment.get(slot, ""))
		if item != null and item.definition.use_action == &"flashlight" and item.charge.current > 0.0 and bool(item.custom_flags.get("enabled", false)):
			result.append(item)
	return result
