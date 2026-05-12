## Ported from Lango-Zelda-RPG Levels/BossLevel.gd + GDQuest core/Game.gd
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
# Onready references
# =============================================================================

@onready var _hearts_hud: CanvasLayer = $HeartsHUD

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(GROUP_SCENE_COORDINATOR)
	# Read-and-restore: only reset to 3 on a fresh run (hearts exhausted or
	# first play).  Reloading mid-run after taking damage preserves the count.
	if GameState.hearts <= 0:
		GameState.hearts = 3
	_hearts_hud.update_hearts(GameState.hearts)
	_connect_doors()

# =============================================================================
# Public methods — called by child nodes / doors
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
	if GameState.hearts <= 0:
		SceneManager.go_to_scene("res://scenes/act1/loss_screen.tscn")
	else:
		get_tree().reload_current_scene()


func on_barn_reached(body: Node2D) -> void:
	# BarnDoor's Area2D detection layer also intersects the Ground StaticBody2D.
	# Only progress when the player itself enters.
	if not body is OldMajor:
		return
	GameState.corrupt_commandment(0)
	GameState.complete_act(1)
	SceneManager.go_to_scene("res://scenes/act2/boxer_revolution.tscn")

# =============================================================================
# Private methods
# =============================================================================

func _connect_doors() -> void:
	# GDQuest Game.gd wiring pattern: push key-count updates to doors so they
	# can gate themselves without calling get_parent().  Doors that do not
	# expose on_key_count_changed(count: int) are silently skipped.
	var doors: Array[Node] = get_tree().get_nodes_in_group(&"door")
	for door: Node in doors:
		if door.has_method(&"on_key_count_changed"):
			key_count_changed.connect(door.on_key_count_changed)
