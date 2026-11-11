class_name Needs
extends RefCounted
## A believer's four needs (GDD section 4) and what they do: each need is met
## by how much the person has against how much their archetype wants, and the
## needs together, weighted by how strongly each affects them, set an output
## multiplier between multiplier_min and multiplier_max.


## How well `r`'s need is met, 0..1: what they have over what they want.
static func met(have: float, desire: float) -> float:
	if desire <= 0.0:
		return 1.0
	return clampf(have / desire, 0.0, 1.0)


## Refresh what `r` has of each need from the systems that feed it.
static func refresh(r: Resident, u: UnitSettings) -> void:
	r.livelihood = r.comfort
	r.security = 1.0 - r.fear
	r.pleasure = u.pleasure_base
	r.meaning = u.meaning_free if r.job == Resident.Job.FREE else u.meaning_posted


## How well `r`'s livelihood is met (below UnitSettings.leave_below they may leave).
static func livelihood_met(r: Resident, a: ArchetypeSettings) -> float:
	return met(r.livelihood, a.value(r.archetype.livelihood_desire)) if r.archetype else 1.0


## The output multiplier for `r`.
static func multiplier(r: Resident, a: ArchetypeSettings, u: UnitSettings) -> float:
	var t := r.archetype
	if t == null:
		return 1.0
	var weights := PackedFloat32Array([a.value(t.livelihood_influence), a.value(t.security_influence),
			a.value(t.pleasure_influence), a.value(t.meaning_influence)])
	var scores := PackedFloat32Array([met(r.livelihood, a.value(t.livelihood_desire)),
			met(r.security, a.value(t.security_desire)),
			met(r.pleasure, a.value(t.pleasure_desire)),
			met(r.meaning, a.value(t.meaning_desire))])
	var total := 0.0
	var sum := 0.0
	for i in 4:
		total += weights[i]
		sum += weights[i] * scores[i]
	var share := sum / total if total > 0.0 else 1.0
	return lerpf(u.multiplier_min, u.multiplier_max, share)
