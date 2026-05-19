## Optional secret scroll pickup — a torn scrap of Old Major's writing.
## Player overlaps + presses E → question via coordinator → sets GameState flag,
## shows a caption, and frees self. Never blocks progress to the barn.
##
## Spec: active.md §4 "objects/secret_scroll.gd".
class_name SecretScroll
extends Area2D

# =============================================================================
# Constants
# =============================================================================

## Caption shown on pickup (after question resolves).
const PICKUP_CAPTION: String = \
	"A torn scrap in old Major's own hand: \"Man is the only real enemy we have.\""

# =============================================================================
# Private state
# =============================================================================

var _player_nearby: bool = false
var _used: bool = false
var _t: float = 0.0

# =============================================================================
# @onready references
# =============================================================================

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _prompt: Label    = $Prompt

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_prompt.visible = false
	_prompt.text = "[E] Read"
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _used:
		return
	_t += delta
	# Gentle float bob.
	if _sprite:
		_sprite.position.y = sin(_t * 2.2) * 5.0


func _unhandled_input(event: InputEvent) -> void:
	if _used or not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_activate()

# =============================================================================
# Private methods
# =============================================================================

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = true
		_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_nearby = false
		_prompt.visible = false


func _activate() -> void:
	_used = true
	_prompt.visible = false

	var coordinator: Node = get_tree().get_first_node_in_group(&"act1_coordinator")
	if coordinator != null and coordinator.has_method("ask_question"):
		await coordinator.ask_question(&"scroll")

	GameState.has_secret_scroll = true

	# Show the pickup caption via the StealthHUD.
	var hud: Node = get_tree().get_first_node_in_group(&"stealth_hud")
	if hud != null and hud.has_method("show_caption"):
		hud.show_caption(PICKUP_CAPTION, 5.0)

	queue_free()
