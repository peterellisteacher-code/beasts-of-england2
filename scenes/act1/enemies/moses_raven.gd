class_name MosesRaven
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const SWOOP_SPEED: float = 120.0
const SWOOP_FREQUENCY: float = 2.0
const Y_LERP_SPEED: float = 5.0

# =============================================================================
# Export variables
# =============================================================================

@export var swoop_amplitude: float = 80.0

# =============================================================================
# Private variables
# =============================================================================

var _time_offset: float = 0.0
var _base_y: float = 0.0
var _moving_right: bool = true

# =============================================================================
# @onready variables
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(&"enemy")
	_base_y = global_position.y
	_time_offset = randf() * TAU
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _physics_process(delta: float) -> void:
	_time_offset += delta * SWOOP_FREQUENCY

	var x_dir: float = 1.0 if _moving_right else -1.0
	velocity.x = x_dir * SWOOP_SPEED

	var target_y: float = _base_y + sin(_time_offset) * swoop_amplitude
	velocity.y = (target_y - global_position.y) * Y_LERP_SPEED

	animated_sprite.flip_h = not _moving_right
	animated_sprite.play(&"fly")

	move_and_slide()

	if is_on_wall():
		_moving_right = not _moving_right

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		body.take_damage(global_position)
