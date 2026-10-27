class_name MiracleProof
extends RefCounted
## What miracles leave behind. A miracle doesn't convert anyone by itself: it
## leaves proof on the spot for a while, and priests preaching there persuade
## better (Population reads Miracles.proof_at()). Proof is weaker where many
## miracles landed lately, and every miracle costs more for a while after it
## is cast and needs a moment before it can be cast again.

const M: MiracleSettings = preload("res://data/miracles.tres")


## One patch of proof on the ground.
class Spot:
	var at: Vector3
	var radius: float
	var strength: float
	var time_left: float


var _spots: Array[Spot] = []
var _landed: Array[Vector3] = []    # where recent miracles landed...
var _landed_age: Array[float] = []  # ...and how long ago
var _uses := {}       # kind -> recent casts, decaying
var _cooldown := {}   # kind -> seconds until it can be cast again


func tick(delta: float) -> void:
	for i in range(_spots.size() - 1, -1, -1):
		_spots[i].time_left -= delta
		if _spots[i].time_left <= 0.0:
			_spots.remove_at(i)
	for i in range(_landed_age.size() - 1, -1, -1):
		_landed_age[i] += delta
		if _landed_age[i] > M.proof_memory:
			_landed.remove_at(i)
			_landed_age.remove_at(i)
	for kind in _uses:
		_uses[kind] = maxf(_uses[kind] - delta / M.repeat_memory, 0.0)
	for kind in _cooldown:
		_cooldown[kind] = maxf(_cooldown[kind] - delta, 0.0)


## A miracle landed at `at`: leave `strength` of proof within `radius` (it can
## be negative), weaker for every miracle that landed near here lately.
func leave(at: Vector3, radius: float, strength: float) -> void:
	var crowded := 0
	for p in _landed:
		if _flat_distance(p, at) < radius:
			crowded += 1
	_landed.append(at)
	_landed_age.append(0.0)
	if is_zero_approx(strength):
		return
	var spot := Spot.new()
	spot.at = at
	spot.radius = radius
	spot.strength = strength * pow(M.proof_saturation, crowded)
	spot.time_left = M.proof_time
	_spots.append(spot)


## The proof at `p` now: about 1 after a strong miracle, fading to 0; negative
## where a miracle went badly.
func proof_at(p: Vector3) -> float:
	var sum := 0.0
	for spot in _spots:
		if _flat_distance(spot.at, p) < spot.radius:
			sum += spot.strength * spot.time_left / M.proof_time
	return sum


## `kind` was cast: dearer for a while, and not again for `cooldown` seconds.
func used(kind: StringName, cooldown: float) -> void:
	_uses[kind] = _uses.get(kind, 0.0) + 1.0
	_cooldown[kind] = cooldown


## How much dearer `kind` is now for being cast lately.
func cost_scale(kind: StringName) -> float:
	return 1.0 + M.repeat_cost_step * _uses.get(kind, 0.0)


## Seconds until `kind` can be cast again (0: ready).
func ready_in(kind: StringName) -> float:
	return _cooldown.get(kind, 0.0)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
