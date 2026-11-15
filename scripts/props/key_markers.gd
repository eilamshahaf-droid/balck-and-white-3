class_name KeyMarkers
extends Node3D
## Marks each key building (where inspectors come from) with a signboard on its roof
## carrying its name. Placeholder look until the Artist gives key buildings their own.

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts

var _board := StandardMaterial3D.new()


func _ready() -> void:
	_board.albedo_color = S.key_board_color
	districts.layout_ready.connect(_on_layout_ready)


func _on_layout_ready() -> void:
	for k in districts.keys:
		var b := districts.buildings[k]
		var size := BuildingBox.size_of(b)
		var width := minf(size.x, S.key_board_width)
		var board := MeshInstance3D.new()
		board.mesh = SharedMeshes.box(Vector3.ONE)
		board.material_override = _board
		board.scale = Vector3(width, S.key_board_height, 0.3)
		add_child(board)
		board.global_transform = b.global_transform \
				* Transform3D(Basis.IDENTITY, Vector3(0.0, size.y / 2.0 + S.key_board_height / 2.0, 0.0))
		board.scale = Vector3(width, S.key_board_height, 0.3)
		for side: float in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = districts.key_name(k).to_upper()
			label.font_size = S.key_label_font_size
			label.pixel_size = width * 0.9 / (label.text.length() * S.key_label_font_size * 0.6)
			label.modulate = S.key_label_color
			label.outline_size = 0
			board.add_child(label)
			label.scale = Vector3.ONE / board.scale
			label.position = Vector3(0.0, 0.0, side * 0.55)
			label.rotation.y = 0.0 if side > 0.0 else PI
