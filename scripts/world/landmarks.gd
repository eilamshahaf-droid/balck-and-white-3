class_name Landmarks
extends Node3D
## The five landmarks of the status quo in the start district, spread around its core.
## The Vandalist marks them (Murals asks is_landmark and calls mark); each standing mark
## makes the core easier to win (core_ease). City Hall scrubs old marks now and then.

## Landmark building `index` was marked, or its mark was cleaned off.
signal changed(index: int, marked: bool)

const L: LandmarkSettings = preload("res://data/landmarks.tres")

@export var districts: Districts

## The landmark buildings, by building index.
var buildings: Array[int] = []
var _marked: Dictionary = {}   # building index -> seconds the mark has stood
var _signs: Dictionary = {}    # building index -> Label3D
var _scrubbed: Dictionary = {}   # building index -> true, once City Hall cleaned it
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 41
	districts.layout_ready.connect(_place, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	for i: int in _marked.keys():
		_marked[i] += 1.0
		if _marked[i] >= L.clean_after_minutes * 60.0 \
				and _rng.randf() < L.clean_chance_per_minute / 60.0:
			clean(i)


func is_landmark(index: int) -> bool:
	return buildings.has(index)


func is_marked(index: int) -> bool:
	return _marked.has(index)


## What a mark on landmark `index` costs: dearer where City Hall scrubbed one off.
func mark_cost(index: int) -> float:
	return L.redo_cost if _scrubbed.has(index) else L.mark_cost


## How many landmarks of district `d` carry a mark.
func marks_in(d: int) -> int:
	var n := 0
	for i: int in _marked:
		if districts.district_of(i) == d:
			n += 1
	return n


## What converting the core's residents is multiplied by thanks to the marks
## (the core's difficulty times mark_multiplier per mark, inverted).
func core_ease(d: int) -> float:
	return 1.0 / pow(L.mark_multiplier, marks_in(d))


func mark(index: int) -> void:
	if not is_landmark(index) or _marked.has(index):
		return
	_marked[index] = 0.0
	_scrubbed.erase(index)
	_show(index)
	changed.emit(index, true)


## City Hall scrubs the mark off landmark `index`.
func clean(index: int) -> void:
	if not _marked.erase(index):
		return
	_scrubbed[index] = true
	_show(index)
	FloatingNote.pop(self, _signs[index].global_position, "City Hall cleaned it", L.sign_color)
	changed.emit(index, false)


func name_of(index: int) -> String:
	var k := buildings.find(index)
	return L.name_of(k) if k >= 0 else ""


## Pick the landmarks: buildings at least min_steps borders from the start district's
## core, one per slice of the circle around it, each the nearest to a ring at `ring` of the way out.
func _place() -> void:
	var d := districts.start_district()
	var core := districts.core_of(d)
	var centre := districts.buildings[core].global_position
	var near := {core: true}
	for j in districts.around(core, L.min_steps - 1):
		near[j] = true
	var pool: Array[int] = []
	var reach := 0.0
	for i in districts.buildings.size():
		if districts.district_of(i) == d and not near.has(i) and i != districts.headquarters:
			pool.append(i)
			reach = maxf(reach, districts.buildings[i].global_position.distance_to(centre))
	var count := L.count()
	for k in count:
		var angle := TAU * k / count
		var best := -1
		var best_score := INF
		for i in pool:
			if buildings.has(i):
				continue
			var off := districts.buildings[i].global_position - centre
			var turn := absf(wrapf(atan2(off.z, off.x) - angle, -PI, PI))
			var score := turn * reach + absf(off.length() - reach * L.ring)
			if score < best_score:
				best_score = score
				best = i
		if best >= 0:
			buildings.append(best)
			_make_sign(best, L.name_of(k))


func _make_sign(index: int, title: String) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 36
	label.outline_size = 10
	label.no_depth_test = true
	add_child(label)
	var b := districts.buildings[index]
	label.global_position = b.global_position + Vector3.UP * (districts.sizes[index].y / 2.0 + L.sign_lift)
	label.set_meta(&"title", title)
	_signs[index] = label
	_show(index)


func _show(index: int) -> void:
	var label: Label3D = _signs[index]
	var marked := _marked.has(index)
	label.text = "%s%s" % [label.get_meta(&"title"), "\n(marked)" if marked else ""]
	label.modulate = L.marked_color if marked else L.sign_color
