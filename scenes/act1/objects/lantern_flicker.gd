## Subtle warm flicker for Old Major's lantern PointLight2D — layered sine
## waves so the light breathes like a real flame. Attach to a PointLight2D.
extends PointLight2D

@export var flicker_amount: float = 0.24

var _base_energy: float = 1.9
var _t: float = 0.0


func _ready() -> void:
	_base_energy = energy
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	var f: float = (sin(_t * 7.1) * 0.5
			+ sin(_t * 17.3) * 0.3
			+ sin(_t * 3.0) * 0.2)
	energy = max(0.2, _base_energy + f * flicker_amount)
