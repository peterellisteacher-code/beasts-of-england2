## Move definitions and damage formula ported from PokemonUnity (reference-library/04-strategy/pokemon-unity/)
## calculate_damage() implements the Gen 5/6 formula verbatim from BattleSystem.cs
extends Node

# =============================================================================
# Constants — Move definitions
# =============================================================================

const MOVES: Dictionary = {
	# --- Boxer moves ---
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
	# --- Jessie (dog) moves ---
	"bite": {
		"name": "Bite",
		"display": "BITE",
		"base_power": 60,
		"type": "Normal",
		"pp": 25,
		"max_pp": 25,
		"effect": "none",
		"description": "Jessie snaps with sharp teeth.",
	},
	"snarl": {
		"name": "Snarl",
		"display": "SNARL",
		"base_power": 0,
		"type": "Status",
		"pp": 20,
		"max_pp": 20,
		"effect": "lower_attack",
		"description": "Jessie snarls ferociously, lowering the enemy's attack.",
	},
	"lunge": {
		"name": "Lunge",
		"display": "LUNGE",
		"base_power": 72,
		"type": "Normal",
		"pp": 15,
		"max_pp": 15,
		"effect": "none",
		"description": "Jessie leaps at the enemy with fierce speed.",
	},
	"guard": {
		"name": "Guard",
		"display": "GUARD",
		"base_power": 0,
		"type": "Status",
		"pp": 20,
		"max_pp": 20,
		"effect": "raise_defense",
		"description": "Jessie stands firm, raising her own defence.",
	},
	# --- Hen moves ---
	"peck": {
		"name": "Peck",
		"display": "PECK",
		"base_power": 38,
		"type": "Normal",
		"pp": 35,
		"max_pp": 35,
		"effect": "none",
		"description": "The hen pecks sharply at the enemy.",
	},
	"flap_dust": {
		"name": "Flap Dust",
		"display": "FLAP DUST",
		"base_power": 0,
		"type": "Status",
		"pp": 20,
		"max_pp": 20,
		"effect": "lower_accuracy",
		"description": "The hen flaps wings furiously, blinding the enemy with dust.",
	},
	"rally": {
		"name": "Rally",
		"display": "RALLY",
		"base_power": 0,
		"type": "Status",
		"pp": 10,
		"max_pp": 10,
		"effect": "heal_15hp",
		"description": "The hen rallies the active party member, restoring 15 HP.",
	},
	"squawk": {
		"name": "Squawk",
		"display": "SQUAWK",
		"base_power": 0,
		"type": "Status",
		"pp": 20,
		"max_pp": 20,
		"effect": "lower_attack",
		"description": "A piercing squawk that lowers the enemy's attack.",
	},
}

# =============================================================================
# Constants — Enemy definitions (index matches battle_index 0-5).
# Index 5 (Mr Jones) is the secret boss — see cowshed_overworld.gd.
# =============================================================================

const ENEMIES: Array = [
	{
		"name": "Jones' Pawn",
		"sprite_frames": "res://assets/sprites/act3_enemies/jones_pawn_frames_v3.tres",
		"max_hp": 35,
		"attack": 30,
		"defense": 25,
		"speed": 40,
		"level": 5,
		"weapon_class": "MELEE",
		"moves": [
			{"name": "Tackle", "base_power": 40, "type": "Normal", "pp": 35, "effect": "none"},
			{"name": "Growl", "base_power": 0, "type": "Status", "pp": 40, "effect": "lower_attack"},
		],
	},
	{
		"name": "Red Archer",
		"sprite_frames": "res://assets/sprites/act3_enemies/red_archer_frames_v3.tres",
		"max_hp": 45,
		"attack": 45,
		"defense": 30,
		"speed": 55,
		"level": 7,
		"weapon_class": "RANGED",
		"moves": [
			{"name": "Arrow Shot", "base_power": 55, "type": "Normal", "pp": 20, "effect": "none"},
			{"name": "Focus", "base_power": 0, "type": "Status", "pp": 15, "effect": "raise_attack"},
		],
	},
	{
		"name": "Foxwood Lancer",
		"sprite_frames": "res://assets/sprites/act3_enemies/foxwood_lancer_frames_v3.tres",
		"max_hp": 60,
		"attack": 55,
		"defense": 60,
		"speed": 35,
		"level": 9,
		"weapon_class": "MELEE",
		"moves": [
			{"name": "Lance Charge", "base_power": 70, "type": "Normal", "pp": 15, "effect": "none"},
			{"name": "Shield Up", "base_power": 0, "type": "Status", "pp": 20, "effect": "raise_defense_2"},
		],
	},
	{
		"name": "Stable-lad",
		"sprite_frames": "res://assets/sprites/act3_enemies/stable_lad_frames_v3.tres",
		"max_hp": 70,
		"attack": 60,
		"defense": 45,
		"speed": 50,
		"level": 10,
		"weapon_class": "MELEE",
		"moves": [
			{"name": "Pitchfork", "base_power": 65, "type": "Normal", "pp": 15, "effect": "none"},
			{"name": "Desperate Swing", "base_power": 85, "type": "Normal", "pp": 10, "effect": "miss_20pct"},
		],
	},
	{
		"name": "Pinchfield Brute",
		"sprite_frames": "res://assets/sprites/act3_enemies/pinchfield_brute_frames_v3.tres",
		"max_hp": 90,
		"attack": 72,
		"defense": 58,
		"speed": 38,
		"level": 12,
		"weapon_class": "LASH",
		"moves": [
			{"name": "Cudgel Smash", "base_power": 78, "type": "Normal", "pp": 12, "effect": "none"},
			{"name": "Bellow", "base_power": 0, "type": "Status", "pp": 15, "effect": "raise_attack"},
		],
	},
	{
		"name": "Mr Jones",
		"sprite_frames": "res://assets/sprites/act3_enemies/mr_jones_frames_v3.tres",
		"max_hp": 120,
		"attack": 84,
		"defense": 66,
		"speed": 52,
		"level": 15,
		"weapon_class": "RANGED",
		"moves": [
			{"name": "Shotgun Blast", "base_power": 92, "type": "Normal", "pp": 8, "effect": "none"},
			{"name": "Whip Crack", "base_power": 62, "type": "Normal", "pp": 14, "effect": "flinch_30pct"},
			{"name": "Cruel Sneer", "base_power": 0, "type": "Status", "pp": 12, "effect": "lower_attack"},
		],
	},
]

# =============================================================================
# Constants — Party definitions
# =============================================================================
## PARTY defines the three playable characters. sprite_frames_path points at a
## SpriteFrames .tres — Jessie and Hen use real v3 art; Boxer's is "" and he
## uses the SpriteFrames embedded directly in battle_scene.tscn.
const PARTY: Array[Dictionary] = [
	{
		"key": "boxer",
		"display_name": "BOXER",
		"weapon_type": "HOOF",
		"max_hp": 80,
		"attack": 70,
		"defense": 55,
		"speed": 40,
		"level": 10,
		"base_moves": ["charge", "brace"],
		# Real art path when available (placeholder: use boxer frames inline in scene)
		"sprite_frames_path": "",
	},
	{
		"key": "jessie",
		"display_name": "JESSIE",
		"weapon_type": "FANG",
		"max_hp": 55,
		"attack": 58,
		"defense": 38,
		"speed": 78,
		"level": 10,
		"base_moves": ["bite", "snarl"],
		"sprite_frames_path": "res://assets/sprites/characters/jessie_frames_v3.tres",
	},
	{
		"key": "hen",
		"display_name": "HEN",
		"weapon_type": "FEATHER",
		"max_hp": 42,
		"attack": 32,
		"defense": 34,
		"speed": 62,
		"level": 10,
		"base_moves": ["peck", "flap_dust"],
		"sprite_frames_path": "res://assets/sprites/characters/hen_frames_v3.tres",
	},
]

# =============================================================================
# Constants — Weapon matchup triangle
# =============================================================================
## MATCHUP_COUNTERS[weapon_type] = enemy_weapon_class that this animal counters.
## Triangle: HOOF > MELEE > FANG > RANGED > FEATHER > LASH > HOOF
## When active animal counters enemy class: animal deals ×1.5, takes ×0.5.
## When enemy class counters active animal's type: see MATCHUP_WEAK_TO.
const MATCHUP_COUNTERS: Dictionary = {
	"HOOF":    "MELEE",   # Boxer beats MELEE
	"FANG":    "RANGED",  # Jessie beats RANGED
	"FEATHER": "LASH",    # Hen beats LASH
}
## MATCHUP_WEAK_TO[weapon_type] = enemy_weapon_class this animal is weak to.
const MATCHUP_WEAK_TO: Dictionary = {
	"HOOF":    "RANGED",  # Boxer weak to RANGED
	"FANG":    "LASH",    # Jessie weak to LASH
	"FEATHER": "MELEE",   # Hen weak to MELEE
}

# =============================================================================
# Constants — Move unlocks after each battle victory (character-aware)
# =============================================================================
## Key = battle_index + 1 (wins required).
## Value = {"character": key, "move": move_key}
## Fights 1–3 also unlock roster members (handled in battle_scene._run_win).
const MOVE_UNLOCKS: Dictionary = {
	1: {"character": "boxer", "move": "stamp"},         # win fight 1 → Boxer gets Stamp
	2: {"character": "jessie", "move": "lunge"},         # win fight 2 → Jessie gets Lunge
	3: {"character": "hen", "move": "rally"},            # win fight 3 → Hen gets Rally
	4: {"character": "boxer", "move": "endure"},         # win fight 4 → Boxer gets Endure
	5: {"character": "boxer", "move": "i_will_work_harder"}, # win fight 5 → Boxer gets IWH
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
