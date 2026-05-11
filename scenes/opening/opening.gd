class_name Opening
extends Node2D

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
	SceneManager.go_to_scene("res://scenes/act1/old_major_platformer.tscn")
