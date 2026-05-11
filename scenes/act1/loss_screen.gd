extends Node2D

func _ready() -> void:
	$RestartButton.pressed.connect(_on_restart)
	$MainMenuButton.pressed.connect(_on_main_menu)

func _on_restart() -> void:
	GameState.hearts = 3
	GameState.has_secret_scroll = false
	get_tree().change_scene_to_file("res://scenes/act1/old_major_platformer.tscn")

func _on_main_menu() -> void:
	GameState.hearts = 3
	get_tree().change_scene_to_file("res://scenes/opening/opening.tscn")
