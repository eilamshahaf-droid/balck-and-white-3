class_name DistrictField
extends TensorField
## A street direction field in which every district lays its own patches and fans
## with the numbers of its street style, so a planned-grid financial district can
## sit next to a winding old quarter. Grid patches turn around one city angle, as
## far as their style's wobble allows, so neighbouring grids meet without a sharp
## turn.

var _base_centres := PackedVector2Array()
var _base_angles := PackedFloat32Array()   # unused for a fan
var _base_fans := PackedByteArray()
var _base_reach_sq := PackedFloat32Array()
var _district_centres := PackedVector2Array()
var _district_wobble := PackedFloat32Array()
var _district_reach_sq: float
var _wobble_noise := FastNoiseLite.new()


## `styles` holds one style per district, in MapLayout district order.
func _init(spec: MapSpec, rng: RandomNumberGenerator, styles: Array[StreetStyle],
		curviness: float) -> void:
	super(spec, rng)
	_wobble_noise.seed = rng.randi()
	_wobble_noise.frequency = 0.01
	var cell := Vector2(spec.field_size.x / spec.columns, spec.field_size.y / spec.rows)
	_district_reach_sq = cell.length_squared() / 4.0
	var city_angle := rng.randf() * PI
	for d in styles.size():
		var style := styles[d]
		var place := Vector2(d % spec.columns, floori(float(d) / spec.columns))
		var low := -spec.field_size / 2.0 + place * cell
		_district_centres.append(low + cell / 2.0)
		_district_wobble.append(style.field_wobble * curviness)
		var reach := style.field_reach * spec.metres_scale
		var turn := PI / 2.0 * clampf(style.field_wobble * 2.0, 0.0, 1.0)
		for n in style.grid_fields + style.radial_fields:
			_base_centres.append(low + Vector2(rng.randf(), rng.randf()) * cell)
			_base_angles.append((city_angle + rng.randf_range(-turn, turn)) * 2.0)
			_base_fans.append(1 if n >= style.grid_fields else 0)
			_base_reach_sq.append(reach * reach)


func major_at(p: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	for n in _base_centres.size():
		var offset := p - _base_centres[n]
		var w := exp(-offset.length_squared() / _base_reach_sq[n])
		var doubled: float = offset.angle() * 2.0 if _base_fans[n] == 1 else _base_angles[n]
		sum += Vector2.from_angle(doubled) * w
	var wobble := 0.0
	var total := 0.0
	for d in _district_centres.size():
		var w := exp(-p.distance_squared_to(_district_centres[d]) / _district_reach_sq)
		wobble += _district_wobble[d] * w
		total += w
	if total > 0.0:
		wobble /= total
	return Vector2.from_angle(sum.angle() / 2.0 + _wobble_noise.get_noise_2dv(p) * wobble)
