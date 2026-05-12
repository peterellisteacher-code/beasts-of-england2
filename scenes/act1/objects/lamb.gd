## Ported from Lango-Zelda-RPG World/Chest.gd — proximity flag + state enum pattern
class_name Lamb
extends CharacterBody2D

## The lamb that Old Major must rescue and escort to the barn.

# =============================================================================
# Constants and enums
# =============================================================================

const GRAVITY: float = 980.0
const FOLLOW_SPEED: float = 90.0
const FOLLOW_DISTANCE: float = 55.0

enum LambState { WAITING, FOLLOWING, RESCUED }

# =============================================================================
# Public variables
# =============================================================================

var state: LambState = LambState.WAITING

# =============================================================================
# Private variables
# =============================================================================

var _player: Node2D = null
var _can_rescue: bool = false

# =============================================================================
# @onready variables
# =============================================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_zone: Area2D = $PickupZone

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(&"lambs")
	pickup_zone.body_entered.connect(_on_pickup_zone_body_entered)
	pickup_zone.body_exited.connect(_on_pickup_zone_body_exited)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		LambState.FOLLOWING:
			if is_instance_valid(_player):
				var offset: Vector2 = _player.global_position - global_position
				if offset.length() > FOLLOW_DISTANCE:
					velocity.x = sign(offset.x) * FOLLOW_SPEED
					sprite.flip_h = velocity.x < 0
					sprite.play("walk")
				else:
					velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
					sprite.play("idle")
		_:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			sprite.play("idle")

	move_and_slide()

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_pickup_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and state == LambState.WAITING:
		_can_rescue = true
		state = LambState.FOLLOWING
		_player = body
		# Tell the player (and through it, the level) the lamb is rescued
		if body.has_method("rescue_lamb"):
			body.rescue_lamb()


func _on_pickup_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_can_rescue = false
