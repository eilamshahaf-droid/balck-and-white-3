class_name LandUsePlanner
extends RefCounted
## Gives every block a use. Each district draws from its archetype's mix, and a
## few rules from how real cities sort themselves bend the draw: offices crowd
## onto main streets, public buildings gather at the centre, big blocks become
## parks, industry is pushed to the edge, and small leftover blocks are squares.

static func plan(blocks: CityBlocks, mixes: Array[LandUseMix], spec: MapSpec,
		params: LabParams, settings: MapLabSettings,
		rng: RandomNumberGenerator) -> PackedInt32Array:
	var uses := PackedInt32Array()
	var scales := params.use_scales()
	var half := spec.field_size / 2.0
	for b in blocks.count():
		var area := blocks.areas[b]
		if area < settings.sliver_area:
			uses.append(LandUse.PAVEMENT)
			continue
		if area < settings.square_area:
			uses.append(LandUse.Use.SQUARE)
			continue
		var centre := blocks.centres[b]
		var weights := mixes[district_at(centre, spec)].weights()
		for u in weights.size():
			weights[u] *= scales[u]
		if blocks.on_main_road[b] == 1:
			weights[LandUse.Use.OFFICES] *= settings.main_road_offices
		var from_centre := clampf((centre / half).length() / sqrt(2.0), 0.0, 1.0)
		weights[LandUse.Use.PUBLIC] *= lerpf(settings.centre_public, 1.0, from_centre)
		if area > settings.big_block_area:
			weights[LandUse.Use.PARK] *= settings.big_block_parks
		if blocks.at_edge[b] == 1:
			weights[LandUse.Use.INDUSTRY] *= settings.edge_industry
		uses.append(_pick(weights, rng))
	return uses


## The district (MapLayout order: west to east, then south to north) a point is in.
static func district_at(p: Vector2, spec: MapSpec) -> int:
	var t := (p + spec.field_size / 2.0) / spec.field_size
	var col := clampi(floori(t.x * spec.columns), 0, spec.columns - 1)
	var row := clampi(floori(t.y * spec.rows), 0, spec.rows - 1)
	return row * spec.columns + col


static func _pick(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return LandUse.Use.HOMES
	var roll := rng.randf() * total
	for u in weights.size():
		roll -= weights[u]
		if roll <= 0.0:
			return u
	return weights.size() - 1
