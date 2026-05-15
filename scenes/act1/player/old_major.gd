## Simple walking-simulator controller for Old Major's Act 1 night walk.
## Stripped of all combat/platformer mechanics — Old Major walks left-to-right
## across a single flat path, carrying a lantern, while Moses circles overhead.
## Quiz gate at the barn door handles the act transition.
class_name OldMajor
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const SPEED: float = 140.0
const GRAVITY: float = 980.0

# =============================================================================
# Public variables
# =============================================================================

var can_move: bool = true

# =============================================================================
# @onready variables
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(&"player")
	animated_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if can_move:
		var direction: float = Input.get_axis(&"move_left", &"move_right")
		if direction != 0.0:
			velocity.x = direction * SPEED
			animated_sprite.flip_h = direction < 0.0
			if animated_sprite.animation != &"run":
				animated_sprite.play(&"run")
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)
			if animated_sprite.animation != &"idle":
				animated_sprite.play(&"idle")
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0)

	move_and_slide()

# =============================================================================
# Public methods — unused stubs kept for API compatibility with other acts
# =============================================================================

func collect_hay_bale() -> void:
	pass


func collect_lantern() -> void:
	pass


func collect_key() -> void:
	# Notify the level coordinator so it can track key count for door logic.
	var coordinator: Node = get_tree().get_first_node_in_group(&"act1_coordinator")
	if coordinator != null and coordinator.has_method(&"on_key_collected"):
		coordinator.on_key_collected()


func collect_secret_scroll() -> void:
	GameState.has_secret_scroll = true


func rescue_lamb() -> void:
	pass


func take_damage(_damage_source_position: Vector2) -> void:
	# No-fail walk — damage is a no-op.
	pass
