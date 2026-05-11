class_name OldMajor
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const SPEED: float = 150.0
const JUMP_VELOCITY: float = -380.0
const DOUBLE_JUMP_VELOCITY: float = -320.0
const GRAVITY: float = 980.0
const KNOCKBACK_FRICTION: float = 600.0

# =============================================================================
# Enums
# =============================================================================

enum State { IDLE, RUN, JUMP, FALL, HURT, DEAD }

# =============================================================================
# Public variables
# =============================================================================

var has_hay_bale: bool = false
var has_lantern: bool = false

# =============================================================================
# Private variables
# =============================================================================

var _state: State = State.IDLE
var _can_double_jump: bool = false
var _lantern_active: bool = false
var _is_invincible: bool = false
var _knockback: Vector2 = Vector2.ZERO

# =============================================================================
# @onready variables
# =============================================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_timer: Timer = $HurtTimer
@onready var lantern_area: Area2D = $LanternArea

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(&"player")
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	lantern_area.monitoring = false


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Horizontal movement
	var direction: float = Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	# Jump / double-jump
	if Input.is_action_just_pressed(&"ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			_can_double_jump = has_hay_bale
		elif _can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			_can_double_jump = false

	# Lantern ability
	if Input.is_action_just_pressed(&"interact") and has_lantern:
		_activate_lantern()

	# Apply knockback — overrides velocity when active
	if _knockback != Vector2.ZERO:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)

	move_and_slide()
	_update_state()
	_update_animation()

# =============================================================================
# Public methods
# =============================================================================

func take_damage(damage_source_position: Vector2) -> void:
	if _is_invincible or _state == State.DEAD:
		return
	_is_invincible = true
	_state = State.HURT
	_knockback = (global_position - damage_source_position).normalized() * 200.0
	hurt_timer.start(1.0)
	# Notify the scene coordinator — it lives in the same group on the tree root.
	_get_coordinator().on_player_died()


func collect_hay_bale() -> void:
	has_hay_bale = true
	_can_double_jump = true


func collect_lantern() -> void:
	has_lantern = true


func collect_key() -> void:
	_get_coordinator().on_key_collected()


func collect_secret_scroll() -> void:
	GameState.has_secret_scroll = true


func rescue_lamb() -> void:
	_get_coordinator().on_lamb_rescued()

# =============================================================================
# Private methods
# =============================================================================

func _update_state() -> void:
	if _state == State.HURT:
		return
	if velocity.y < -50.0:
		_state = State.JUMP
	elif velocity.y > 50.0:
		_state = State.FALL
	elif abs(velocity.x) > 10.0:
		_state = State.RUN
	else:
		_state = State.IDLE


func _update_animation() -> void:
	match _state:
		State.IDLE: animated_sprite.play(&"idle")
		State.RUN:  animated_sprite.play(&"run")
		State.JUMP: animated_sprite.play(&"jump")
		State.FALL: animated_sprite.play(&"fall")
		State.HURT: animated_sprite.play(&"hit")
		State.DEAD: animated_sprite.play(&"dead")


func _activate_lantern() -> void:
	if _lantern_active:
		return
	_lantern_active = true
	lantern_area.monitoring = true
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	_lantern_active = false
	lantern_area.monitoring = false


func _get_coordinator() -> OldMajorPlatformer:
	var nodes: Array = get_tree().get_nodes_in_group(&"act1_coordinator")
	if nodes.is_empty():
		push_error("OldMajor: no act1_coordinator found in scene tree")
		return null
	return nodes[0] as OldMajorPlatformer

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_hurt_timer_timeout() -> void:
	_is_invincible = false
	if _state == State.HURT:
		_state = State.IDLE
