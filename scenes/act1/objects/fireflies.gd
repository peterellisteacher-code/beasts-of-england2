## Ambient firefly effect — drifting glowing dots on a sine-wave path.
## Pure GDScript, no particle system (gl_compatibility-safe). Spawns N
## lightweight Sprite2D children spread across the level, at varied heights.
extends Node2D

@export var count: int = 22
@export var spread_x: float = 2500.0
@export var glow_color: Color = Color(0.92, 1.0, 0.55, 0.85)

var _flies: Array = []

const STAR_PATH: String = "res://assets/sprites/erw/props/star.png"


func _ready() -> void:
	var tex: Texture2D = load(STAR_PATH)
	for i: int in range(count):
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = tex
		var s: float = randf_range(0.3, 0.62)
		sp.scale = Vector2(s, s)
		var fly: Dictionary = {
			"node": sp,
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(0.3, 0.95),
			"drift_x": randf_range(0.12, 0.4),
			"amp_y": randf_range(14.0, 42.0),
			"base_x": randf_range(0.0, spread_x),
			"base_y": randf_range(350.0, 560.0),
		}
		sp.position = Vector2(fly["base_x"], fly["base_y"])
		add_child(sp)
		_flies.append(fly)


func _process(delta: float) -> void:
	for fly: Dictionary in _flies:
		fly["phase"] += delta * fly["speed"]
		var sp: Sprite2D = fly["node"]
		sp.position.x += delta * fly["drift_x"] * 20.0
		if sp.position.x > spread_x:
			sp.position.x = 0.0
		sp.position.y = fly["base_y"] + sin(fly["phase"]) * fly["amp_y"]
		var a: float = 0.42 + sin(fly["phase"] * 1.7) * 0.36
		sp.modulate = Color(glow_color.r, glow_color.g, glow_color.b,
				clamp(a, 0.1, 0.92))
