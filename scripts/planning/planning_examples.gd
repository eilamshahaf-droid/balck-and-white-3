extends RefCounted
## Three example plans, one for each god, built on the same starting city with
## the same tools the player has. Each follows the planning approach of its
## path in the design doc ("cities and stages"):
##   good    - Jane Jacobs and Jan Gehl: a humane city,
##   evil    - Robert Moses and Haussmann: the city as a machine,
##   neutral - agglomeration and land value capture: a business district on the line.

const City = preload("res://scripts/city.gd")

const TITLES := {"good": "Good god", "evil": "Evil god", "neutral": "Neutral god"}
const TEXTS := {
	"good": "Jacobs and Gehl, the humane city. Every block mixed with homes and shops, short blocks (cross streets closed into plazas), a temple on a square at the heart, parks, street trees, benches and small shrines, and no cameras. Buildings stay human-scale. The city makes quality of life, so people move in by choice.",
	"evil": "Moses and Haussmann, the city as a machine. Factories on both edges, worker housing slabs beside them, few shops, a frightening monument in the centre and cameras on every avenue. No trees. The city makes power: fear, compliance and recruits, and frightened people pray too.",
	"neutral": "Agglomeration and land value capture. Three stations on one line, a dense business district around them, a headquarters tower at each station and billboards on the avenues. Homes are pushed outwards. The city makes money and commuters, and influence that spreads along the line.",
}


static func apply(model, which: String) -> void:
	match which:
		"good":
			_good(model)
		"evil":
			_evil(model)
		"neutral":
			_neutral(model)
	# Let the city grow into the plan: buildings rise and convert where wanted.
	var idle := 0
	for n in 6000:
		if model.step() < 0:
			idle += 1
			if idle > 200:
				break
		else:
			idle = 0


static func _good(model) -> void:
	for b in model.blocks.size():
		var block: Dictionary = model.blocks[b]
		# Mixed use everywhere (Jacobs): homes and shops alternate like a chessboard.
		model.set_zone(b, "residential" if (block.i + block.j) % 2 == 0 else "commercial")
		block.density = 2 if absi(block.i * 2 - 5) < 4 and absi(block.j - 6) < 5 else 1
	_landmark(model, "temple", 2, 6, 0.75)
	_landmark(model, "square", 3, 6, 0.25)
	_landmark(model, "park", 1, 3, 0.5)
	_landmark(model, "park", 4, 9, 0.5)
	_landmark(model, "square", 2, 10, 0.3)
	# Short blocks: close cross streets into plazas.
	for p in [Vector2i(1, 5), Vector2i(2, 4), Vector2i(3, 8), Vector2i(4, 5), Vector2i(2, 9), Vector2i(1, 9), Vector2i(4, 3)]:
		model.place_plaza(_street(model, p.x, p.y))
	# Street trees on the sidewalks, benches by the squares, small shrines in the neighbourhoods.
	for i in City.AVENUES - 1:
		for j in range(1, City.STREETS - 1, 2):
			for x in [-22.0, 0.0, 22.0]:
				model.place_detail("tree", _street(model, i, j) + Vector3(x, 0, 5.8))
	for p in [Vector2i(2, 6), Vector2i(3, 6), Vector2i(2, 10), Vector2i(1, 3), Vector2i(4, 9)]:
		model.place_detail("bench", _street(model, p.x, p.y) + Vector3(-8, 0, -5.8))
		model.place_detail("bench", _street(model, p.x, p.y) + Vector3(8, 0, -5.8))
	for p in [Vector2i(0, 2), Vector2i(1, 7), Vector2i(3, 2), Vector2i(4, 11), Vector2i(5, 6), Vector2i(0, 10), Vector2i(3, 11)]:
		model.place_detail("shrine", _street(model, p.x, p.y) + Vector3(14, 0, -5.8))


static func _evil(model) -> void:
	for b in model.blocks.size():
		var block: Dictionary = model.blocks[b]
		if block.i == 0 or block.i == 5:
			model.set_zone(b, "industrial")
			block.density = 3
		elif block.i == 1 or block.i == 4:
			model.set_zone(b, "residential")   # worker housing next to the factories
			block.density = 3
		else:
			model.set_zone(b, "commercial" if block.j % 5 == 0 else "residential")
			block.density = 2
	for p in [Vector2i(0, 2), Vector2i(0, 7), Vector2i(5, 4), Vector2i(5, 10), Vector2i(0, 11)]:
		_landmark(model, "factory", p.x, p.y, 0.5)
	_landmark(model, "monument", 2, 6, 0.85)
	_landmark(model, "monument", 3, 6, 0.15)
	# Cameras on every avenue crossing.
	for a in range(1, City.AVENUES - 1):
		for j in range(1, City.STREETS - 1, 2):
			var x: float = a * City.AVENUE_SPACING - model.half_size.x + City.AVENUE_WIDTH / 2.0 + 1.5
			model.place_detail("camera", Vector3(x, 0, j * City.STREET_SPACING - model.half_size.y + 5.8))


static func _neutral(model) -> void:
	var stations := [Vector2i(2, 2), Vector2i(2, 6), Vector2i(2, 10)]
	for b in model.blocks.size():
		var block: Dictionary = model.blocks[b]
		var near := 99
		for s in stations:
			near = mini(near, absi(block.i - s.x) + absi(block.j - s.y))
		if near <= 1 or (block.i == 3 and near <= 2):
			model.set_zone(b, "commercial")   # the business district around the stations
			block.density = 3
		elif block.zone == "industrial":
			block.density = 1
		else:
			model.set_zone(b, "residential" if block.j % 4 != 0 else "commercial")
			block.density = 2 if near <= 3 else 1
	for s in stations:
		_landmark(model, "station", s.x, s.y, 0.8)
		_landmark(model, "tower", s.x + 1, s.y, 0.2)
	for a in [2, 3, 4]:
		for j in range(1, City.STREETS - 1, 2):
			var x: float = a * City.AVENUE_SPACING - model.half_size.x - City.AVENUE_WIDTH / 2.0 - 1.5
			model.place_detail("billboard", Vector3(x, 0, j * City.STREET_SPACING - model.half_size.y - 5.8))


## A landmark in block (i, j), `along` from its west end (0) to its east end (1).
static func _landmark(model, kind: String, i: int, j: int, along: float) -> void:
	var block: Dictionary = model.blocks[model.block_index(i, j)]
	var x: float = block.center.x + (along - 0.5) * block.size.x
	model.place_landmark(kind, Vector3(x, 0, block.center.z))


## The middle of the cross street on the north side of block (i, j).
static func _street(model, i: int, j: int) -> Vector3:
	return Vector3(i * City.AVENUE_SPACING - model.half_size.x + City.AVENUE_SPACING / 2.0, 0,
			j * City.STREET_SPACING - model.half_size.y)
