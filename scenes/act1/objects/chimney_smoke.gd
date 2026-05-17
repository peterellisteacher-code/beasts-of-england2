## Soft chimney smoke — puffs rise from the barn roof, expand, drift and fade.
## Pure GDScript (no GPUParticles) so it is safe on the gl_compatibility
## web renderer. Attach to a Node2D placed at the chimney mouth.
extends Node2D

const PUFF_TEX: String = "res://assets/sprites/ui/lantern_light.png"

@export var spawn_interval: float = 1.05
@export var rise_speed: float = 26.0
@export var puff_lifetime: float = 5.0
@export var puff_tint: Color = Color(0.60, 0.62, 0.70)

var _tex: Texture2D
var _spawn_t: float = 0.4
var _puffs: Array[Dictionary] = []


func _ready() -> void:
	_tex = load(PUFF_TEX) as Texture2D


func _process(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = spawn_interval
		_spawn_puff()

	for i: int in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		var sp: Sprite2D = p["node"]
		if not is_instance_valid(sp):
			_puffs.remove_at(i)
			continue
		p["age"] += delta
		var t: float = p["age"] / puff_lifetime
		if t >= 1.0:
			sp.queue_free()
			_puffs.remove_at(i)
			continue
		sp.position.y -= rise_speed * delta
		sp.position.x += sin(p["age"] * 1.2 + p["phase"]) * 14.0 * delta
		var s: float = lerp(p["s0"], p["s0"] * 2.7, t)
		sp.scale = Vector2(s, s)
		# Quick fade-in, long fade-out.
		var a: float = (t / 0.18) if t < 0.18 else (1.0 - (t - 0.18) / 0.82)
		sp.modulate.a = clamp(a, 0.0, 1.0) * 0.5


func _spawn_puff() -> void:
	var sp: Sprite2D = Sprite2D.new()
	sp.texture = _tex
	sp.modulate = Color(puff_tint.r, puff_tint.g, puff_tint.b, 0.0)
	var s0: float = randf_range(0.22, 0.34)
	sp.scale = Vector2(s0, s0)
	sp.position = Vector2(randf_range(-7.0, 7.0), 0.0)
	add_child(sp)
	_puffs.append({"node": sp, "age": 0.0, "s0": s0, "phase": randf_range(0.0, TAU)})
