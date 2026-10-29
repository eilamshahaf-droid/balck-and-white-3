class_name TensorField
extends RefCounted
## A direction for streets at every point of the map, blended from a few basis
## fields (patches of straight streets at an angle, fans around a centre) with a
## little noise on top (Chen et al., "Interactive Procedural Street Modeling").
## Each basis is stored as a doubled angle, so opposite directions add up instead
## of cancelling.

var _centres := PackedVector2Array()
var _angles := PackedFloat32Array()     # doubled angle of a grid basis, unused for a radial
var _radial := PackedByteArray()
var _reach_sq: float
var _wobble: float
var _noise := FastNoiseLite.new()


func _init(spec: MapSpec, rng: RandomNumberGenerator) -> void:
	_reach_sq = spec.field_reach * spec.field_reach
	_wobble = spec.field_wobble
	_noise.seed = rng.randi()
	_noise.frequency = 0.01
	var half := spec.field_size / 2.0
	for n in spec.grid_fields + spec.radial_fields:
		_centres.append(Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y)))
		_angles.append(rng.randf() * TAU)
		_radial.append(1 if n >= spec.grid_fields else 0)


## The major street direction at p, as a unit vector. The minor one is its
## perpendicular.
func major_at(p: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	for n in _centres.size():
		var offset := p - _centres[n]
		var w := exp(-offset.length_squared() / _reach_sq)
		var doubled: float = offset.angle() * 2.0 if _radial[n] == 1 else _angles[n]
		sum += Vector2.from_angle(doubled) * w
	var angle := sum.angle() / 2.0 + _noise.get_noise_2dv(p) * _wobble
	return Vector2.from_angle(angle)
