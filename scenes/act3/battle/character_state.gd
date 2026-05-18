## CharacterState — runtime battle state for one party member.
## Ported pattern from PokemonUnity PartyMember data model.
## Factory method builds from a PARTY definition dict in MoveData.
class_name CharacterState
extends RefCounted

# =============================================================================
# Runtime state fields
# =============================================================================

var character_key: String = ""
var display_name: String = ""
var weapon_type: String = ""          # "HOOF", "FANG", or "FEATHER"
var sprite_frames_path: String = ""   # path to SpriteFrames .tres; empty = use boxer placeholder

var current_hp: int = 0
var max_hp: int = 0
var attack: int = 0
var defense: int = 0
var speed: int = 0
var level: int = 10

var attack_stage: int = 0
var defense_stage: int = 0
var accuracy_stage: int = 0           # used by flap_dust / accuracy mechanic
var enduring: bool = false
var flinched: bool = false            # flinch_30pct: skip next turn if true
var double_next_turn: bool = false    # double_next_turn: next damage move deals x2

var moves: Array[String] = []         # ordered list of move keys available to this member
var pp: Dictionary = {}               # move_key -> current PP (int)

# =============================================================================
# Factory
# =============================================================================

## Build a CharacterState from a PARTY definition dict and a move list.
## party_def — one entry from MoveData.PARTY
## unlocked_moves — Array[String] from GameState.party_moves[key] (may be empty)
static func from_party_def(
		party_def: Dictionary,
		unlocked_moves: Array[String]) -> CharacterState:

	var cs: CharacterState = CharacterState.new()
	cs.character_key     = party_def["key"]
	cs.display_name      = party_def["display_name"]
	cs.weapon_type       = party_def["weapon_type"]
	cs.sprite_frames_path = party_def.get("sprite_frames_path", "")
	cs.max_hp            = party_def["max_hp"]
	cs.current_hp        = cs.max_hp
	cs.attack            = party_def["attack"]
	cs.defense           = party_def["defense"]
	cs.speed             = party_def["speed"]
	cs.level             = party_def.get("level", 10)
	cs.attack_stage      = 0
	cs.defense_stage     = 0
	cs.accuracy_stage    = 0
	cs.enduring          = false
	cs.flinched          = false
	cs.double_next_turn  = false

	# Build the move list: start from the party def's base_moves, add any
	# additional unlocked ones that are not already in base_moves.
	var base_moves: Array[String] = []
	for m: String in party_def["base_moves"]:
		base_moves.append(m)
	cs.moves = base_moves.duplicate()
	for m: String in unlocked_moves:
		if not (m in cs.moves) and MoveData.MOVES.has(m):
			cs.moves.append(m)

	# Initialise PP to max_pp for every move.
	cs.pp.clear()
	for move_key: String in cs.moves:
		if MoveData.MOVES.has(move_key):
			cs.pp[move_key] = MoveData.MOVES[move_key]["max_pp"]

	return cs


# =============================================================================
# Helpers
# =============================================================================

func is_alive() -> bool:
	return current_hp > 0


## Reset stat stages (called on switch-out — standard Pokémon rule).
## Also clears per-turn volatile flags (flinch, double_next_turn).
func reset_stages() -> void:
	attack_stage     = 0
	defense_stage    = 0
	accuracy_stage   = 0
	enduring         = false
	flinched         = false
	double_next_turn = false
