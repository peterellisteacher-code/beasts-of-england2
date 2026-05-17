## Moses the raven — flies a gentle arc across the night sky, then perches on
## the barn roof when Old Major approaches. Plays raven-caw SFX at intervals.
extends AnimatedSprite2D

@export var arc_radius_x: float = 240.0
@export var arc_radius_y: float = 58.0
@export var fly_speed: float = 0.42
## Sky height Moses circles at (kept inside the camera view).
@export var sky_y: float = 300.0
## World-space x-position of the barn door (triggers perch behaviour)
@export var barn_x: float = 2400.0
## Player proximity (px) to barn that triggers the perch
@export var perch_trigger_dist: float = 700.0
## World position Moses lands on (barn roof)
@export var perch_pos: Vector2 = Vector2(2380.0, 235.0)

var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _perching: bool = false
var _player: Node2D = null
var _raven_audio: AudioStreamPlayer2D = null

## Arc flight toward perch point
var _arcing_to_perch: bool = false
var _arc_start: Vector2 = Vector2.ZERO
var _arc_progress: float = 0.0
const ARC_SPEED: float = 0.6


func _ready() -> void:
	play("fly")
	# Find player in group
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D
	# Centre the flight circle above Old Major so Moses stays on-screen
	# for the whole walk (fixes the "Moses invisible" report).
	if _player != null:
		_origin = Vector2(_player.global_position.x + 30.0, sky_y)
		global_position = _origin
	else:
		_origin = global_position
	# Find raven audio sibling (added to Moses node in scene)
	_raven_audio = get_node_or_null("RavenCaw")
	_schedule_caw()


func _process(delta: float) -> void:
	if _perching:
		return

	if _arcing_to_perch:
		_arc_progress += delta * ARC_SPEED
		var t: float = clamp(_arc_progress, 0.0, 1.0)
		# Smooth arc: lerp position with a vertical bow
		var lerped: Vector2 = _arc_start.lerp(perch_pos, t)
		lerped.y -= sin(t * PI) * 80.0  # bow upward mid-arc
		global_position = lerped
		# Sprite faces RIGHT — flip to face left when arcing leftward.
		flip_h = perch_pos.x < _arc_start.x
		if _arc_progress >= 1.0:
			global_position = perch_pos
			_perching = true
			play("perch")
			if _raven_audio:
				_raven_audio.play()
		return

	# Normal looping arc flight — circle centre drifts to stay above Old Major.
	_t += delta * fly_speed
	if _player != null:
		_origin.x = lerp(_origin.x, _player.global_position.x + 30.0,
				clamp(delta * 1.6, 0.0, 1.0))
	global_position = _origin + Vector2(cos(_t) * arc_radius_x, sin(_t) * arc_radius_y)
	# Sprite art faces RIGHT (verified against moses_perch.png); horizontal
	# velocity ∝ -sin(_t), so flip to face left when moving left (sin(_t) > 0).
	flip_h = sin(_t) > 0.0

	# Check if player is within trigger distance of barn
	if _player and not _arcing_to_perch:
		var dist_to_barn: float = abs(_player.global_position.x - barn_x)
		if dist_to_barn < perch_trigger_dist:
			_start_perch_arc()


func _start_perch_arc() -> void:
	_arcing_to_perch = true
	_arc_start = global_position
	_arc_progress = 0.0


func _schedule_caw() -> void:
	if _raven_audio == null:
		return
	var wait: float = randf_range(8.0, 20.0)
	await get_tree().create_timer(wait).timeout
	if not _perching and not _arcing_to_perch:
		_raven_audio.play()
	_schedule_caw()
