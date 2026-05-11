class_name OldMajorPlatformer
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const GROUP_SCENE_COORDINATOR: StringName = &"act1_coordinator"

# =============================================================================
# Signals
# =============================================================================

signal key_count_changed(new_count: int)

# =============================================================================
# Public variables
# =============================================================================

var keys_collected: int = 0
var doors_unlocked: int = 0

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(GROUP_SCENE_COORDINATOR)
	GameState.hearts = 3
	GameState.hearts_changed.emit(GameState.hearts)
	$HeartsHUD.update_hearts(GameState.hearts)

# =============================================================================
# Public methods
# =============================================================================

func on_key_collected() -> void:
	keys_collected += 1
	key_count_changed.emit(keys_collected)


func on_door_unlocked() -> void:
	doors_unlocked += 1


func on_lamb_rescued() -> void:
	GameState.lamb_rescued = true


func on_player_died() -> void:
	GameState.hearts -= 1
	GameState.hearts_changed.emit(GameState.hearts)
	if GameState.hearts <= 0:
		SceneManager.go_to_scene("res://scenes/act1/loss_screen.tscn")
	else:
		get_tree().reload_current_scene()


func on_barn_reached() -> void:
	GameState.corrupt_commandment(0)
	GameState.complete_act(1)
	SceneManager.go_to_scene("res://scenes/act2/boxer_revolution.tscn")
