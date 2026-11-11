class_name BuildingBox
## A building's box, read from its collision shape, so props, markers and effects fit it
## even after a decree adds floors.


## Width, height and depth of `building`.
static func size_of(building: Node3D) -> Vector3:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size
	return Vector3.ONE * 10.0
