class_name PropKind
extends Resource
## One kind of Meshy prop (a trash can, a window air conditioner, a water tank)
## and how the city uses it. Listed in data/city_props.tres.

## The prop's model, as exported from Meshy and shrunk to 1K textures
## (assets/models/meshy/). Its largest side is already its real size in metres.
@export var model: PackedScene
## Turn the model about the vertical so its front faces +Z (degrees).
@export var yaw_degrees := 0.0
## Stretch on top of the real size, after the turn; the taxi uses it to stay a
## toy-like sedan.
@export var scale := Vector3.ONE
## How often this kind is picked against the others in its list.
@export var weight := 1.0
## Street props only: weight in the hand, and the sound it makes.
@export var mass := 1.0
@export var surface := &"metal"
## Street props only: how many to stand side by side when this kind is picked
## (trash bags come in heaps).
@export var cluster := Vector2i(1, 1)
