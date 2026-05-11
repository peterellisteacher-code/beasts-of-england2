class_name BattleLoss
extends Node2D

# =============================================================================
# Onready references
# =============================================================================

@onready var _retry_button: Button = $RetryButton

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/act3/cowshed_overworld.tscn")
