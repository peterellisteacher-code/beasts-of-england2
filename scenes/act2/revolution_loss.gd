class_name RevolutionLoss
extends Node2D

# =============================================================================
# Onready references
# =============================================================================

@onready var retry_button: Button = $RetryButton

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	retry_button.pressed.connect(_on_retry)

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_retry() -> void:
	# FIX: use SceneManager (deferred change_scene_to_file) for consistency with
	# all other scene transitions in the game.
	SceneManager.go_to_scene("res://scenes/act2/boxer_revolution.tscn")
