class_name BoxerTopdown
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const ACCELERATION: float = 600.0
const MAX_SPEED: float = 120.0
const FRICTION: float = 600.0
const CHARGE_SPEED: float = 250.0

# =============================================================================
# Public variables
# =============================================================================

var can_move: bool = true

# =============================================================================
# Private variables
# =============================================================================

var _is_charging: bool = false
var _charge_direction: Vector2 = Vector2.ZERO

# =============================================================================
# Onready references
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var charge_hitbox: Area2D = $ChargeHitbox

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	var input_vector: Vector2 = _get_input_vector()

	if _is_charging:
		velocity = velocity.move_toward(_charge_direction * CHARGE_SPEED, ACCELERATION * delta)
		# Charge ends once speed drops below half charge speed
		if velocity.length() <= CHARGE_SPEED * 0.5:
			_is_charging = false
			charge_hitbox.monitoring = false
	elif input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
		_update_sprite_direction(input_vector)
		animated_sprite.play("run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		animated_sprite.play("idle")

	# Charge attack (Space / ui_accept) — only when moving and not already charging
	if Input.is_action_just_pressed("ui_accept") and not _is_charging and input_vector != Vector2.ZERO:
		_is_charging = true
		_charge_direction = input_vector
		charge_hitbox.monitoring = true

	move_and_slide()

# =============================================================================
# Private methods
# =============================================================================

func _get_input_vector() -> Vector2:
	var iv: Vector2 = Vector2.ZERO
	iv.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	iv.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return iv.normalized()


func _update_sprite_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		animated_sprite.flip_h = direction.x < 0
