extends RefCounted
## What the decrees do to a building's body and look: new floors, and a roof sign for
## a shop. Placeholder boxes and labels built in code, so real models can replace them
## here alone.
## Every look is rebuilt from the building's decree metas (see decrees.gd).

const D: DecreeSettings = preload("res://data/decrees.tres")
const BuildingVisual := preload("res://scripts/building_visual.gd")

const FLOOR_HEIGHT := BuildingVisual.BAY * BuildingVisual.MODULE_HEIGHT
const DECOR := &"decree_decor"
const SEED := &"visual_seed"
const GROWTH := &"growth_tween"
const GOLD := Color(1.0, 0.8, 0.3)
const LABEL_PIXEL := 0.02   # metres per label pixel

static var _materials := {}


## Grow `building` by `floors` floors, feet still on the street. The new
## floors rise out of the old roof over D.grow_time seconds.
static func grow(building: Node3D, floors: int) -> void:
	if not building.has_meta(SEED):
		building.set_meta(SEED, hash(building.position))  # the city's own seed, before the move
	var old := BuildingBox.size_of(building)
	var size := old + Vector3.UP * floors * FLOOR_HEIGHT
	_shape(building).size = size
	building.position.y += (size.y - old.y) / 2.0
	if building.has_meta(GROWTH):
		(building.get_meta(GROWTH) as Tween).kill()  # the last growth's mesh is about to go
	var visual := _rebuild_visual(building, size)
	var rise := func(t: float) -> void:
		visual.scale.y = t
		visual.position.y = size.y / 2.0 * (t - 1.0)
	rise.call(old.y / size.y)
	var tween := building.create_tween()
	tween.tween_method(rise, old.y / size.y, 1.0, D.grow_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	building.set_meta(GROWTH, tween)
	redecorate(building)


## Rebuild every decree's look on `building` from its metas.
static func redecorate(building: Node3D) -> void:
	for child in building.get_children():
		if child.is_in_group(DECOR):
			child.free()
	var size := BuildingBox.size_of(building)
	var foot := -size.y / 2.0
	for side: float in [1.0, -1.0]:
		var yaw := 0.0 if side > 0.0 else PI
		var use: String = building.get_meta(&"decree_use", "")
		if use != "":
			# A rooftop sign, so the god can read it from up high.
			var name := use.to_upper()
			var fit := clampi(roundi(size.x * 0.9 / (name.length() * 0.6 * LABEL_PIXEL)), 40, 160)
			_label(building, name, Vector3(0, -foot + 3.0, size.z * 0.4 + side * 0.2), yaw, fit, GOLD)
	if building.get_meta(&"decree_use", "") != "":
		_box(building, Vector3(size.x * 0.9, 4.0, 0.3), Vector3(0, -foot + 3.0, size.z * 0.4), _mat(Color(0.2, 0.15, 0.25), false))



static func _rebuild_visual(building: Node3D, size: Vector3) -> MeshInstance3D:
	for child in building.get_children():
		if child is MeshInstance3D and not child.is_in_group(DECOR):
			child.free()
	var glass: bool = building.get_meta(&"surface", &"concrete") == &"glass"
	var visual := BuildingVisual.build(size, building.get_meta(SEED), glass)
	building.add_child(visual)
	return visual


static func _shape(building: Node3D) -> BoxShape3D:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape
	return null


static func _box(building: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	mesh.add_to_group(DECOR)
	building.add_child(mesh)


static func _label(building: Node3D, text: String, pos: Vector3, yaw: float, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = LABEL_PIXEL
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.07, 0.05)
	label.position = pos
	label.rotation.y = yaw
	label.double_sided = false
	label.add_to_group(DECOR)
	building.add_child(label)


static func _mat(color: Color, glow: bool) -> StandardMaterial3D:
	var key := [color, glow]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 0.8
		_materials[key] = m
	return _materials[key]
