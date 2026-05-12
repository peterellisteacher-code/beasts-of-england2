## State machine architecture ported from GDQuest "Make Pro 2D Games" (Godot 3→4)
## ref: Games Workshop/reference-library/04-strategy/gdquest-combat/actors/player/PlayerStateMachine.gd
## Extension: platformer gravity + double-jump + lantern ability for Old Major (Animal Farm)
class_name OldMajor
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const SPEED: float = 220.0
const JUMP_VELOCITY: float = -420.0
const DOUBLE_JUMP_VELOCITY: float = -360.0
const GRAVITY: float = 980.0
const KNOCKBACK_FRICTION: float = 600.0

# =============================================================================
# Enums
# =============================================================================

enum State { IDLE, RUN, JUMP, FALL, HURT, DEAD }

# =============================================================================
# Signals
# =============================================================================

signal state_changed(new_state: State)

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
	_enter_state(_state)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	# Gravity — always applies when airborne
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Apply knockback — overrides horizontal velocity when active
	if _knockback != Vector2.ZERO:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	else:
		_process_movement()

	move_and_slide()
	_update_state()

# =============================================================================
# Public methods
# =============================================================================

func take_damage(damage_source_position: Vector2) -> void:
	if _is_invincible or _state == State.DEAD:
		return
	_is_invincible = true
	_knockback = (global_position - damage_source_position).normalized() * 200.0
	hurt_timer.start(1.0)
	_change_state(State.HURT)
	var c := _get_coordinator()
	if c:
		c.on_player_died()


func collect_hay_bale() -> void:
	has_hay_bale = true
	_can_double_jump = true


func collect_lantern() -> void:
	has_lantern = true


func collect_key() -> void:
	var c := _get_coordinator()
	if c:
		c.on_key_collected()


func collect_secret_scroll() -> void:
	GameState.has_secret_scroll = true


func rescue_lamb() -> void:
	var c := _get_coordinator()
	if c:
		c.on_lamb_rescued()

# =============================================================================
# Private methods — state machine core
# =============================================================================

func _change_state(new_state: State) -> void:
	if _state == new_state:
		return
	_exit_state(_state)
	_state = new_state
	_enter_state(new_state)
	state_changed.emit(new_state)


func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			animated_sprite.play(&"idle")
		State.RUN:
			animated_sprite.play(&"run")
		State.JUMP:
			animated_sprite.play(&"jump")
		State.FALL:
			animated_sprite.play(&"fall")
		State.HURT:
			animated_sprite.play(&"hit")
		State.DEAD:
			animated_sprite.play(&"dead")
			set_physics_process(false)


func _exit_state(state: State) -> void:
	match state:
		State.HURT:
			# Invincibility is cleared by the timer callback, not on exit —
			# the timer may still be running if we somehow force a transition.
			pass
		State.DEAD:
			# Dead is a terminal state; nothing to clean up on exit.
			pass
		_:
			pass

# =============================================================================
# Private methods — per-frame logic
# =============================================================================

func _process_movement() -> void:
	var direction: float = Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	# Jump / double-jump — only when not in a locked state
	if _state not in [State.HURT, State.DEAD]:
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


func _update_state() -> void:
	# HURT and DEAD states are set externally — physics loop must not override them.
	if _state in [State.HURT, State.DEAD]:
		return

	var next_state: State
	if velocity.y < -50.0:
		next_state = State.JUMP
	elif velocity.y > 50.0:
		next_state = State.FALL
	elif abs(velocity.x) > 10.0:
		next_state = State.RUN
	else:
		next_state = State.IDLE

	if next_state != _state:
		_change_state(next_state)


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


func _get_coordinator() -> Node:
	var nodes: Array = get_tree().get_nodes_in_group(&"act1_coordinator")
	if nodes.is_empty():
		push_error("OldMajor: no act1_coordinator found in scene tree")
		return null
	return nodes[0]

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_hurt_timer_timeout() -> void:
	_is_invincible = false
	if _state == State.HURT:
		_change_state(State.IDLE)
