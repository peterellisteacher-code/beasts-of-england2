## Move definitions and damage formula ported from PokemonUnity (reference-library/04-strategy/pokemon-unity/)
## calculate_damage() implements the Gen 5/6 formula verbatim from BattleSystem.cs
extends Node

# =============================================================================
# Constants — Move definitions
# =============================================================================

const MOVES: Dictionary = {
	"charge": {
		"name": "Charge",
		"display": "CHARGE",
		"base_power": 70,
		"type": "Normal",
		"pp": 15,
		"max_pp": 15,
		"effect": "none",
		"description": "Boxer charges forward with his massive chest.",
	},
	"brace": {
		"name": "Brace",
		"display": "BRACE",
		"base_power": 0,
		"type": "Status",
		"pp": 20,
		"max_pp": 20,
		"effect": "raise_defense",
		"description": "Boxer braces himself, raising his defence.",
	},
	"stamp": {
		"name": "Stamp",
		"display": "STAMP",
		"base_power": 65,
		"type": "Normal",
		"pp": 20,
		"max_pp": 20,
		"effect": "flinch_30pct",
		"description": "Boxer stamps with his great iron hooves.",
	},
	"endure": {
		"name": "Endure",
		"display": "ENDURE",
		"base_power": 0,
		"type": "Status",
		"pp": 10,
		"max_pp": 10,
		"effect": "survive_one_hit",
		"description": "Boxer will not fall below 1 HP this turn.",
	},
	"i_will_work_harder": {
		"name": "I Will Work Harder",
		"display": "I WILL WORK HARDER",
		"base_power": 80,
		"type": "Normal",
		"pp": 5,
		"max_pp": 5,
		"effect": "double_next_turn",
		"description": "Boxer's famous motto fuels a devastating blow.",
	},
	"solidarity": {
		"name": "Solidarity",
		"display": "SOLIDARITY",
		"base_power": 0,
		"type": "Status",
		"pp": 5,
		"max_pp": 5,
		"effect": "heal_10hp",
		"description": "The animals rally behind Boxer, restoring his spirit.",
	},
}

# =============================================================================
# Constants — Enemy definitions (index matches battle_index 0-3)
# =============================================================================

const ENEMIES: Array = [
	{
		"name": "Jones' Pawn",
		"max_hp": 35,
		"attack": 30,
		"defense": 25,
		"speed": 40,
		"level": 5,
		"moves": [
			{"name": "Tackle", "base_power": 40, "type": "Normal", "pp": 35, "effect": "none"},
			{"name": "Growl", "base_power": 0, "type": "Status", "pp": 40, "effect": "lower_attack"},
		],
	},
	{
		"name": "Red Archer",
		"max_hp": 45,
		"attack": 45,
		"defense": 30,
		"speed": 55,
		"level": 7,
		"moves": [
			{"name": "Arrow Shot", "base_power": 55, "type": "Normal", "pp": 20, "effect": "none"},
			{"name": "Focus", "base_power": 0, "type": "Status", "pp": 15, "effect": "raise_attack"},
		],
	},
	{
		"name": "Foxwood Lancer",
		"max_hp": 60,
		"attack": 55,
		"defense": 60,
		"speed": 35,
		"level": 9,
		"moves": [
			{"name": "Lance Charge", "base_power": 70, "type": "Normal", "pp": 15, "effect": "none"},
			{"name": "Shield Up", "base_power": 0, "type": "Status", "pp": 20, "effect": "raise_defense_2"},
		],
	},
	{
		"name": "Stable-lad",
		"max_hp": 70,
		"attack": 60,
		"defense": 45,
		"speed": 50,
		"level": 10,
		"moves": [
			{"name": "Pitchfork", "base_power": 65, "type": "Normal", "pp": 15, "effect": "none"},
			{"name": "Desperate Swing", "base_power": 85, "type": "Normal", "pp": 10, "effect": "miss_20pct"},
		],
	},
]

# =============================================================================
# Constants — Move unlocks after each battle victory
# =============================================================================

# Key = battle_index + 1 (i.e. the count of wins needed to unlock)
const MOVE_UNLOCKS: Dictionary = {
	1: "stamp",
	2: "endure",
	3: "i_will_work_harder",
}

# =============================================================================
# Static methods
# =============================================================================

static func calculate_damage(
		attacker_level: int,
		base_power: int,
		attacker_attack: int,
		defender_defense: int) -> int:
	if base_power == 0:
		return 0
	var raw: float = (
		(2.0 * float(attacker_level) / 5.0 + 2.0)
		* float(base_power)
		* float(attacker_attack)
		/ float(defender_defense)
	) / 50.0 + 2.0
	var damage: int = int(floor(raw * randf_range(0.85, 1.0)))
	return maxi(1, damage)
