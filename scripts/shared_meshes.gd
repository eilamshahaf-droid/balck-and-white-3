class_name SharedMeshes
extends RefCounted
## Low-poly primitive meshes shared by every instance that uses them.
##
## Godot's default SphereMesh, CapsuleMesh and CylinderMesh have thousands of
## triangles each; hundreds of trees and people made of them cost more to draw
## than all the buildings. One mesh per shape, sized through the node's scale
## where sizes vary, also saves a mesh resource per instance.

static var _cache: Dictionary = {}


## A sphere of radius 1 (scale the node by the radius you want).
static func unit_sphere(radial_segments: int = 16, rings: int = 8) -> SphereMesh:
	var key := "sphere_%d_%d" % [radial_segments, rings]
	if not _cache.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = radial_segments
		mesh.rings = rings
		_cache[key] = mesh
	return _cache[key]


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "capsule_%s_%s" % [radius, height]
	if not _cache.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		mesh.rings = 3
		_cache[key] = mesh
	return _cache[key]


static func cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var key := "cylinder_%s_%s_%s" % [top_radius, bottom_radius, height]
	if not _cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top_radius
		mesh.bottom_radius = bottom_radius
		mesh.height = height
		mesh.radial_segments = 10
		mesh.rings = 1
		_cache[key] = mesh
	return _cache[key]


static func box(size: Vector3) -> BoxMesh:
	var key := "box_%s" % size
	if not _cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_cache[key] = mesh
	return _cache[key]
