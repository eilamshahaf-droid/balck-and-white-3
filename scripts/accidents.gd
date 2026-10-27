class_name Accidents
extends Node
## Believers are a risk: now and then the zealous ones set one of your own
## buildings on fire (candles, incense, a very moving sermon). Water puts it
## out in time and the residents call it a miracle (miracles.gd); left to
## burn, the building is lost.

const M: MiracleSettings = preload("res://data/miracles.tres")
const Sfx := preload("res://scripts/sfx.gd")
const DivineSign := preload("res://scripts/divine_sign.gd")

## A believer set `building` on fire by accident.
signal accident(building: Node3D)

## Uses where candles and incense burn all day: likelier to catch fire.
const RISKY_USES: Array[String] = ["Prayer House", "Course Center"]

@export var miracles: Miracles
@export var districts: Districts
@export var decrees: Decrees
@export var population: Population

var _wait := 0.0


func _ready() -> void:
	_wait = M.accident_interval


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = M.accident_interval
	if randf() < M.accident_chance:
		var building := _pick()
		if building:
			start_fire(building)


## A believer sets `building` alight by accident.
func start_fire(building: Node3D) -> void:
	miracles.set_alight(building, M.accident_burn_time / M.fire_burn_time)
	var line: String = M.accident_lines[randi() % M.accident_lines.size()]
	var roof := DivineSign.building_size(building).y / 2.0 + 3.0
	FloatingNote.pop(building.get_parent(), building.global_position + Vector3.UP * roof,
			line + "  Water, quick!", Color(1.0, 0.55, 0.25))
	Sfx.play(get_tree(), building.global_position, &"fire", 1.0)
	accident.emit(building)


## One of your buildings with believers in it and no fire, likelier where
## zealots are about and where candles burn.
func _pick() -> Node3D:
	var total := 0.0
	var weights: Array[float] = []
	var pool: Array[Node3D] = []
	for b in districts.converted_buildings():
		var fire := miracles.fire_on(b)
		if districts.believers_in(b) == 0 or (fire and (fire.is_burning() or fire.lost)):
			continue
		var w := 1.0 + population.zealots_near(b.global_position, M.accident_zealot_radius).size()
		if decrees.use_of(b) in RISKY_USES:
			w *= M.accident_use_weight
		pool.append(b)
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return null
