class_name LabCamera
extends Camera2D
## Looks at the lab's map: the mouse wheel zooms toward the cursor, a right or
## middle drag moves the view.

var _zoom_range := Vector2.ONE
var _zoom_step := 1.0


func setup(settings: MapLabSettings) -> void:
	_zoom_range = settings.zoom_range
	_zoom_step = settings.zoom_step
	# Centre the map in the space right of the menu.
	position = Vector2(-settings.panel_width / 2.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(button.position, _zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(button.position, 1.0 / _zoom_step)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		position -= motion.relative / zoom.x


## Zooms keeping the map point under `screen` where it is.
func _zoom_at(screen: Vector2, factor: float) -> void:
	var from_centre := screen - get_viewport_rect().size / 2.0
	var under := position + from_centre / zoom.x
	var z := clampf(zoom.x * factor, _zoom_range.x, _zoom_range.y)
	zoom = Vector2(z, z)
	position = under - from_centre / z
