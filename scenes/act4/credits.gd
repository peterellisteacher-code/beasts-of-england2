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
	GameState.reset_all()
	SceneManager.go_to_scene("res://scenes/opening/opening.tscn")
