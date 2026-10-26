extends RefCounted
## What the divine decrees do to a building's body and look: new floors, a
## luxury lobby, banners, a new use and a preservation plaque. Placeholder
## boxes and labels built in code, so real models can replace them here alone.
## Every look is rebuilt from the building's decree metas (see decrees.gd).

const D: DecreeSettings = preload("res://data/decrees.tres")
const BuildingVisual := preload("res://scripts/building_visual.gd")
const DivineSign := preload("res://scripts/divine_sign.gd")

const FLOOR_HEIGHT := BuildingVisual.BAY * BuildingVisual.MODULE_HEIGHT
const DECOR := &"decree_decor"
const SEED := &"visual_seed"
const GROWTH := &"growth_tween"
const GOLD := Color(1.0, 0.8, 0.3)
const MARBLE := Color(0.95, 0.93, 0.88)
const PENTHOUSE := Color(0.55, 0.85, 1.0)
const BRONZE := Color(0.6, 0.42, 0.25)
const LABEL_PIXEL := 0.02   # metres per label pixel

static var _materials := {}


## Grow `building` by `floors` floors, feet still on the street. The new
## floors rise out of the old roof over D.grow_time seconds.
static func grow(building: Node3D, floors: int) -> void:
	if not building.has_meta(SEED):
		building.set_meta(SEED, hash(building.position))  # the city's own seed, before the move
	var old := DivineSign.building_size(building)
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
	if building.has_meta(DivineSign.META) and is_instance_valid(building.get_meta(DivineSign.META)):
		DivineSign.mark(building, building.get_meta(DivineSign.META).kind)  # back on the new roof


## Rebuild every decree's look on `building` from its metas.
static func redecorate(building: Node3D) -> void:
	for child in building.get_children():
		if child.is_in_group(DECOR):
			child.free()
	var size := DivineSign.building_size(building)
	var foot := -size.y / 2.0
	for side: float in [1.0, -1.0]:
		var face := side * (size.z / 2.0 + 0.05)
		var yaw := 0.0 if side > 0.0 else PI
		if building.get_meta(&"decree_luxury", false):
			_box(building, Vector3(size.x * 0.5, 0.3, 2.6), Vector3(0, foot + 3.4, side * (size.z / 2.0 + 1.3)), _mat(GOLD, true))
			_box(building, Vector3(size.x * 0.45, 3.0, 0.2), Vector3(0, foot + 1.7, face), _mat(MARBLE, false))
		if building.get_meta(&"decree_facade", false):
			var count := maxi(1, roundi(size.x / 5.0))
			for i in count:
				var x := (i + 0.5) / count * size.x - size.x / 2.0
				_box(building, Vector3(1.4, size.y * 0.55, 0.1), Vector3(x, foot + size.y * 0.55, face + side * 0.1), _mat(D.facade_color, false))
			_box(building, Vector3(size.x, 0.35, 0.2), Vector3(0, -foot - 0.4, face + side * 0.1), _mat(Color(1.0, 0.9, 0.6), true))
		var use: int = building.get_meta(&"decree_use", 0)
		if use > 0:
			# A rooftop sign, so the god can read it from up high.
			var name := D.uses[(use - 1) % D.uses.size()].to_upper()
			var fit := clampi(roundi(size.x * 0.9 / (name.length() * 0.6 * LABEL_PIXEL)), 40, 160)
			_label(building, name, Vector3(0, -foot + 3.0, size.z * 0.4 + side * 0.2), yaw, fit, GOLD)
		if building.get_meta(&"decree_preserve", false):
			_label(building, "PRESERVED\nForm 12-B", Vector3(size.x * 0.3, foot + 2.0, face + side * 0.05), yaw, 40, BRONZE)
	if building.get_meta(&"decree_use", 0) > 0:
		_box(building, Vector3(size.x * 0.9, 4.0, 0.3), Vector3(0, -foot + 3.0, size.z * 0.4), _mat(Color(0.2, 0.15, 0.25), false))
	if building.get_meta(&"decree_luxury", false):
		var top := -foot
		_box(building, Vector3(size.x * 0.6, 3.5, size.z * 0.6), Vector3(0, top + 1.75, 0), _mat(PENTHOUSE, false))
		_box(building, Vector3(size.x + 0.4, 0.8, 0.4), Vector3(0, top + 0.4, size.z / 2.0), _mat(GOLD, true))
		_box(building, Vector3(size.x + 0.4, 0.8, 0.4), Vector3(0, top + 0.4, -size.z / 2.0), _mat(GOLD, true))


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
