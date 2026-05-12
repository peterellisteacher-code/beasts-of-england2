## Ported from gdquest-demos/godot-open-rpg src/combat/actions/battler_action.gd
class_name TacticsAction
extends Resource

## Abstract base for all Act 4 player actions.
## Ported from gdquest-demos/godot-open-rpg src/combat/actions/battler_action.gd

# =============================================================================
# @export variables
# =============================================================================

@export var action_name: String = "Action"
@export var description: String = ""

# =============================================================================
# Public methods
# =============================================================================

## Override in subclasses. Executes the action; coordinator provides grid access.
func execute(_actor: UnitBase, _coordinator: Node) -> void:
	pass
