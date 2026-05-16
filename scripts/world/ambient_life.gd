extends Node2D
## Spawns ambient critters (hens, butterflies, crows) into the parent World so
## each critter y-sorts against the props by its own feet position. Hens/crows
## animate in place; butterflies also drift. No collision. Attach as a child of
## a y-sorted World node.

@export var hen_count: int = 3
@export var butterfly_count: int = 2
@export var crow_count: int = 1
## Spawn / wander bounds — kept below the building footprints so critters never
## sit on a roof or drift across a building.
@export var area: Rect2 = Rect2(340, 200, 800, 440)
@export var spawn_seed: int = 1

const HEN := "res://assets/sprites/critters/hen.png"
const BUTTERFLY := "res://assets/sprites/critters/butterfly.png"
const CROW := "res://assets/sprites/critters/crow.png"
const SHADOW := "res://assets/sprites/fx/shadow.png"
const HFRAMES := 4
const VFRAMES := 2
const FRAMES := 8

var _critters: Array = []
var _rng := RandomNumberGenerator.new()
var _world: Node = null


func _ready() -> void:
	_rng.seed = spawn_seed
	# Critters become direct children of World so they y-sort with the props.
	_world = get_parent()
	_spawn(HEN, hen_count, 0.15, 0.9, false, -30.0, 0.22)
	_spawn(CROW, crow_count, 0.24, 1.0, false, -30.0, 0.25)
	_spawn(BUTTERFLY, butterfly_count, 0.09, 0.65, true, -46.0, 0.13)


func _spawn(path: String, count: int, frame_time: float, scl: float, wander: bool,
		feet_off: float, shadow_scl: float) -> void:
	var tex: Texture2D = load(path)
	var shadow_tex: Texture2D = load(SHADOW)
	for _i in count:
		var critter := Node2D.new()
		critter.position = Vector2(
			_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.position.y, area.end.y))

		# Faint contact shadow for ground critters only. Butterflies (wander)
		# fly, so a ground shadow under them just reads as a detached shadow.
		if not wander:
			var shadow := Sprite2D.new()
			shadow.texture = shadow_tex
			shadow.modulate = Color(1, 1, 1, 0.24)
			shadow.scale = Vector2(shadow_scl, shadow_scl)
			critter.add_child(shadow)

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.hframes = HFRAMES
		spr.vframes = VFRAMES
		spr.frame = _rng.randi_range(0, FRAMES - 1)
		spr.scale = Vector2(scl, scl)
		# Feet offset: the critter node's position.y is the y-sort key.
		spr.offset = Vector2(0, feet_off)
		critter.add_child(spr)

		# Deferred: World is still instantiating its own children when this
		# AmbientLife child's _ready() runs.
		_world.add_child.call_deferred(critter)
		var vel := Vector2.ZERO
		if wander:
			vel = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(16.0, 34.0)
		_critters.append({
			"node": critter, "spr": spr, "ft": frame_time,
			"t": _rng.randf() * frame_time, "wander": wander, "vel": vel,
			"retarget": _rng.randf_range(0.8, 2.2),
		})


func _process(delta: float) -> void:
	for cr in _critters:
		cr["t"] -= delta
		if cr["t"] <= 0.0:
			cr["t"] += cr["ft"]
			var s: Sprite2D = cr["spr"]
			s.frame = wrapi(s.frame + 1, 0, FRAMES)
		if cr["wander"]:
			_wander(cr, delta)


func _wander(cr: Dictionary, delta: float) -> void:
	var node: Node2D = cr["node"]
	cr["retarget"] -= delta
	if cr["retarget"] <= 0.0:
		cr["retarget"] = _rng.randf_range(0.9, 2.4)
		cr["vel"] = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(16.0, 34.0)
	var vel: Vector2 = cr["vel"]
	var p: Vector2 = node.position + vel * delta
	if p.x < area.position.x or p.x > area.end.x:
		vel.x = -vel.x
	if p.y < area.position.y or p.y > area.end.y:
		vel.y = -vel.y
	cr["vel"] = vel
	node.position = Vector2(
		clampf(p.x, area.position.x, area.end.x),
		clampf(p.y, area.position.y, area.end.y))
	cr["spr"].flip_h = vel.x < 0.0
