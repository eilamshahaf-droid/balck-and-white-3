class_name BuildingBox
## A building's box, read from its collision shape, so props, markers and effects fit it
## even after a decree adds floors.


## Width, height and depth of `building`.
static func size_of(building: Node3D) -> Vector3:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size
	return Vector3.ONE * 10.0


## The building (a unit's "buildings" node) that `node` is or is a part of, or null:
## a unit's other buildings point to it (PlanBuilder).
static func building_of(node: Object) -> Node3D:
	if not node is Node3D:
		return null
	var n := node as Node3D
	if n.is_in_group("buildings"):
		return n
	if n.has_meta(&"building"):
		var main: Variant = n.get_meta(&"building")
		return main if is_instance_valid(main) else null
	return null


## `building` and the other buildings of its unit.
static func pieces_of(building: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = [building]
	if building.has_meta(&"parts"):
		out.append_array(building.get_meta(&"parts"))
	return out
