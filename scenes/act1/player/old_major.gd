## Old Major — stealth player controller for Act 1.
## Side-scrolling CharacterBody2D; moves left/right only with gravity.
## Detects `shadow` and `light` Area2D groups each frame.
## detection float 0→1 rises while exposed (in light OR Moses sees); drains while
## safe. At 1.0: emits `caught`; coordinator handles respawn.
##
## Spec: active.md §4 "player/old_major.gd".
class_name OldMajor
extends CharacterBody2D

# =============================================================================
# Constants
# =============================================================================

const SPEED: float   = 135.0
const GRAVITY: float = 980.0

## Seconds to fill detection from 0 → 1 when fully exposed.
const DETECT_FILL_SECS: float  = 1.3
## Seconds to drain detection from 1 → 0 when fully safe.
const DETECT_DRAIN_SECS: float = 0.7

## Sprite tint while hidden in shadow.
const HIDDEN_MODULATE: Color  = Color(0.45, 0.5, 0.7)
const NORMAL_MODULATE: Color  = Color(1.0, 1.0, 1.0)

# =============================================================================
# Signals
# =============================================================================

signal caught

# =============================================================================
# Public properties
# =============================================================================

## True when overlapping ≥1 Area2D in the `shadow` group. Read by Moses.
var is_hidden: bool = false

## True when overlapping ≥1 Area2D in the `light` group.
var is_in_light: bool = false

## 0..1. Read by the StealthHUD each frame.
var detection: float = 0.0

## Set false to freeze player during question panels / finale dialogue.
var can_move: bool = true

# =============================================================================
# Private state
# =============================================================================

## Set true by Moses each frame it can see us; cleared at the start of each frame.
var _seen_by_moses: bool = false
## Guard to prevent re-emitting `caught` before the coordinator has respawned us.
var _is_caught: bool = false

# =============================================================================
# @onready references
# =============================================================================

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _body_sensor: Area2D    = $BodySensor

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(&"player")
	_anim.flip_h = true   # sprite art faces left; flip so he walks right.
	_anim.play(&"idle")
	_body_sensor.area_entered.connect(_on_area_entered)
	_body_sensor.area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	# Gravity — keep him on the ground.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Horizontal movement.
	if can_move:
		var dir: float = Input.get_axis(&"move_left", &"move_right")
		if dir != 0.0:
			velocity.x = dir * SPEED
			_anim.flip_h = dir > 0.0
			if _anim.animation != &"run":
				_anim.play(&"run")
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)
			if _anim.animation != &"idle":
				_anim.play(&"idle")
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0)
		if _anim.animation != &"idle":
			_anim.play(&"idle")

	move_and_slide()

	# Detection accumulation.
	_update_detection(delta)

	# Reset moses-seen flag; Moses will re-set it if still visible this frame.
	_seen_by_moses = false


## Called by Moses every frame it can see us.
func mark_seen() -> void:
	_seen_by_moses = true

# =============================================================================
# Public API
# =============================================================================

## Teleport the player to a checkpoint position after being caught.
func respawn_at(pos: Vector2) -> void:
	global_position = pos
	detection = 0.0
	_is_caught = false
	velocity = Vector2.ZERO


## Freeze movement during question panels or the barn finale.
func freeze_for_question() -> void:
	can_move = false


## Unfreeze after a question panel dismisses.
func unfreeze() -> void:
	can_move = true


## Let the coordinator enable/disable input explicitly.
func set_input_enabled(enabled: bool) -> void:
	can_move = enabled

# =============================================================================
# Private methods
# =============================================================================

func _update_detection(delta: float) -> void:
	# No detection accrual while caught, or while frozen (the barn finale) —
	# this prevents a spurious catch during the finale's scripted dialogue.
	if _is_caught or not can_move:
		return

	# Determine exposure.
	var exposed: bool = is_in_light or _seen_by_moses

	if exposed:
		detection += delta / DETECT_FILL_SECS
	else:
		detection -= delta / DETECT_DRAIN_SECS

	detection = clampf(detection, 0.0, 1.0)

	# Update visual tint.
	_anim.modulate = HIDDEN_MODULATE if is_hidden else NORMAL_MODULATE

	# Emit caught at threshold.
	if detection >= 1.0 and not _is_caught:
		_is_caught = true
		detection = 1.0
		caught.emit()

# =============================================================================
# Shadow / light sensor
# =============================================================================

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"shadow"):
		is_hidden = _count_overlapping_group(&"shadow") > 0
	if area.is_in_group(&"light"):
		is_in_light = _count_overlapping_group(&"light") > 0


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group(&"shadow"):
		# Re-check: there may still be other shadow areas overlapping.
		is_hidden = _count_overlapping_group(&"shadow") > 0
	if area.is_in_group(&"light"):
		is_in_light = _count_overlapping_group(&"light") > 0


func _count_overlapping_group(group: StringName) -> int:
	var count: int = 0
	for area: Area2D in _body_sensor.get_overlapping_areas():
		if area.is_in_group(group):
			count += 1
	return count
