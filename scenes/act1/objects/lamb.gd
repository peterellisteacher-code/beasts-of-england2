extends CharacterBody2D

## The lamb that Old Major must rescue and escort to the barn.

const GRAVITY: float = 980.0
const FOLLOW_SPEED: float = 90.0
const FOLLOW_DISTANCE: float = 55.0

var is_following: bool = false
var _player: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_zone: Area2D = $PickupZone

func _ready() -> void:
	pickup_zone.body_entered.connect(_on_pickup_zone_body_entered)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_following and is_instance_valid(_player):
		var offset := _player.global_position - global_position
		if offset.length() > FOLLOW_DISTANCE:
			velocity.x = sign(offset.x) * FOLLOW_SPEED
			sprite.flip_h = velocity.x < 0
			sprite.play("walk")
		else:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			sprite.play("idle")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		sprite.play("idle")

	move_and_slide()

func _on_pickup_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_following:
		is_following = true
		_player = body
		# Tell the player (and through it, the level) the lamb is rescued
		if body.has_method("rescue_lamb"):
			body.rescue_lamb()
