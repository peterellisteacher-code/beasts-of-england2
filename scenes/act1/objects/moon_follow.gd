## Keeps the moon at a near-fixed point in the sky as the camera scrolls —
## a distant celestial object has effectively zero parallax. This guarantees
## the big moon is visible for Old Major's whole night walk.
extends Sprite2D

## Offset from the camera's screen-centre, in world units.
@export var screen_offset: Vector2 = Vector2(-250.0, -210.0)
## Tiny drift so the moon is not perfectly glued (subtle life).
@export var drift_amount: float = 14.0

var _cam: Camera2D
var _t: float = 0.0


func _ready() -> void:
	_cam = get_node_or_null(^"../OldMajor/Camera2D") as Camera2D
	# Moon is the first child of World, so tree order already puts it behind
	# the hills/props yet in front of the flat NightSky backdrop.


func _process(delta: float) -> void:
	if _cam == null:
		return
	_t += delta * 0.25
	var centre: Vector2 = _cam.get_screen_center_position()
	global_position = centre + screen_offset + Vector2(
			sin(_t) * drift_amount, cos(_t * 0.7) * drift_amount * 0.4)
