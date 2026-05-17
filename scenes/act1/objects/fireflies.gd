## Ambient firefly effect — drifting glowing dots that follow a sine-wave path.
## Pure GDScript, no particle system required. Spawns N firefly nodes as
## lightweight Sprite2D children. Keeps gl_compatibility renderer happy.
extends Node2D

@export var count: int = 12
@export var spread_x: float = 2200.0
@export var spread_y: float = 80.0
@export var base_y: float = 540.0
@export var glow_color: Color = Color(0.85, 1.0, 0.55, 0.75)

var _flies: Array = []

const STAR_PATH: String = "res://assets/sprites/erw/props/star.png"

func _ready() -> void:
	var tex: Texture2D = load(STAR_PATH)
	for i in range(count):
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = tex
		sp.modulate = Color(glow_color.r, glow_color.g, glow_color.b,
				randf_range(0.3, 0.8))
		sp.scale = Vector2(0.35, 0.35)
		var fly_data: Dictionary = {
			"node": sp,
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(0.3, 0.9),
			"drift_x": randf_range(0.12, 0.35),
			"amp_y": randf_range(12.0, 35.0),
			"base_x": randf_range(0.0, spread_x),
		}
		sp.position = Vector2(fly_data["base_x"], base_y + randf_range(-20, 20))
		add_child(sp)
		_flies.append(fly_data)


func _process(delta: float) -> void:
	for fly in _flies:
		fly["phase"] += delta * fly["speed"]
		var sp: Sprite2D = fly["node"]
		sp.position.x += delta * fly["drift_x"] * 18.0
		if sp.position.x > spread_x:
			sp.position.x = 0.0
		sp.position.y = base_y + sin(fly["phase"]) * fly["amp_y"]
		# Gentle alpha pulse
		var a: float = 0.35 + sin(fly["phase"] * 1.7) * 0.3
		sp.modulate.a = clamp(a, 0.1, 0.85)
