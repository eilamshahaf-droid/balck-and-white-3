class_name UiIcon
extends Control
## A small icon on the tape strip: drawn in flat shapes so it stays sharp when small
## (paperwork, a follower, a building), or a picture from the settings (a sewing button
## for money, a push pin for Reps).

enum Kind { PAPERWORK, MONEY, FOLLOWER, REP, BUILDING }

const S: UiSettings = preload("res://data/ui.tres")

var kind := Kind.PAPERWORK


func _init(k: Kind = Kind.PAPERWORK) -> void:
	kind = k
	custom_minimum_size = Vector2.ONE * S.icon_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := S.icon_size
	var r := Rect2(Vector2.ZERO, Vector2.ONE * s)
	match kind:
		Kind.MONEY:
			draw_texture_rect(S.coin_texture, r, false)
		Kind.REP:
			var w := s * S.pin_texture.get_width() / S.pin_texture.get_height()
			draw_texture_rect(S.pin_texture, Rect2((s - w) / 2.0, 0, w, s), false)
		Kind.PAPERWORK:
			var sheet := Rect2(s * 0.18, s * 0.08, s * 0.64, s * 0.84)
			draw_rect(sheet, Color.WHITE)
			draw_rect(sheet, S.ink, false, 1.5)
			for i in 4:
				var y := s * (0.3 + i * 0.15)
				draw_line(Vector2(s * 0.3, y), Vector2(s * 0.7, y), S.muted, 1.0)
		Kind.FOLLOWER:
			draw_circle(Vector2(s * 0.5, s * 0.25), s * 0.17, S.ink)
			draw_colored_polygon(PackedVector2Array([Vector2(s * 0.28, s * 0.95),
					Vector2(s * 0.34, s * 0.48), Vector2(s * 0.66, s * 0.48),
					Vector2(s * 0.72, s * 0.95)]), S.ink)
		Kind.BUILDING:
			var front := Rect2(s * 0.15, s * 0.1, s * 0.7, s * 0.85)
			draw_rect(front, S.red.darkened(0.2))
			for y in 3:
				for x in 2:
					draw_rect(Rect2(s * (0.27 + x * 0.27), s * (0.2 + y * 0.24), s * 0.18, s * 0.14),
							Color(1.0, 0.9, 0.6))
