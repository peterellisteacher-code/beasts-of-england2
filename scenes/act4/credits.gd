class_name Act4Credits
extends Node2D

# =============================================================================
# @onready variables
# =============================================================================

@onready var _play_again_btn: Button = %PlayAgainButton

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_play_again_btn.pressed.connect(_on_play_again)

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_play_again() -> void:
	# Reset all cross-act state via the canonical GameState API
	GameState.current_act = 1
	GameState.commandments_corrupted = 0
	GameState.hearts = 3
	GameState.has_secret_scroll = false
	GameState.lamb_rescued = false
	GameState.has_gatekeeper_bonus = false
	GameState.jones_men_driven_off = false
	GameState.boxer_moves = ["charge", "brace"]
	GameState.battle_wins = 0
	GameState.snowball_expelled = false
	GameState.save_to_disk()
	SceneManager.go_to_scene("res://scenes/opening/opening.tscn")
