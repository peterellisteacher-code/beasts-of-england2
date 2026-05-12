## Ported from gdquest-demos/godot-open-rpg src/combat/battlers/battler.gd + battler_stats.gd
class_name UnitBase
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const COLOR_DAMAGED: Color = Color(1.0, 0.3, 0.3, 1.0)
const COLOR_NORMAL: Color  = Color(1.0, 1.0, 1.0, 1.0)

# =============================================================================
# Signals
# =============================================================================

signal hp_changed(new_hp: int, max_hp_value: int)
signal unit_died

# =============================================================================
# @export variables
# =============================================================================

@export var unit_display_name: String = "Unit"
@export var max_hp: int = 6
@export var attack: int = 3
@export var move_range: int = 2
@export var is_player: bool = false

# =============================================================================
# Public variables
# =============================================================================

var hp: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var defense_bonus: int = 0
var cached_action: TacticsAction = null

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	hp = max_hp

# =============================================================================
# Public methods
# =============================================================================

## Apply damage, clamp to 0, and emit signals. Mirrors battler.gd take_damage().
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		unit_died.emit()


## Execute cached_action then clear it. Mirrors battler.gd act() coroutine.
func act(coordinator: Node) -> void:
	if cached_action == null:
		return
	await cached_action.execute(self, coordinator)
	cached_action = null
