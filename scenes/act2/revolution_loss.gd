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
	get_tree().change_scene_to_file("res://scenes/act2/boxer_revolution.tscn")
