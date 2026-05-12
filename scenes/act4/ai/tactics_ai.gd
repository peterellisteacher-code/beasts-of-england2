## Ported from gdquest-demos/godot-open-rpg src/combat/combat_ai_random.gd
class_name TacticsAI
extends Node

## Enemy AI node attached as a child of each dog unit.
## Delegates movement and attack to the coordinator, keeping AI logic
## decoupled from the combat loop — mirroring the CombatAI pattern from
## gdquest-demos/godot-open-rpg src/combat/combat_ai_random.gd

# =============================================================================
# Public methods
# =============================================================================

## Called by PoliticsTactics._run_ai_turn() for each living dog.
## Moves the dog toward Snowball, waits briefly, then attempts an attack.
func take_turn(unit: UnitBase, coordinator: PoliticsTactics) -> void:
	coordinator.move_dog_toward_snowball(unit)
	await get_tree().create_timer(0.3).timeout
	coordinator.try_dog_attack(unit)
