extends Node

# =============================================================================
# Constants
# =============================================================================

const SAVE_PATH: String = "user://boe_save.json"

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

# =============================================================================
# Act 1 state
# =============================================================================

var hearts: int = 3:
	set(value):
		# Use the implicit backing field keyword so the setter does not recurse.
		field = value
		hearts_changed.emit(field)
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

# =============================================================================
# Act 4 state
# =============================================================================

var snowball_expelled: bool = false

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	load_from_disk()

# =============================================================================
# Public methods
# =============================================================================

func corrupt_commandment(index: int) -> void:
	if index < 0 or index >= COMMANDMENTS.size():
		push_error("GameState.corrupt_commandment: index %d out of range" % index)
		return
	# Track the total count, clamped to 7
	commandments_corrupted = mini(commandments_corrupted + 1, COMMANDMENTS.size())
	commandment_corrupted.emit(index)
	save_to_disk()


func complete_act(act: int) -> void:
	if act < 1 or act > 4:
		push_error("GameState.complete_act: act %d is not valid (expected 1-4)" % act)
		return
	# Advance the persistent act pointer so save/load stays consistent.
	current_act = mini(act + 1, 4)
	act_completed.emit(act)
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
		4:
			snowball_expelled = false


func save_to_disk() -> void:
	var data: Dictionary = {
		"current_act": current_act,
		"commandments_corrupted": commandments_corrupted,
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
		"snowball_expelled": snowball_expelled,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_to_disk: could not open %s for writing (error %d)" % [
			SAVE_PATH, FileAccess.get_open_error()
		])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState.load_from_disk: could not open %s for reading (error %d)" % [
			SAVE_PATH, FileAccess.get_open_error()
		])
		return
	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null:
		push_error("GameState.load_from_disk: JSON parse failed — save file may be corrupt")
		return
	if not parsed is Dictionary:
		push_error("GameState.load_from_disk: unexpected JSON root type")
		return

	var data: Dictionary = parsed as Dictionary
	current_act              = _read_int(data, "current_act", 1)
	commandments_corrupted   = _read_int(data, "commandments_corrupted", 0)
	hearts                   = _read_int(data, "hearts", 3)
	has_secret_scroll        = _read_bool(data, "has_secret_scroll", false)
	lamb_rescued             = _read_bool(data, "lamb_rescued", false)
	collected_key_ids        = _read_int_array(data, "collected_key_ids", [])
	opened_door_ids          = _read_int_array(data, "opened_door_ids", [])
	has_gatekeeper_bonus     = _read_bool(data, "has_gatekeeper_bonus", false)
	jones_men_driven_off     = _read_bool(data, "jones_men_driven_off", false)
	jones_men_driven         = _read_int(data, "jones_men_driven", 0)
	boxer_moves              = _read_string_array(data, "boxer_moves", ["charge", "brace"])
	battle_wins              = _read_int(data, "battle_wins", 0)
	snowball_expelled        = _read_bool(data, "snowball_expelled", false)

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
		if element is float:
			result.append(int(element))
		elif element is int:
			result.append(element)
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
