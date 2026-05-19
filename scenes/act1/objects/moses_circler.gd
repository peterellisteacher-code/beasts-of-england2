## Moses the raven — stealth threat AI. Patrols the sky horizontally, casting a
## downward vision cone. Three-state FSM ported from lango-zelda-rpg/Enemy.gd
## (MIT, Godot 3 → Godot 4 conversion). PATROL → ALERT (cone red, ! visible,
## player.mark_seen()) ↔ SUSPICIOUS (cone orange, scanning hover) → PATROL.
##
## No GPUParticles (gl_compatibility). All visual feedback is code-driven or
## via ConeVisual (Polygon2D child) and AlertIcon (Label child).
##
## Spec: active.md §4 "objects/moses_circler.gd".
class_name MosesRaven
extends AnimatedSprite2D

# =============================================================================
# Constants — tune in spec §5
# =============================================================================

## Horizontal patrol bounds (world-space x).
const PATROL_X_MIN: float = 350.0
const PATROL_X_MAX: float = 2250.0
## Cruising altitude (world-space y).
const PATROL_Y: float = 190.0

const PATROL_SPEED: float = 110.0
## Gentle sine-bob amplitude and frequency during patrol.
const BOB_AMP: float = 14.0
const BOB_SPEED: float = 1.8   # rad/s

## Vision cone parameters.
const CONE_HALF_ANGLE_DEG: float = 32.0
const CONE_RANGE: float = 340.0

## How long Moses hovers in SUSPICIOUS before returning to PATROL.
const SUSPICIOUS_DURATION: float = 2.0
## How fast Moses drifts toward the player's x in ALERT.
const ALERT_DRIFT_SPEED: float = 60.0

## Cone colours per state — (r,g,b,a).
const CONE_COL_PATROL:     Color = Color(0.55, 0.62, 0.85, 0.18)
const CONE_COL_SUSPICIOUS: Color = Color(0.95, 0.65, 0.2, 0.28)
const CONE_COL_ALERT:      Color = Color(0.85, 0.2, 0.2, 0.34)

## Collision mask bit for cover_blocker layer (layer 3 → bit 2, 1-indexed → mask value 4).
const COVER_BLOCKER_MASK: int = 4

# =============================================================================
# FSM state enum
# =============================================================================

enum State { PATROL, SUSPICIOUS, ALERT }

# =============================================================================
# Private state
# =============================================================================

var _state: State = State.PATROL
var _dir: float = 1.0          # +1 right, -1 left
var _t: float = 0.0            # phase timer (bob + suspicious timer)
var _suspicious_timer: float = 0.0
var _player: OldMajor = null

# =============================================================================
# @onready references
# =============================================================================

@onready var _cone: Polygon2D      = $ConeVisual
@onready var _sight: RayCast2D     = $Sight
@onready var _alert_icon: Label    = $AlertIcon
@onready var _raven_caw: AudioStreamPlayer2D = $RavenCaw

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	play(&"fly")
	_find_player()
	# Position at start of patrol range.
	global_position = Vector2(PATROL_X_MIN + 100.0, PATROL_Y)
	_build_cone()
	_update_cone_colour()
	_alert_icon.visible = false
	_sight.collision_mask = COVER_BLOCKER_MASK
	_sight.enabled = true
	_schedule_caw()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	_t += delta

	# Always re-find the player lazily (avoids hard _ready ordering dependency).
	if _player == null:
		_find_player()

	match _state:
		State.PATROL:
			_do_patrol(delta)
			if _can_see_player():
				_enter_alert()

		State.SUSPICIOUS:
			_do_suspicious_bob(delta)
			_suspicious_timer -= delta
			if _can_see_player():
				_enter_alert()
			elif _suspicious_timer <= 0.0:
				_enter_patrol()

		State.ALERT:
			_do_alert_drift(delta)
			if _player != null and _player.has_method("mark_seen"):
				_player.mark_seen()
			if not _can_see_player():
				_enter_suspicious()


# =============================================================================
# FSM transitions
# =============================================================================

func _enter_patrol() -> void:
	_state = State.PATROL
	_alert_icon.visible = false
	_update_cone_colour()


func _enter_suspicious() -> void:
	_state = State.SUSPICIOUS
	_suspicious_timer = SUSPICIOUS_DURATION
	_alert_icon.visible = false
	_update_cone_colour()


func _enter_alert() -> void:
	_state = State.ALERT
	_alert_icon.visible = true
	_update_cone_colour()
	if _raven_caw and not _raven_caw.playing:
		_raven_caw.play()

# =============================================================================
# Per-state update methods
# =============================================================================

func _do_patrol(delta: float) -> void:
	# Horizontal cruise with gentle sine bob.
	global_position.x += _dir * PATROL_SPEED * delta
	global_position.y = PATROL_Y + sin(_t * BOB_SPEED) * BOB_AMP

	if global_position.x >= PATROL_X_MAX:
		_dir = -1.0
		flip_h = true
	elif global_position.x <= PATROL_X_MIN:
		_dir = 1.0
		flip_h = false


func _do_suspicious_bob(delta: float) -> void:
	# Hover in place with a scanning bob.
	global_position.y = PATROL_Y + sin(_t * BOB_SPEED * 2.5) * (BOB_AMP * 0.6)


func _do_alert_drift(delta: float) -> void:
	# Slowly drift toward the player's x position.
	if _player != null:
		var target_x: float = _player.global_position.x
		global_position.x = move_toward(global_position.x, target_x,
				ALERT_DRIFT_SPEED * delta)
	global_position.y = PATROL_Y + sin(_t * BOB_SPEED) * BOB_AMP

# =============================================================================
# Vision check
# =============================================================================

## Returns true when all conditions are met: player in range, within cone
## half-angle, RayCast LOS is clear (hay bales block it), and not hidden.
func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false

	var to_player: Vector2 = _player.global_position - global_position
	# Range check.
	if to_player.length() > CONE_RANGE:
		return false

	# Cone angle: compare to straight-down (Vector2.DOWN).
	var angle_rad: float = Vector2.DOWN.angle_to(to_player.normalized())
	if abs(rad_to_deg(angle_rad)) > CONE_HALF_ANGLE_DEG:
		return false

	# LOS raycast — target the player's centre.
	_sight.target_position = to_player
	_sight.force_raycast_update()
	if _sight.is_colliding():
		return false   # Blocked by hay bale or cover.

	# Hidden check — Moses cannot see a player tucked in shadow or behind cover.
	if _player.is_hidden:
		return false

	return true

# =============================================================================
# Helpers
# =============================================================================

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		_player = players[0] as OldMajor


func _update_cone_colour() -> void:
	if _cone == null:
		return
	match _state:
		State.PATROL:     _cone.color = CONE_COL_PATROL
		State.SUSPICIOUS: _cone.color = CONE_COL_SUSPICIOUS
		State.ALERT:      _cone.color = CONE_COL_ALERT


## Build the downward triangle Polygon2D for the vision cone.
## Apex at (0,0), base at CONE_RANGE below, half-width = tan(half_angle)*range.
func _build_cone() -> void:
	if _cone == null:
		return
	var half_w: float = tan(deg_to_rad(CONE_HALF_ANGLE_DEG)) * CONE_RANGE
	_cone.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(-half_w, CONE_RANGE),
		Vector2(half_w, CONE_RANGE),
	])
	_cone.color = CONE_COL_PATROL


func _schedule_caw() -> void:
	if _raven_caw == null:
		return
	var wait: float = randf_range(8.0, 22.0)
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(self):
		return
	if _state != State.ALERT and not get_tree().paused:
		_raven_caw.play()
	_schedule_caw()
