class_name BuildingBox
## A building's box, read from its collision shape, so props, markers and effects fit it
## even after a decree adds floors.


## Width, height and depth of `building`.
static func size_of(building: Node3D) -> Vector3:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size
	return Vector3.ONE * 10.0


## `node` as a building, or null when it is not one.
static func building_of(node: Object) -> Node3D:
	var n := node as Node3D
	return n if n and n.is_in_group("buildings") else null
