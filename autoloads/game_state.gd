extends Node

# =============================================================================
# Constants
# =============================================================================

const SAVE_PATH: String = "user://boe_save.json"
const SAVE_TMP_PATH: String = "user://boe_save.json.tmp"
const SAVE_BAK_PATH: String = "user://boe_save.json.bak"

const SAVE_VERSION: int = 1

const MAX_HEARTS: int = 3
const MAX_ACT: int = 4
const MAX_BATTLE_WINS: int = 4

const COMMANDMENTS: Array[String] = [
	"Whatever goes upon two legs is an enemy.",
	"Whatever goes upon four legs, or has wings, is a friend.",
	"No animal shall wear clothes.",
	"No animal shall sleep in a bed.",
	"No animal shall drink alcohol.",
	"No animal shall kill any other animal.",
	"All animals are equal.",
]

# =============================================================================
# Signals
# =============================================================================

signal commandment_corrupted(index: int)
signal act_completed(act: int)
signal hearts_changed(new_hearts: int)

# =============================================================================
# Cross-act progress
# =============================================================================

var current_act: int = 1
var commandments_corrupted: int = 0
# Tracks WHICH commandments are corrupted by index (0-based).  The integer
# count above is kept for backward-compat with any act code that reads it, but
# the display layer (seven_commandments.gd) now reads this array so it can show
# the correct commandments after a save/load round-trip regardless of the order
# in which they were corrupted.
var corrupted_commandment_indices: Array[int] = []

# =============================================================================
# Act 1 state
# =============================================================================

var hearts: int = 3:
	set(value):
		hearts = value
		hearts_changed.emit(hearts)
var has_secret_scroll: bool = false
var lamb_rescued: bool = false
var collected_key_ids: Array[int] = []
var opened_door_ids: Array[int] = []

# =============================================================================
# Act 2 state
# =============================================================================

var has_gatekeeper_bonus: bool = false
var jones_men_driven_off: bool = false
var jones_men_driven: int = 0

# =============================================================================
# Act 3 state
# =============================================================================

var boxer_moves: Array[String] = ["charge", "brace"]
var battle_wins: int = 0

## party_roster — ordered list of unlocked character keys (always includes "boxer").
## The tutorial ramp adds "jessie" after fight 1 win, "hen" after fight 2 win.
var party_roster: Array[String] = ["boxer"]

## party_moves — extra unlocked moves per character (beyond base_moves in PARTY def).
## Keys are character keys ("boxer", "jessie", "hen"); values are Array[String] of move keys.
## Base moves come from MoveData.PARTY and are NOT stored here to avoid duplication.
var party_moves: Dictionary = {}

# =============================================================================
# Act 4 state
# =============================================================================

var snowball_expelled: bool = false

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_recover_orphaned_tmp()
	load_from_disk()


# If the browser tab was killed between `rename(main -> bak)` and
# `rename(tmp -> main)`, the newest save sits in .tmp while main is missing.
# Promote .tmp to main before load so we don't fall back to the stale .bak.
# If .tmp exists alongside a valid main, the second rename never happened —
# the .tmp is stale and we delete it.
func _recover_orphaned_tmp() -> void:
	if not FileAccess.file_exists(SAVE_TMP_PATH):
		return
	if FileAccess.file_exists(SAVE_PATH):
		var rm_err: int = DirAccess.remove_absolute(SAVE_TMP_PATH)
		if rm_err != OK:
			push_warning("GameState._recover_orphaned_tmp: could not remove stale .tmp (error %d)" % rm_err)
		return
	var promote_err: int = DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
	if promote_err != OK:
		push_error("GameState._recover_orphaned_tmp: failed to promote .tmp to main (error %d)" % promote_err)

# =============================================================================
# Public methods
# =============================================================================

func corrupt_commandment(index: int) -> void:
	if index < 0 or index >= COMMANDMENTS.size():
		push_error("GameState.corrupt_commandment: index %d out of range" % index)
		return
	# Record the specific index so save/load can restore exactly which
	# commandments were corrupted (not just how many).
	if not corrupted_commandment_indices.has(index):
		corrupted_commandment_indices.append(index)
	# Keep the integer count in sync for any act code that reads it.
	commandments_corrupted = corrupted_commandment_indices.size()
	commandment_corrupted.emit(index)
	save_to_disk()


func complete_act(act: int) -> void:
	if act < 1 or act > 4:
		push_error("GameState.complete_act: act %d is not valid (expected 1-4)" % act)
		return
	# Advance the persistent act pointer so save/load stays consistent.
	current_act = mini(act + 1, MAX_ACT)
	act_completed.emit(act)
	save_to_disk()


func reset_all() -> void:
	_reset_to_defaults()
	save_to_disk()


func reset_act_state() -> void:
	match current_act:
		1:
			hearts = 3
			has_secret_scroll = false
			lamb_rescued = false
			collected_key_ids = []
			opened_door_ids = []
		2:
			has_gatekeeper_bonus = false
			jones_men_driven_off = false
			jones_men_driven = 0
		3:
			boxer_moves = ["charge", "brace"]
			battle_wins = 0
			party_roster = ["boxer"]
			party_moves = {}
		4:
			snowball_expelled = false
	# Persist immediately so a browser refresh/close doesn't roll back the reset.
	save_to_disk()

# =============================================================================
# Persistence — atomic save, crash-safe load
# =============================================================================

func save_to_disk() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"current_act": current_act,
		"commandments_corrupted": commandments_corrupted,
		"corrupted_commandment_indices": corrupted_commandment_indices,
		"hearts": hearts,
		"has_secret_scroll": has_secret_scroll,
		"lamb_rescued": lamb_rescued,
		"collected_key_ids": collected_key_ids,
		"opened_door_ids": opened_door_ids,
		"has_gatekeeper_bonus": has_gatekeeper_bonus,
		"jones_men_driven_off": jones_men_driven_off,
		"jones_men_driven": jones_men_driven,
		"boxer_moves": boxer_moves,
		"battle_wins": battle_wins,
		"party_roster": party_roster,
		"party_moves": party_moves,
		"snowball_expelled": snowball_expelled,
	}
	# Atomic write: write to .tmp, snapshot the old save as .bak, then rename
	# .tmp -> main. Prevents a half-written/corrupt save if the browser tab is
	# closed mid-write — a real risk for an HTML5 classroom game.
	var file: FileAccess = FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_to_disk: could not open %s for writing (error %d)" % [
			SAVE_TMP_PATH, FileAccess.get_open_error()
		])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if FileAccess.file_exists(SAVE_PATH):
		# rename_absolute fails if the destination exists (Windows / HTML5 do not
		# overwrite on rename) — clear any stale .bak first.
		if FileAccess.file_exists(SAVE_BAK_PATH):
			DirAccess.remove_absolute(SAVE_BAK_PATH)
		# Snapshot the previous good save as .bak before overwriting.
		var bak_err: int = DirAccess.rename_absolute(SAVE_PATH, SAVE_BAK_PATH)
		if bak_err != OK:
			push_warning("GameState.save_to_disk: could not back up previous save (error %d)" % bak_err)
	# If the backup rename failed, main still exists — clear it so tmp -> main
	# cannot fail on an existing destination. _recover_orphaned_tmp() promotes
	# the .tmp on next launch if the tab is killed in this window.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var rename_err: int = DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
	if rename_err != OK:
		push_error("GameState.save_to_disk: rename tmp -> main failed (error %d)" % rename_err)


func load_from_disk() -> void:
	# Try the main save first, fall back to .bak, otherwise reset to defaults.
	var data: Dictionary = _try_load_path(SAVE_PATH)
	if data.is_empty() and FileAccess.file_exists(SAVE_BAK_PATH):
		push_warning("GameState.load_from_disk: main save unreadable, falling back to .bak")
		data = _try_load_path(SAVE_BAK_PATH)
	if data.is_empty():
		_reset_to_defaults()
		return

	current_act                   = _read_int(data, "current_act", 1)
	commandments_corrupted         = _read_int(data, "commandments_corrupted", 0)
	corrupted_commandment_indices  = _read_int_array(data, "corrupted_commandment_indices", [])
	# If a save from before the indices fix exists, it won't have the array.
	# Reconstruct it from the count by assuming the first N were corrupted —
	# which matches the old (buggy) display assumption and is the best we can do.
	if corrupted_commandment_indices.is_empty() and commandments_corrupted > 0:
		for i: int in range(commandments_corrupted):
			corrupted_commandment_indices.append(i)
	hearts                         = _read_int(data, "hearts", MAX_HEARTS)
	has_secret_scroll              = _read_bool(data, "has_secret_scroll", false)
	lamb_rescued                   = _read_bool(data, "lamb_rescued", false)
	collected_key_ids              = _read_int_array(data, "collected_key_ids", [])
	opened_door_ids                = _read_int_array(data, "opened_door_ids", [])
	has_gatekeeper_bonus           = _read_bool(data, "has_gatekeeper_bonus", false)
	jones_men_driven_off           = _read_bool(data, "jones_men_driven_off", false)
	jones_men_driven               = _read_int(data, "jones_men_driven", 0)
	boxer_moves                    = _read_string_array(data, "boxer_moves", ["charge", "brace"])
	battle_wins                    = _read_int(data, "battle_wins", 0)
	party_roster                   = _read_string_array(data, "party_roster", ["boxer"])
	party_moves                    = _read_dict_of_string_arrays(data, "party_moves", {})
	snowball_expelled              = _read_bool(data, "snowball_expelled", false)
	_clamp_loaded_state()


func _try_load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameState._try_load_path: could not open %s (error %d)" % [
			path, FileAccess.get_open_error()
		])
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not parsed is Dictionary:
		push_error("GameState._try_load_path: parse failed for %s — file may be corrupt" % path)
		return {}
	return parsed as Dictionary


func _reset_to_defaults() -> void:
	current_act = 1
	commandments_corrupted = 0
	corrupted_commandment_indices = []
	hearts = MAX_HEARTS
	has_secret_scroll = false
	lamb_rescued = false
	collected_key_ids = []
	opened_door_ids = []
	has_gatekeeper_bonus = false
	jones_men_driven_off = false
	jones_men_driven = 0
	boxer_moves = ["charge", "brace"]
	battle_wins = 0
	party_roster = ["boxer"]
	party_moves = {}
	snowball_expelled = false


# Defensive bounds against a corrupt or stale browser save (e.g. battle_wins
# from a hacked file) — keeps loaded values inside the ranges the act code
# assumes. These are NOT game-design caps.
func _clamp_loaded_state() -> void:
	current_act = clampi(current_act, 1, MAX_ACT)
	hearts = clampi(hearts, 0, MAX_HEARTS)
	battle_wins = clampi(battle_wins, 0, MAX_BATTLE_WINS)
	# Drop out-of-range commandment indices, then keep the integer count in
	# sync with the (now-valid) index list.
	var valid_indices: Array[int] = []
	for idx: int in corrupted_commandment_indices:
		if idx >= 0 and idx < COMMANDMENTS.size() and not valid_indices.has(idx):
			valid_indices.append(idx)
	corrupted_commandment_indices = valid_indices
	commandments_corrupted = corrupted_commandment_indices.size()

# =============================================================================
# Private helpers — safe typed reads from an untyped JSON Dictionary
# =============================================================================

func _read_int(data: Dictionary, key: String, default_value: int) -> int:
	if data.has(key) and data[key] is float:
		return int(data[key])
	if data.has(key) and data[key] is int:
		return data[key]
	return default_value


func _read_bool(data: Dictionary, key: String, default_value: bool) -> bool:
	if data.has(key) and data[key] is bool:
		return data[key]
	return default_value


func _read_int_array(data: Dictionary, key: String, default_value: Array[int]) -> Array[int]:
	if not data.has(key):
		return default_value
	if not data[key] is Array:
		return default_value
	var result: Array[int] = []
	for element: Variant in (data[key] as Array):
		var value: int
		if element is float:
			value = int(element)
		elif element is int:
			value = element
		else:
			continue
		# Reject negative IDs (key/door/commandment indices are non-negative) and dedupe.
		if value < 0:
			continue
		if value in result:
			continue
		result.append(value)
	return result


func _read_string_array(data: Dictionary, key: String, default_value: Array[String]) -> Array[String]:
	if not data.has(key):
		return default_value
	if not data[key] is Array:
		return default_value
	var result: Array[String] = []
	for element: Variant in (data[key] as Array):
		if element is String:
			result.append(element)
	return result


func _read_dict_of_string_arrays(data: Dictionary, key: String, default_value: Dictionary) -> Dictionary:
	if not data.has(key):
		return default_value
	if not data[key] is Dictionary:
		return default_value
	var result: Dictionary = {}
	for char_key: Variant in (data[key] as Dictionary):
		if not char_key is String:
			continue
		var arr: Array[String] = []
		if data[key][char_key] is Array:
			for m: Variant in (data[key][char_key] as Array):
				if m is String:
					arr.append(m)
		result[char_key] = arr
	return result
