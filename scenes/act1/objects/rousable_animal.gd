## Sleeping animal that Old Major must rouse on the way to the barn.
## Walk up → pulsing E-prompt → press interact → woven question via coordinator →
## on correct/reveal: animal wakes, speaks its line, Old Major speaks, animal
## scurries toward the barn and fades out. Emits `roused` for the coordinator.
##
## Spec: active.md §4 "objects/rousable_animal.gd".
class_name RousableAnimal
extends Area2D

# =============================================================================
# Constants
# =============================================================================

const SLEEP_MODULATE: Color     = Color(0.66, 0.70, 0.80)   # night-tinted but visible
const AWAKE_MODULATE: Color     = Color(1.0, 1.0, 1.0)
const HIDDEN_MODULATE: Color    = Color(0.45, 0.5, 0.7)     # player dark-in-shadow

## Prompt pulse scale bounds.
const PULSE_MIN: float = 0.85
const PULSE_MAX: float = 1.15
const PULSE_SPEED: float = 3.0   # radians/sec

## How long it takes the animal to scurry off-screen after rousing.
const SCURRY_DURATION: float = 1.4
const SCURRY_FADE_DURATION: float = 0.9

## ZZZ bob amplitude.
const ZZZ_BOB_AMP: float = 4.0
const ZZZ_BOB_SPEED: float = 1.8

# =============================================================================
# Signals
# =============================================================================

## Emitted after the rouse sequence completes. Coordinator increments comrades.
signal roused(animal_id: StringName, world_pos: Vector2)

# =============================================================================
# Exports
# =============================================================================

## StringName matching a key in Act1Questions.QUESTIONS.
@export var animal_id: StringName = &"hen"

## World-space x-position the animal tweens toward on scurry.
@export var scurry_to_x: float = 2400.0

# =============================================================================
# Private state
# =============================================================================

var _asleep: bool = true
var _player_nearby: bool = false
var _rousing: bool = false
var _t: float = 0.0   # pulse/bob timer

# =============================================================================
# @onready references
# =============================================================================

@onready var _sprite: Sprite2D       = $Sprite2D
@onready var _prompt: Label          = $Prompt
@onready var _zzz: Label             = $Zzz

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_sprite.modulate = SLEEP_MODULATE
	_prompt.visible = false
	_prompt.text = "[E]"
	_zzz.visible = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if not _asleep or _rousing:
		return
	_t += delta

	# Pulse the E-prompt if player is nearby.
	if _player_nearby and _prompt.visible:
		var scale_val: float = lerp(PULSE_MIN, PULSE_MAX,
				(sin(_t * PULSE_SPEED) + 1.0) * 0.5)
		_prompt.scale = Vector2(scale_val, scale_val)

	# Bob the Zzz label while asleep.
	_zzz.position.y = -60.0 + sin(_t * ZZZ_BOB_SPEED) * ZZZ_BOB_AMP


func _unhandled_input(event: InputEvent) -> void:
	if _rousing or not _asleep or not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_begin_rouse()

# =============================================================================
# Private methods
# =============================================================================

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and _asleep:
		_player_nearby = true
		_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = false
		_prompt.visible = false


func _begin_rouse() -> void:
	_rousing = true
	_prompt.visible = false
	_zzz.visible = false

	# Ask the coordinator to spawn the question and await its result.
	var coordinator: Node = get_tree().get_first_node_in_group(&"act1_coordinator")
	if coordinator == null or not coordinator.has_method("ask_question"):
		# Fail-safe: rouse without a question.
		_finish_rouse()
		return

	await coordinator.ask_question(animal_id)
	_finish_rouse()


func _finish_rouse() -> void:
	_asleep = false
	_sprite.modulate = AWAKE_MODULATE

	# Emit roused FIRST so the coordinator advances the checkpoint and the
	# comrades counter immediately — not after the cosmetic caption delays.
	roused.emit(animal_id, global_position)

	# Show the animal's in-character waking line, then Old Major's reply.
	var coordinator: Act1Coordinator = \
		get_tree().get_first_node_in_group(&"act1_coordinator") as Act1Coordinator
	if coordinator != null:
		coordinator.show_animal_line(animal_id, false)
		await get_tree().create_timer(2.2).timeout
		if not is_instance_valid(self) or not is_instance_valid(coordinator):
			return
		coordinator.show_animal_line(animal_id, true)  # Old Major's line
		await get_tree().create_timer(2.4).timeout
		if not is_instance_valid(self):
			return

	# Scurry toward the barn and fade out.
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_sprite, "global_position:x",
			scurry_to_x, SCURRY_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate:a",
			0.0, SCURRY_FADE_DURATION).set_delay(SCURRY_DURATION - SCURRY_FADE_DURATION)
	await tween.finished
	if is_instance_valid(self):
		hide()
