class_name OrganicStreets
extends RefCounted
## Street lines of an organic city: pure data, deterministic by seed, so the
## preview, the sandbox and a test all see the same streets.

var major: Array[PackedVector2Array] = []
var minor: Array[PackedVector2Array] = []


static func generate(spec: MapSpec) -> OrganicStreets:
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.map_seed
	var tracer := StreetTracer.new(spec, TensorField.new(spec, rng), rng)
	var out := OrganicStreets.new()
	out.major = tracer.major
	out.minor = tracer.minor
	return out
