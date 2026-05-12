class_name JonesMan
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const MAX_SPEED: float = 60.0
const CHASE_SPEED: float = 90.0
const ACCELERATION: float = 300.0
const FRICTION: float = 200.0
const GRAVITY: float = 980.0

# =============================================================================
# Enums
# =============================================================================

enum State { PATROL, CHASE, STUNNED, DEAD }

# =============================================================================
# Private variables
# =============================================================================

var _state: State = State.PATROL
var _patrol_direction: float = 1.0
var _patrol_timer: float = 2.0
var _player: Node2D = null

# =============================================================================
# @onready variables
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_zone: Area2D = $DetectionZone
@onready var left_wall_checker: RayCast2D = $LeftWallChecker
@onready var right_wall_checker: RayCast2D = $RightWallChecker

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(&"enemy")
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)


func _physics_process(delta: float) -> void:
	if _state == State.STUNNED or _state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	# Gravity always applies
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match _state:
		State.CHASE:
			if is_instance_valid(_player):
				_accelerate_towards_point(_player.global_position, delta)
			else:
				_state = State.PATROL

		State.PATROL:
			_patrol_timer -= delta
			var hit_right_wall: bool = right_wall_checker.is_colliding() and _patrol_direction > 0.0
			var hit_left_wall: bool = left_wall_checker.is_colliding() and _patrol_direction < 0.0
			if _patrol_timer <= 0.0 or hit_right_wall or hit_left_wall:
				_patrol_direction *= -1.0
				_patrol_timer = randf_range(1.5, 3.0)

			velocity.x = move_toward(velocity.x, _patrol_direction * MAX_SPEED, ACCELERATION * delta)
			animated_sprite.flip_h = velocity.x < 0.0

			if abs(velocity.x) > 10.0:
				animated_sprite.play(&"walk")
			else:
				animated_sprite.play(&"idle")

	move_and_slide()

# =============================================================================
# Private methods
# =============================================================================

## Ported from Lango-Zelda-RPG Enemy.gd — accelerate_towards_point()
func _accelerate_towards_point(target_pos: Vector2, delta: float) -> void:
	var direction: Vector2 = global_position.direction_to(target_pos)
	velocity.x = move_toward(velocity.x, direction.x * CHASE_SPEED, ACCELERATION * delta)
	animated_sprite.flip_h = velocity.x < 0.0
	animated_sprite.play(&"walk")

# =============================================================================
# Public methods
# =============================================================================

func stun(duration: float = 2.0) -> void:
	if _state == State.DEAD:
		return
	_state = State.STUNNED
	_player = null
	animated_sprite.play(&"stun")
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	if _state != State.DEAD:
		_state = State.PATROL


func take_hit() -> void:
	_state = State.DEAD
	_player = null
	animated_sprite.play(&"death")
	await animated_sprite.animation_finished
	if is_instance_valid(self):
		queue_free()

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_detection_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and _state == State.PATROL:
		_player = body
		_state = State.CHASE


func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		if _state == State.CHASE:
			_state = State.PATROL
