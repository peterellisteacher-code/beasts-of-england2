class_name Opening
extends Control

# =============================================================================
# Private state
# =============================================================================

# Guard: prevent _on_start_pressed from being called multiple times before the
# deferred scene change executes (e.g. if the player holds a key or clicks the
# button while also triggering _input).
var _started: bool = false

# =============================================================================
# @onready variables
# =============================================================================

@onready var start_button: Button = $StartButton

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_start_pressed()

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_start_pressed() -> void:
	if _started:
		return
	_started = true
	# Use go_to_act(1) so GameState.current_act is always set to 1 before the
	# scene loads — bypassing this would leave current_act at whatever was saved
	# (e.g. act 3), causing reset_act_state() to reset the wrong act's data.
	SceneManager.go_to_act(1)
