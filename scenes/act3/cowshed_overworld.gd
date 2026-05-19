## Ported from Lango-Zelda-RPG Levels/DangeonEntrace.gd + GDQuest core/world/Door.gd
class_name CowshedOverworld
extends Node2D

# =============================================================================
# Constants
# =============================================================================

## Five visible enemies stand in the farmyard; the sixth (Mr Jones) is the
## secret boss, revealed only once the five men are beaten.
const TOTAL_BATTLES: int = 6

# =============================================================================
# Onready references
# =============================================================================

@onready var _encounter_zones: Array[Area2D] = []

# One-shot guard — repeated body_entered events must not queue duplicate battle
# loads. The scene is re-instantiated on each return, so it never needs resetting.
var _battle_starting: bool = false

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# Collect and wire the four encounter zones
	for i: int in range(TOTAL_BATTLES):
		var zone_name: String = "World/EncounterZone" + str(i + 1)
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
	if _battle_starting:
		return
	# Only allow entering the current (next unfinished) battle
	if battle_index != GameState.battle_wins:
		return
	_battle_starting = true
	GameState.save_to_disk()
	get_tree().set_meta("battle_index", battle_index)
	SceneManager.go_to_scene("res://scenes/act3/battle/battle_scene.tscn")


func _update_encounter_zones() -> void:
	# Enable only the zone matching the next battle to win.
	var next_battle: int = GameState.battle_wins
	for i: int in range(_encounter_zones.size()):
		var is_current: bool = (i == next_battle)
		_encounter_zones[i].monitoring = is_current
		_encounter_zones[i].monitorable = is_current
		# Only the current enemy stands in the farmyard — beaten enemies are
		# gone, and later ones (the secret Mr Jones included) stay hidden
		# until it is their turn.
		var enemy: CanvasItem = _encounter_zones[i].get_node_or_null(^"Enemy") as CanvasItem
		if enemy != null:
			enemy.visible = is_current


func _check_act_complete() -> void:
	# Guard: only run act-complete logic once — if current_act has already advanced
	# past 3, corrupt_commandment and complete_act have already fired.
	if GameState.battle_wins >= TOTAL_BATTLES and GameState.current_act <= 3:
		GameState.corrupt_commandment(2)
		GameState.complete_act(3)
		SceneManager.go_to_scene("res://scenes/act4/windmill_case.tscn")
