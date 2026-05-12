## Battle system ported from PokemonUnity (reference-library/04-strategy/pokemon-unity/)
## Damage formula: Gen 5/6 standard — (2L/5+2) × BP × Atk/Def ÷ 50 + 2
## Stat stages: -6..+6 with canonical multiplier table
## PP system, move unlocks, status effects all mirror PokemonUnity BattleSystem.cs patterns
class_name BattleScene
extends Node2D

# =============================================================================
# Enums
# =============================================================================

enum BattlePhase {
	IDLE,
	AWAIT_PLAYER_INPUT,
	PLAYER_MOVE,
	ENEMY_MOVE,
	ANIMATING,
	WIN,
	LOSE,
}

# =============================================================================
# Private variables — battle state
# =============================================================================

var _phase: BattlePhase = BattlePhase.IDLE
var _phase_entered: bool = false
var _battle_index: int = 0

# Boxer runtime stats
var _boxer_hp: int = 80
var _boxer_max_hp: int = 80
var _boxer_attack: int = 65
var _boxer_defense: int = 50
var _boxer_speed: int = 45
var _boxer_level: int = 10
var _boxer_defense_stage: int = 0
var _boxer_attack_stage: int = 0
var _boxer_enduring: bool = false

# Current enemy runtime data (deep-copied from MoveData.ENEMIES)
var _enemy_data: Dictionary = {}
var _enemy_hp: int = 0
var _enemy_attack_stage: int = 0
var _enemy_defense_stage: int = 0

# Boxer move list and per-move PP for this battle
var _boxer_moves: Array[String] = []
var _boxer_pp: Dictionary = {}

# Move selected during AWAIT_PLAYER_INPUT (-1 = none yet)
var _queued_move_index: int = -1

# =============================================================================
# Onready references
# =============================================================================

@onready var _boxer_hp_bar: ProgressBar = $UI/BoxerPanel/HPBar
@onready var _enemy_hp_bar: ProgressBar = $UI/EnemyPanel/HPBar
@onready var _boxer_hp_label: Label = $UI/BoxerPanel/HPLabel
@onready var _enemy_hp_label: Label = $UI/EnemyPanel/HPLabel
@onready var _boxer_name_label: Label = $UI/BoxerPanel/NameLabel
@onready var _enemy_name_label: Label = $UI/EnemyPanel/NameLabel
@onready var _battle_log: RichTextLabel = $UI/BattleLog
@onready var _move_buttons_container: GridContainer = $UI/MoveButtons
@onready var _boxer_sprite: AnimatedSprite2D = $BoxerSprite
@onready var _enemy_sprite: AnimatedSprite2D = $EnemySprite

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_battle_index = get_tree().get_meta("battle_index", 0)
	_setup_boxer()
	_setup_enemy()
	_setup_move_buttons()
	_update_hud()
	_log("A battle begins! Boxer faces " + _enemy_data["name"] + "!")

	# Wire animation_finished so BoxerSprite returns to idle after attack
	_boxer_sprite.animation_finished.connect(_on_boxer_animation_finished)
	_boxer_sprite.play("idle")
	_enemy_sprite.play("idle")

	_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)


func _physics_process(_delta: float) -> void:
	if _phase_entered:
		return
	_phase_entered = true
	_enter_phase(_phase)


# =============================================================================
# Phase state machine
# =============================================================================

func _transition_to(new_phase: BattlePhase) -> void:
	_phase = new_phase
	_phase_entered = false
	# AWAIT_PLAYER_INPUT is driven by button callbacks, not physics_process
	set_physics_process(new_phase != BattlePhase.AWAIT_PLAYER_INPUT)


func _enter_phase(phase: BattlePhase) -> void:
	match phase:
		BattlePhase.AWAIT_PLAYER_INPUT:
			_refresh_move_buttons()
			_set_buttons_disabled(false)
		BattlePhase.PLAYER_MOVE:
			_set_buttons_disabled(true)
			_run_player_move()
		BattlePhase.ENEMY_MOVE:
			_run_enemy_move()
		BattlePhase.WIN:
			_set_buttons_disabled(true)
			_run_win()
		BattlePhase.LOSE:
			_set_buttons_disabled(true)
			_run_lose()
		BattlePhase.IDLE, BattlePhase.ANIMATING:
			pass


# =============================================================================
# Private methods — setup
# =============================================================================

func _setup_boxer() -> void:
	_boxer_hp = _boxer_max_hp
	_boxer_defense_stage = 0
	_boxer_attack_stage = 0
	_boxer_enduring = false

	_boxer_moves.clear()
	for move_key: String in GameState.boxer_moves:
		_boxer_moves.append(move_key)

	if GameState.has_gatekeeper_bonus and not ("solidarity" in _boxer_moves):
		_boxer_moves.append("solidarity")

	_boxer_pp.clear()
	for move_key: String in _boxer_moves:
		_boxer_pp[move_key] = MoveData.MOVES[move_key]["max_pp"]


func _setup_enemy() -> void:
	_enemy_data = MoveData.ENEMIES[_battle_index].duplicate(true)
	_enemy_hp = _enemy_data["max_hp"]
	_enemy_attack_stage = 0
	_enemy_defense_stage = 0


func _setup_move_buttons() -> void:
	for i: int in range(_move_buttons_container.get_child_count()):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn == null:
			continue
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_move_button_pressed(idx))

	_refresh_move_buttons()


func _refresh_move_buttons() -> void:
	for i: int in range(_move_buttons_container.get_child_count()):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn == null:
			continue
		if i < _boxer_moves.size():
			var move_key: String = _boxer_moves[i]
			var move: Dictionary = MoveData.MOVES[move_key]
			var pp_now: int = _boxer_pp[move_key]
			var pp_max: int = move["max_pp"]
			btn.text = move["display"] + " (" + str(pp_now) + "/" + str(pp_max) + ")"
			btn.disabled = (pp_now <= 0)
			btn.visible = true
		else:
			btn.visible = false


# =============================================================================
# Coroutines — player and enemy moves
# =============================================================================

func _run_player_move() -> void:
	var move_index: int = _queued_move_index
	_queued_move_index = -1

	var move_key: String = _boxer_moves[move_index]
	_boxer_pp[move_key] -= 1

	await _execute_move(move_key, MoveData.MOVES[move_key], true)

	if _enemy_hp <= 0:
		_transition_to(BattlePhase.WIN)
		return

	await get_tree().create_timer(0.8).timeout
	_transition_to(BattlePhase.ENEMY_MOVE)


func _run_enemy_move() -> void:
	var enemy_moves: Array = _enemy_data["moves"]
	var move: Dictionary
	if float(_enemy_hp) / float(_enemy_data["max_hp"]) < 0.3:
		move = enemy_moves[0]
	else:
		move = enemy_moves[randi() % enemy_moves.size()]

	await _execute_move(move["name"], move, false)
	_update_hud()

	if _boxer_hp <= 0:
		_transition_to(BattlePhase.LOSE)
		return

	_boxer_enduring = false
	_update_hud()
	_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)


func _run_win() -> void:
	_log("Boxer is victorious!")
	GameState.battle_wins += 1

	var unlock_key: String = MoveData.MOVE_UNLOCKS.get(_battle_index + 1, "")
	if unlock_key != "" and not (unlock_key in GameState.boxer_moves):
		GameState.boxer_moves.append(unlock_key)
		GameState.save_to_disk()
		await get_tree().create_timer(0.5).timeout
		_log("Boxer learned: " + MoveData.MOVES[unlock_key]["display"] + "!")
	else:
		GameState.save_to_disk()

	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/act3/cowshed_overworld.tscn")


func _run_lose() -> void:
	_log("Boxer has fallen...")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/act3/battle/battle_loss.tscn")


# =============================================================================
# Private methods — move execution
# =============================================================================

func _on_move_button_pressed(move_index: int) -> void:
	if _phase != BattlePhase.AWAIT_PLAYER_INPUT:
		return
	if move_index >= _boxer_moves.size():
		return
	var move_key: String = _boxer_moves[move_index]
	if _boxer_pp[move_key] <= 0:
		return

	_queued_move_index = move_index
	_transition_to(BattlePhase.PLAYER_MOVE)
	# Re-enable physics_process so the state machine can enter PLAYER_MOVE
	set_physics_process(true)


func _execute_move(move_key: String, move: Dictionary, is_player: bool) -> void:
	var attacker_name: String = "Boxer" if is_player else _enemy_data["name"]
	_log(attacker_name + " uses " + move["name"] + "!")
	await get_tree().create_timer(0.5).timeout

	var effect: String = move.get("effect", "none")
	var is_damage_move: bool = move.get("base_power", 0) > 0

	# Play attack animation for Boxer on damage moves
	if is_player and is_damage_move:
		_boxer_sprite.play("attack")

	match effect:
		"none":
			_deal_damage(move, is_player)
		"raise_defense":
			if is_player:
				_boxer_defense_stage = mini(_boxer_defense_stage + 1, 6)
				_log("Boxer's defence rose!")
			else:
				_enemy_defense_stage = mini(_enemy_defense_stage + 1, 6)
				_log(_enemy_data["name"] + "'s defence rose!")
		"raise_attack":
			if is_player:
				_boxer_attack_stage = mini(_boxer_attack_stage + 1, 6)
				_log("Boxer's attack rose!")
			else:
				_enemy_attack_stage = mini(_enemy_attack_stage + 1, 6)
				_log(_enemy_data["name"] + "'s attack rose!")
		"raise_defense_2":
			if is_player:
				_boxer_defense_stage = mini(_boxer_defense_stage + 2, 6)
				_log("Boxer's defence sharply rose!")
			else:
				_enemy_defense_stage = mini(_enemy_defense_stage + 2, 6)
				_log(_enemy_data["name"] + "'s defence sharply rose!")
		"lower_attack":
			if is_player:
				_enemy_attack_stage = maxi(_enemy_attack_stage - 1, -6)
				_log(_enemy_data["name"] + "'s attack fell!")
			else:
				_boxer_attack_stage = maxi(_boxer_attack_stage - 1, -6)
				_log("Boxer's attack fell!")
		"survive_one_hit":
			_boxer_enduring = true
			_log("Boxer braces — he will endure this turn!")
		"heal_10hp":
			_boxer_hp = mini(_boxer_max_hp, _boxer_hp + 10)
			_log("Solidarity restores Boxer's spirit! (+10 HP)")
		"flinch_30pct":
			_deal_damage(move, is_player)
		"double_next_turn":
			_deal_damage(move, is_player)
		"miss_20pct":
			if randf() < 0.2:
				_log("But it missed!")
			else:
				_deal_damage(move, is_player)

	_update_hud()
	await get_tree().create_timer(0.3).timeout


func _deal_damage(move: Dictionary, is_player: bool) -> void:
	var base_power: int = move.get("base_power", 0)
	if base_power == 0:
		return

	if is_player:
		var atk: int = int(float(_boxer_attack) * _stage_multiplier(_boxer_attack_stage))
		var def: int = int(float(_enemy_data["defense"]) * _stage_multiplier(_enemy_defense_stage))
		var dmg: int = MoveData.calculate_damage(_boxer_level, base_power, atk, def)
		_enemy_hp = maxi(0, _enemy_hp - dmg)
		_log("Boxer dealt " + str(dmg) + " damage!")
	else:
		var atk: int = int(float(_enemy_data["attack"]) * _stage_multiplier(_enemy_attack_stage))
		var def: int = int(float(_boxer_defense) * _stage_multiplier(_boxer_defense_stage))
		var dmg: int = MoveData.calculate_damage(_enemy_data["level"], base_power, atk, def)
		if _boxer_enduring and (_boxer_hp - dmg) <= 0:
			dmg = _boxer_hp - 1
			_log("Boxer endured the hit!")
		_boxer_hp = maxi(0, _boxer_hp - dmg)
		_log(_enemy_data["name"] + " dealt " + str(dmg) + " damage to Boxer!")


# =============================================================================
# Sprite callbacks
# =============================================================================

func _on_boxer_animation_finished() -> void:
	if _boxer_sprite.animation == "attack":
		_boxer_sprite.play("idle")


# =============================================================================
# Private methods — HUD
# =============================================================================

func _update_hud() -> void:
	_boxer_name_label.text = "BOXER  Lv." + str(_boxer_level)
	_boxer_hp_bar.max_value = _boxer_max_hp
	_boxer_hp_bar.value = _boxer_hp
	_boxer_hp_label.text = str(_boxer_hp) + "/" + str(_boxer_max_hp)

	_enemy_name_label.text = _enemy_data.get("name", "???") + "  Lv." + str(_enemy_data.get("level", "?"))
	_enemy_hp_bar.max_value = _enemy_data["max_hp"]
	_enemy_hp_bar.value = _enemy_hp
	_enemy_hp_label.text = str(_enemy_hp) + "/" + str(_enemy_data["max_hp"])


func _log(text: String) -> void:
	_battle_log.append_text(text + "\n")
	await get_tree().process_frame
	_battle_log.scroll_to_line(_battle_log.get_line_count() - 1)


func _set_buttons_disabled(disabled: bool) -> void:
	for i: int in range(_move_buttons_container.get_child_count()):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn != null:
			btn.disabled = disabled


# =============================================================================
# Private methods — stat stage multiplier (Pokémon standard)
# =============================================================================

func _stage_multiplier(stage: int) -> float:
	const STAGE_TABLE: Array[float] = [
		0.25, 0.286, 0.333, 0.4, 0.5, 0.667,
		1.0,
		1.5, 2.0, 2.5, 3.0, 3.5, 4.0,
	]
	return STAGE_TABLE[clamp(stage + 6, 0, 12)]
