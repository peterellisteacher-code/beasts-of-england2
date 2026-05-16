## Ported from gdquest-demos/godot-open-rpg src/combat/actions/battler_action_attack.gd
class_name BattleCryAction
extends TacticsAction

## Pushes the nearest adjacent dog 1 cell away from the actor.
## Ported from gdquest-demos/godot-open-rpg src/combat/actions/battler_action_attack.gd

# =============================================================================
# Public methods
# =============================================================================

func execute(actor: UnitBase, coordinator: Node) -> void:
	var politics: PoliticsTactics = coordinator as PoliticsTactics
	if politics == null:
		return

	# Find the first living dog that is Manhattan-distance 1 from actor.
	for dog: UnitBase in politics.get_dogs():
		if dog.hp <= 0:
			continue
		var dist: int = abs(dog.grid_pos.x - actor.grid_pos.x) + abs(dog.grid_pos.y - actor.grid_pos.y)
		if dist == 1:
			var push_dir: Vector2i = dog.grid_pos - actor.grid_pos
			var new_pos: Vector2i = dog.grid_pos + push_dir
			# push_unit returns true only if the push actually succeeded.
			if politics.push_unit(dog, new_pos):
				politics.show_feedback("Snowball cries out — the dog recoils!")
			else:
				politics.show_feedback("Snowball cries out — but the dog holds its ground!")
			return
	# No adjacent dog found.
	politics.show_feedback("Battle Cry: no enemy close enough to push.")
