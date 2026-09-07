class_name ItemVisual
extends RefCounted


static func create(definition: ItemDefinition) -> Node3D:
	if definition.world_scene != null:
		var node: Node3D = definition.world_scene.instantiate() as Node3D
		if node != null:
			return node
	var root: Node3D = Node3D.new()
	var size: Vector3 = definition.world_size
	match definition.world_visual_fallback:
		&"bottle":
			_cylinder(root, size.x * 0.5, size.y * 0.8, Vector3.ZERO, definition.color)
			_cylinder(root, size.x * 0.28, size.y * 0.15, Vector3(0.0, size.y * 0.45, 0.0), Color(0.85, 0.86, 0.82))
		&"flashlight":
			_cylinder(root, size.x * 0.4, size.y * 0.8, Vector3.ZERO, definition.color)
			_cylinder(root, size.x * 0.55, size.y * 0.18, Vector3(0.0, size.y * 0.4, 0.0), Color(0.8, 0.82, 0.72))
		&"phone":
			_box(root, size, Vector3.ZERO, definition.color)
			_box(root, Vector3(size.x * 0.85, size.y * 0.84, 0.005), Vector3(0.0, 0.0, -size.z * 0.53), Color(0.08, 0.19, 0.22))
		&"bag", &"pouch":
			_box(root, size, Vector3.ZERO, definition.color)
			_box(root, Vector3(size.x * 0.65, size.y * 0.07, size.z * 0.25), Vector3(0.0, size.y * 0.59, 0.0), Color(0.12, 0.13, 0.12))
		&"tool":
			_box(root, Vector3(size.x * 0.25, size.y, size.z), Vector3.ZERO, definition.color)
			_box(root, Vector3(size.x, size.y * 0.25, size.z), Vector3(size.x * 0.3, size.y * 0.38, 0.0), definition.color)
		_:
			_box(root, size, Vector3.ZERO, definition.color)
	return root


static func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_add_mesh(parent, mesh, position, color)


static func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3, color: Color) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	_add_mesh(parent, mesh, position, color)


static func _add_mesh(parent: Node3D, mesh: Mesh, position: Vector3, color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	parent.add_child(instance)
