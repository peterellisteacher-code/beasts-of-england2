## Ported from Lango-Zelda-RPG Levels/DangeonEntrace.gd + GDQuest core/world/Door.gd
class_name CowshedOverworld
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const TOTAL_BATTLES: int = 4

# =============================================================================
# Onready references
# =============================================================================

@onready var _boxer_player: CharacterBody2D = $Player/BoxerOverworld
@onready var _encounter_zones: Array[Area2D] = []

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# Collect and wire the four encounter zones
	for i: int in range(TOTAL_BATTLES):
		var zone_name: String = "EncounterZone" + str(i + 1)
		var zone: Area2D = get_node_or_null(zone_name) as Area2D
		if zone == null:
			push_error("CowshedOverworld: missing node " + zone_name)
			continue
		_encounter_zones.append(zone)
		zone.body_entered.connect(_on_zone_body_entered.bind(i))

	_update_encounter_zones()
	_check_act_complete()

# =============================================================================
# Private methods
# =============================================================================

func _on_zone_body_entered(body: Node2D, battle_index: int) -> void:
	if body.is_in_group("player"):
		_try_start_battle(battle_index)


func _try_start_battle(battle_index: int) -> void:
	# Only allow entering the current (next unfinished) battle
	if battle_index != GameState.battle_wins:
		return
	GameState.save_to_disk()
	get_tree().set_meta("battle_index", battle_index)
	SceneManager.go_to_scene("res://scenes/act3/battle/battle_scene.tscn")


func _update_encounter_zones() -> void:
	# Enable only the zone matching the next battle to win
	var next_battle: int = GameState.battle_wins
	for i: int in range(_encounter_zones.size()):
		_encounter_zones[i].monitoring = (i == next_battle)
		_encounter_zones[i].monitorable = (i == next_battle)


func _check_act_complete() -> void:
	if GameState.battle_wins >= TOTAL_BATTLES:
		GameState.corrupt_commandment(2)
		GameState.complete_act(3)
		SceneManager.go_to_scene("res://scenes/act4/politics_tactics.tscn")
