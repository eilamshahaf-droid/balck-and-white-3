class_name PropModel
extends RefCounted
## The mesh inside a prop's model scene, with the node transforms between the
## scene root and the mesh baked into one transform. Loaded once per kind and
## shared by every instance, MultiMesh or not.

static var _cache: Dictionary = {}   # PropKind -> PropModel

var mesh: Mesh
## The model's own material, made matte: Meshy's metal maps mirror the bright
## sky and wash the hand-painted colours out from the god's height.
var material: StandardMaterial3D
## Places the mesh so the model's footprint is centred on the origin and its
## base sits at y = 0 (or, with `against_wall`, its back face sits at z = 0).
var offset: Transform3D
## The model's size after `offset` and the kind's scale.
var size: Vector3
## Index of the "squash" blend shape, or -1 if the model has none.
var squash_shape := -1


static func of(kind: PropKind) -> PropModel:
	if not _cache.has(kind):
		_cache[kind] = PropModel.new(kind)
	return _cache[kind]


func _init(kind: PropKind) -> void:
	var root: Node3D = kind.model.instantiate()
	var found := _find_mesh(root)
	var to_root := found.transform
	var parent := found.get_parent()
	while parent != root:
		to_root = (parent as Node3D).transform * to_root
		parent = parent.get_parent()
	mesh = found.mesh
	root.free()
	material = (mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	material.metallic = 0.0
	material.metallic_texture = null
	material.roughness = 0.85
	material.roughness_texture = null
	var arrays := mesh as ArrayMesh
	if arrays:
		for i in arrays.get_blend_shape_count():
			if arrays.get_blend_shape_name(i) == &"squash":
				squash_shape = i
	var turn := Basis(Vector3.UP, deg_to_rad(kind.yaw_degrees))
	var scaled := Transform3D(Basis.from_scale(kind.scale) * turn, Vector3.ZERO) * to_root
	var box := scaled * mesh.get_aabb()
	size = box.size
	var centre := box.get_center()
	offset = Transform3D(Basis.IDENTITY, Vector3(-centre.x, -box.position.y, -centre.z)) * scaled


## The same placement but with the model's back (its -Z face) at z = 0, for
## things that hang on a wall and face away from it along +Z.
func against_wall() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 0, size.z / 2.0)) * offset


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null
