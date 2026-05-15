class_name BoxerTopdown
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const ACCELERATION: float = 600.0
const MAX_SPEED: float = 120.0
const FRICTION: float = 600.0
const CHARGE_SPEED: float = 250.0
const CHARGE_DURATION: float = 0.45

# =============================================================================
# Public variables
# =============================================================================

var can_move: bool = true

# =============================================================================
# Private variables
# =============================================================================

var _is_charging: bool = false
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_time_left: float = 0.0

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
	# FIX: connect ChargeHitbox so charging actually affects jones men.
	# body_entered fires whenever a CharacterBody2D overlaps while monitoring=true.
	charge_hitbox.body_entered.connect(_on_charge_hit_body)


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	var input_vector: Vector2 = _get_input_vector()

	if _is_charging:
		_charge_time_left -= delta
		velocity = velocity.move_toward(_charge_direction * CHARGE_SPEED, ACCELERATION * delta)
		animated_sprite.play(&"attack")
		# Charge ends after a fixed duration OR if the player releases all
		# direction keys (lets the player cancel a runaway charge).
		if _charge_time_left <= 0.0 or input_vector == Vector2.ZERO:
			_end_charge()
	elif input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
		_update_sprite_direction(input_vector)
		animated_sprite.play(&"run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		animated_sprite.play(&"idle")

	# Charge attack (Space / Enter / E) — only when moving and not already charging
	if Input.is_action_just_pressed("interact") and not _is_charging and input_vector != Vector2.ZERO:
		_start_charge(input_vector)

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


func _start_charge(direction: Vector2) -> void:
	_is_charging = true
	_charge_direction = direction
	_charge_time_left = CHARGE_DURATION
	charge_hitbox.monitoring = true


func _end_charge() -> void:
	_is_charging = false
	_charge_time_left = 0.0
	charge_hitbox.monitoring = false
	# Bleed off the charge velocity so the player isn't propelled after release.
	velocity = velocity.move_toward(Vector2.ZERO, CHARGE_SPEED)


func _on_charge_hit_body(body: Node2D) -> void:
	# FIX: when the charge hitbox contacts a jones man, force them into FLEE
	# state immediately — the charge now has a real gameplay effect.
	if body.is_in_group("jones_man") and body.has_method("force_flee"):
		body.force_flee()
