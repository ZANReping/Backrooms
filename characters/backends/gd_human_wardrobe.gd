class_name GdHumanWardrobe
extends RefCounted

## Offline MakeHuman OBJ accessories are fitted once to the shared skeleton.
const ROOT := "res://assets/third_party/characters/makehuman_system_cc0/"
const HairFit := preload("res://characters/backends/hair_fit_calibration.gd")
var hair: MeshInstance3D
var shoes: Array[MeshInstance3D] = []
var _skeleton: Skeleton3D
var _hair_attachment: BoneAttachment3D
var _hair_id: StringName = &""


func configure(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	_hair_attachment = _attachment("head", "HairAttachment")
	hair = MeshInstance3D.new()
	hair.name = "Hair"
	hair.mesh = load(ROOT + "short01/short01.obj") as Mesh
	_hair_attachment.add_child(hair)
	var skin_basis: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("head")).affine_inverse()
	hair.transform = skin_basis * HairFit.source_to_model(&"short", CharacterAppearance.new())
	var hair_material := StandardMaterial3D.new()
	hair_material.albedo_texture = load(ROOT + "short01/short01_diffuse.png") as Texture2D
	hair_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	hair_material.alpha_scissor_threshold = 0.35
	hair_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hair_material.roughness = 0.8
	hair.material_override = hair_material
	var source := load(ROOT + "shoes01/shoes01.obj") as ArrayMesh
	for side: String in ["L", "R"]:
		var shoe := MeshInstance3D.new()
		shoe.name = "Shoe" + side
		shoe.mesh = _split_shoe(source, side == "L")
		var attachment: BoneAttachment3D = _attachment("foot." + side, "ShoeAttachment" + side)
		attachment.add_child(shoe)
		var inverse_rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("foot." + side)).affine_inverse()
		shoe.transform = inverse_rest * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.1), Vector3(0.0, 0.820, 0.0))
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(ROOT + "shoes01/shoes01_diffuse.png") as Texture2D
		material.normal_texture = load(ROOT + "shoes01/shoes01_normal.png") as Texture2D
		material.normal_enabled = true
		material.roughness = 0.65
		shoe.material_override = material
		shoes.append(shoe)


func apply_appearance(appearance: CharacterAppearance) -> void:
	if hair != null:
		if _hair_id != appearance.hair:
			_hair_id = appearance.hair
			var asset: String = HairFit.asset_for(appearance.hair)
			hair.mesh = load(ROOT + asset + "/" + asset + ".obj") as Mesh
			(hair.material_override as StandardMaterial3D).albedo_texture = load(ROOT + asset + "/" + asset + "_diffuse.png") as Texture2D
		var inverse_rest: Transform3D = _skeleton.get_bone_global_rest(_skeleton.find_bone("head")).affine_inverse()
		hair.transform = inverse_rest * HairFit.source_to_model(appearance.hair, appearance)
		(hair.material_override as StandardMaterial3D).albedo_color = appearance.hair_color.lightened(0.25)
	for shoe: MeshInstance3D in shoes:
		(shoe.material_override as StandardMaterial3D).albedo_color = appearance.clothing_colors.get(&"shoes", Color("606060")).lightened(0.3)


func set_first_person(enabled: bool) -> void:
	if hair != null:
		hair.visible = not enabled


func get_hair_model_bounds() -> AABB:
	if hair == null or hair.mesh == null or _skeleton == null:
		return AABB()
	var head_rest := _skeleton.get_bone_global_rest(_skeleton.find_bone("head"))
	return head_rest * hair.transform * hair.mesh.get_aabb()


func get_hair_contact_metrics() -> Dictionary:
	var result := {&"occipital_min_z": INF, &"crown_min_z": INF, &"crown_max_z": -INF, &"crown_samples": 0}
	if hair == null or hair.mesh == null or _skeleton == null:
		return result
	var to_model: Transform3D = _skeleton.get_bone_global_rest(_skeleton.find_bone("head")) * hair.transform
	for surface: int in hair.mesh.get_surface_count():
		var vertices: PackedVector3Array = hair.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for source_vertex: Vector3 in vertices:
			var vertex: Vector3 = to_model * source_vertex
			if vertex.y >= 1.52 and vertex.y <= 1.68:
				result[&"occipital_min_z"] = minf(result[&"occipital_min_z"], vertex.z)
			if vertex.y >= 1.68:
				result[&"crown_min_z"] = minf(result[&"crown_min_z"], vertex.z)
				result[&"crown_max_z"] = maxf(result[&"crown_max_z"], vertex.z)
				result[&"crown_samples"] += 1
	return result


func _attachment(bone: String, node_name: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone
	_skeleton.add_child(attachment)
	return attachment


func _split_shoe(source: ArrayMesh, positive_x: bool) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var old_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		for index: int in range(0, old_indices.size(), 3):
			var center_x: float = (vertices[old_indices[index]].x + vertices[old_indices[index + 1]].x + vertices[old_indices[index + 2]].x) / 3.0
			if (center_x >= 0.0) == positive_x:
				indices.append_array(old_indices.slice(index, index + 3))
		if indices.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
