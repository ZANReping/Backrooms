class_name RoundedBoxMesh
extends RefCounted


static func create(size: Vector3, radius: float, segments: int = 3) -> ArrayMesh:
	var safe_radius: float = clampf(radius, 0.0001, minf(size.x, minf(size.y, size.z)) * 0.499)
	var safe_segments: int = maxi(1, segments)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for normal: Vector3 in axes:
		_add_face(surface, size, safe_radius, safe_segments, normal)
	surface.generate_tangents()
	surface.index()
	return surface.commit()


static func _add_face(surface: SurfaceTool, size: Vector3, radius: float, segments: int, face_normal: Vector3) -> void:
	var u_axis: Vector3
	var v_axis: Vector3
	if absf(face_normal.x) > 0.5:
		u_axis = Vector3(0.0, 0.0, -face_normal.x)
		v_axis = Vector3.UP
	elif absf(face_normal.y) > 0.5:
		u_axis = Vector3.RIGHT
		v_axis = Vector3(0.0, 0.0, -face_normal.y)
	else:
		u_axis = Vector3(face_normal.z, 0.0, 0.0)
		v_axis = Vector3.UP
	var steps: int = segments * 2 + 2
	for y: int in range(steps):
		for x: int in range(steps):
			var uv00 := Vector2(float(x) / steps, float(y) / steps)
			var uv10 := Vector2(float(x + 1) / steps, float(y) / steps)
			var uv11 := Vector2(float(x + 1) / steps, float(y + 1) / steps)
			var uv01 := Vector2(float(x) / steps, float(y + 1) / steps)
			_emit(surface, _rounded_point(size, radius, face_normal, u_axis, v_axis, uv00), uv00)
			_emit(surface, _rounded_point(size, radius, face_normal, u_axis, v_axis, uv10), uv10)
			_emit(surface, _rounded_point(size, radius, face_normal, u_axis, v_axis, uv11), uv11)
			_emit(surface, _rounded_point(size, radius, face_normal, u_axis, v_axis, uv00), uv00)
			_emit(surface, _rounded_point(size, radius, face_normal, u_axis, v_axis, uv11), uv11)
			_emit(surface, _rounded_point(size, radius, face_normal, u_axis, v_axis, uv01), uv01)


static func _rounded_point(size: Vector3, radius: float, face_normal: Vector3, u_axis: Vector3, v_axis: Vector3, uv: Vector2) -> Array[Vector3]:
	var half: Vector3 = size * 0.5
	var raw: Vector3 = face_normal * half.abs() + u_axis * _axis_extent(half, u_axis) * (uv.x * 2.0 - 1.0) + v_axis * _axis_extent(half, v_axis) * (uv.y * 2.0 - 1.0)
	var core := Vector3(maxf(half.x - radius, 0.0), maxf(half.y - radius, 0.0), maxf(half.z - radius, 0.0))
	var nearest := Vector3(clampf(raw.x, -core.x, core.x), clampf(raw.y, -core.y, core.y), clampf(raw.z, -core.z, core.z))
	var delta: Vector3 = raw - nearest
	var normal: Vector3 = delta.normalized() if delta.length_squared() > 0.00000001 else face_normal
	return [nearest + normal * radius, normal]


static func _axis_extent(half: Vector3, axis: Vector3) -> float:
	return absf(axis.x) * half.x + absf(axis.y) * half.y + absf(axis.z) * half.z


static func _emit(surface: SurfaceTool, data: Array[Vector3], uv: Vector2) -> void:
	surface.set_normal(data[1])
	surface.set_uv(uv)
	surface.add_vertex(data[0])
