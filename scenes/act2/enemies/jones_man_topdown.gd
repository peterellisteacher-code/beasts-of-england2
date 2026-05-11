class_name JonesManTopdown
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const MAX_SPEED: float = 80.0
const ACCELERATION: float = 400.0
const FRICTION: float = 300.0
const FLEE_RANGE: float = 200.0
const FLEE_SPEED: float = 100.0
const REGROUP_DELAY: float = 5.0
const REGROUP_ENTRY_X: float = -50.0
const REGROUP_THRESHOLD_X: float = 200.0
const WANDER_SPEED_MULT: float = 0.5
const WANDER_MIN_TIME: float = 1.0
const WANDER_MAX_TIME: float = 2.5

# =============================================================================
# Enums
# =============================================================================

enum State { IDLE, WANDER, FLEE, DRIVEN_OFF, REGROUPING }

# =============================================================================
# Private variables
# =============================================================================

var _state: State = State.WANDER
var _wander_direction: Vector2 = Vector2.RIGHT
var _wander_timer: float = 0.0
var _player: Node2D = null

# =============================================================================
# Onready references
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_zone: Area2D = $DetectionZone

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group("jones_man")
	_wander_timer = randf_range(WANDER_MIN_TIME, WANDER_MAX_TIME * 1.5)
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	match _state:
		State.WANDER:
			_wander_behavior(delta)
			_check_player_proximity()
		State.FLEE:
			_flee_behavior(delta)
		State.REGROUPING:
			_regroup_behavior(delta)
		State.DRIVEN_OFF, State.IDLE:
			pass

	move_and_slide()

# =============================================================================
# Private methods
# =============================================================================

func _check_player_proximity() -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) < FLEE_RANGE:
		_state = State.FLEE


func _wander_behavior(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_wander_timer = randf_range(WANDER_MIN_TIME, WANDER_MAX_TIME)
	velocity = velocity.move_toward(_wander_direction * MAX_SPEED * WANDER_SPEED_MULT, ACCELERATION * delta)
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"walk"):
		animated_sprite.play(&"walk")


func _flee_behavior(delta: float) -> void:
	if _player == null:
		_state = State.WANDER
		return

	var flee_dir: Vector2 = (global_position - _player.global_position).normalized()
	velocity = velocity.move_toward(flee_dir * FLEE_SPEED, ACCELERATION * delta)

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"run"):
		animated_sprite.play(&"run")

	# Driven off when the node leaves the visible viewport rect
	var screen_rect: Rect2 = get_viewport().get_visible_rect()
	if not screen_rect.has_point(global_position):
		_state = State.DRIVEN_OFF
		_notify_driven_off()
		_schedule_regroup()


func _schedule_regroup() -> void:
	await get_tree().create_timer(REGROUP_DELAY).timeout
	# Guard: node may have been freed during the delay
	if not is_instance_valid(self):
		return
	if _state == State.DRIVEN_OFF:
		_state = State.REGROUPING
		global_position = Vector2(REGROUP_ENTRY_X, randf_range(100.0, 620.0))


func _regroup_behavior(delta: float) -> void:
	velocity = velocity.move_toward(Vector2(MAX_SPEED * WANDER_SPEED_MULT * 0.3, 0.0), ACCELERATION * delta)
	if global_position.x > REGROUP_THRESHOLD_X:
		_state = State.WANDER
		_notify_regrouped()


func _notify_driven_off() -> void:
	var scene_root: Node = get_parent()
	if scene_root != null and scene_root.has_method("on_jones_man_driven_off"):
		scene_root.on_jones_man_driven_off()


func _notify_regrouped() -> void:
	var scene_root: Node = get_parent()
	if scene_root != null and scene_root.has_method("on_jones_man_regrouped"):
		scene_root.on_jones_man_regrouped()
