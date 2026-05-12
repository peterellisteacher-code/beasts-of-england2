## Ported from gdquest-demos/godot-open-rpg src/combat/actions/battler_action_modify_stats.gd
class_name WindmillAction
extends TacticsAction

## Grants actor +2 defence bonus until the end of the AI turn.
## Ported from gdquest-demos/godot-open-rpg src/combat/actions/battler_action_modify_stats.gd

# =============================================================================
# Public methods
# =============================================================================

func execute(actor: UnitBase, coordinator: Node) -> void:
	actor.defense_bonus = 2
	var politics: PoliticsTactics = coordinator as PoliticsTactics
	if politics:
		politics.show_feedback("Snowball shows his Windmill blueprints... (+2 Defence next turn)")
