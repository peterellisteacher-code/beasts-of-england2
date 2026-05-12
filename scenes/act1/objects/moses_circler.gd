## Drives Moses the raven on a slow circular path above the scene — pure
## atmosphere, no detection, no fail state. Pattern: position oscillation.
extends Sprite2D

@export var radius_x: float = 520.0
@export var radius_y: float = 110.0
@export var speed: float = 0.42

var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_origin = position


func _process(delta: float) -> void:
	_t += delta * speed
	position = _origin + Vector2(cos(_t) * radius_x, sin(_t) * radius_y)
	# Mild horizontal flip so Moses faces the direction of travel
	flip_h = sin(_t) > 0.0
