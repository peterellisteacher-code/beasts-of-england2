## Battle system — party overhaul (Phases 2, 4, 5, 6, 7).
## Ported from PokemonUnity (reference-library/04-strategy/pokemon-unity/).
## Damage formula: Gen 5/6 standard — (2L/5+2) × BP × Atk/Def ÷ 50 + 2
## Stat stages: -6..+6 with canonical multiplier table
## PP system, move unlocks, status effects mirror PokemonUnity BattleSystem.cs patterns.
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
	AWAIT_SWITCH,         # voluntary or forced switch — player must pick a member
	WIN,
	LOSE,
}

# =============================================================================
# Private variables — battle state
# =============================================================================

var _phase: BattlePhase = BattlePhase.IDLE
var _phase_entered: bool = false
var _battle_index: int = 0

# --- Party ---
# _party: Array[CharacterState] — one entry per roster member in this fight.
# _active_index: int — which party member is currently battling.
# ALL player-side stat reads go through _active() so there is exactly one
# source of truth.  The stale _boxer_* variables have been removed.
var _party: Array[CharacterState] = []
var _active_index: int = 0

# True when the active member is being switched out because it fainted (forced);
# false for a voluntary SWITCH-button switch. On a forced switch the enemy gets
# no free hit — the player just picks a replacement and resumes input; on a
# voluntary switch the enemy DOES attack, so switching costs the player a turn.
var _forced_switch: bool = false

# Current enemy runtime data (deep-copied from MoveData.ENEMIES)
var _enemy_data: Dictionary = {}
var _enemy_hp: int = 0
var _enemy_attack_stage: int = 0
var _enemy_defense_stage: int = 0
var _enemy_accuracy_stage: int = 0  # tracks flap_dust / lower_accuracy effects on enemy
var _enemy_flinched: bool = false    # flinch_30pct effect — enemy skips next turn

# Move selected during AWAIT_PLAYER_INPUT (-1 = Struggle sentinel)
var _queued_move_index: int = -1

# Idle bob tweens — player + enemy tracked separately so attacks can stop both
var _idle_bob_tween: Tween = null
var _enemy_bob_tween: Tween = null

# Camera shake tween — tracked so a new shake cancels an in-flight one
var _shake_tween: Tween = null

# Sprite base scales captured once in _ready — idle-bob tweens animate around
# these so a bob killed mid-oscillation cannot drift the baseline over a battle.
var _player_base_scale: Vector2 = Vector2.ONE
var _enemy_base_scale: Vector2 = Vector2.ONE

# =============================================================================
# Onready references
# =============================================================================

@onready var _active_hp_bar: ProgressBar   = $UI/BoxerPanel/VBoxContainer/HPBar
@onready var _enemy_hp_bar: ProgressBar    = $UI/EnemyPanel/VBoxContainer/HPBar
@onready var _active_hp_label: Label       = $UI/BoxerPanel/VBoxContainer/HPLabel
@onready var _enemy_hp_label: Label        = $UI/EnemyPanel/VBoxContainer/HPLabel
@onready var _active_name_label: Label     = $UI/BoxerPanel/VBoxContainer/NameLabel
@onready var _enemy_name_label: Label      = $UI/EnemyPanel/VBoxContainer/NameLabel
@onready var _battle_log: RichTextLabel    = $UI/BattleLog
@onready var _move_buttons_container: GridContainer = $UI/MoveButtons
@onready var _switch_button: Button        = $UI/SwitchButton
@onready var _player_sprite: AnimatedSprite2D = $BoxerSprite
@onready var _enemy_sprite: AnimatedSprite2D  = $EnemySprite
# Bench panel — shows benched party members' status (text labels are fine)
@onready var _bench_panel: PanelContainer  = $UI/BenchPanel
@onready var _bench_labels: VBoxContainer  = $UI/BenchPanel/VBoxContainer
# Party dot rows in HP panels
@onready var _player_dots: HBoxContainer   = $UI/BoxerPanel/VBoxContainer/PartyDots
@onready var _enemy_dots: HBoxContainer    = $UI/EnemyPanel/VBoxContainer/PartyDots

# Camera2D added in code for shake effect
var _camera: Camera2D = null

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_battle_index = clampi(
		get_tree().get_meta("battle_index", 0) as int,
		0, MoveData.ENEMIES.size() - 1
	)

	_build_party()
	_setup_enemy()
	_setup_move_buttons()
	_update_hud()

	_log("A battle begins! " + _active().display_name + " faces " + _enemy_data["name"] + "!")

	_player_sprite.animation_finished.connect(_on_player_animation_finished)
	_enemy_sprite.animation_finished.connect(_on_enemy_animation_finished)
	_player_sprite.play("idle")
	_enemy_sprite.play("idle")

	# Wire the dedicated SWITCH button
	_switch_button.pressed.connect(_on_switch_button_pressed)

	# Add Camera2D for shake. anchor_mode FIXED_TOP_LEFT keeps the camera at
	# (0,0) framing world-space (0,0)-(1280,720); the engine auto-makes this the
	# current camera, and its DRAG_CENTER default would otherwise show only the
	# top-left quarter of the scene.
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = false
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)

	# Each HP bar gets its own fill stylebox so _tint_hp_bar mutates them
	# independently rather than through a shared theme resource.
	for bar: ProgressBar in [_active_hp_bar, _enemy_hp_bar]:
		var fill_sb: StyleBox = bar.get_theme_stylebox("fill")
		if fill_sb != null:
			bar.add_theme_stylebox_override("fill", fill_sb.duplicate() as StyleBox)

	_player_base_scale = _player_sprite.scale
	_enemy_base_scale = _enemy_sprite.scale
	_start_idle_bob()

	_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)


func _physics_process(_delta: float) -> void:
	if _phase_entered:
		return
	_phase_entered = true
	_enter_phase(_phase)


# =============================================================================
# Party accessor — single source of truth for the active member
# =============================================================================

func _active() -> CharacterState:
	return _party[_active_index]


# =============================================================================
# Phase state machine
# =============================================================================

func _transition_to(new_phase: BattlePhase) -> void:
	_phase = new_phase
	_phase_entered = true
	# AWAIT_PLAYER_INPUT and AWAIT_SWITCH are handled synchronously so buttons
	# appear on the same frame rather than waiting for the next physics tick.
	if new_phase == BattlePhase.AWAIT_PLAYER_INPUT or new_phase == BattlePhase.AWAIT_SWITCH:
		set_physics_process(false)
		_enter_phase(new_phase)
	else:
		set_physics_process(true)
		_phase_entered = false  # let _physics_process trigger _enter_phase


func _enter_phase(phase: BattlePhase) -> void:
	match phase:
		BattlePhase.AWAIT_PLAYER_INPUT:
			_refresh_move_buttons()
			_show_switch_button(true)
			_set_buttons_disabled(false)
		BattlePhase.PLAYER_MOVE:
			_set_buttons_disabled(true)
			_run_player_move()
		BattlePhase.ENEMY_MOVE:
			_run_enemy_move()
		BattlePhase.AWAIT_SWITCH:
			_set_buttons_disabled(true)
			_switch_button.visible = false
			_run_await_switch()
		BattlePhase.WIN:
			_set_buttons_disabled(true)
			_switch_button.visible = false
			_run_win()
		BattlePhase.LOSE:
			_set_buttons_disabled(true)
			_switch_button.visible = false
			_run_lose()
		BattlePhase.IDLE, BattlePhase.ANIMATING:
			pass


# =============================================================================
# Private methods — setup
# =============================================================================

## Build the party array from GameState.party_roster + MoveData.PARTY definitions.
## All members start at full HP and full PP (auto-heal per fight — see Phase 6 spec).
func _build_party() -> void:
	_party.clear()
	_active_index = 0

	# Tutorial ramp: only include roster members that have been unlocked.
	for party_def in MoveData.PARTY:
		var char_key: String = party_def["key"]
		if not (char_key in GameState.party_roster):
			continue
		var extra_moves: Array[String] = []
		if GameState.party_moves.has(char_key):
			for m: String in GameState.party_moves[char_key]:
				extra_moves.append(m)
		# Special case: boxer may also have solidarity from gatekeeper bonus
		if char_key == "boxer" and GameState.has_gatekeeper_bonus:
			if not ("solidarity" in extra_moves):
				extra_moves.append("solidarity")
		var cs: CharacterState = CharacterState.from_party_def(party_def, extra_moves)
		_party.append(cs)

	if _party.is_empty():
		push_error("BattleScene._build_party: party is empty — falling back to boxer defaults")
		var boxer_def: Dictionary = MoveData.PARTY[0]
		_party.append(CharacterState.from_party_def(boxer_def, []))


func _setup_player_sprite_for(cs: CharacterState) -> void:
	# If the character has a real sprite_frames_path, load it.
	# Otherwise fall back to the boxer SpriteFrames already in the scene (placeholder).
	var sf_path: String = cs.sprite_frames_path
	if sf_path != "" and ResourceLoader.exists(sf_path):
		var sf: SpriteFrames = load(sf_path) as SpriteFrames
		if sf != null:
			_player_sprite.sprite_frames = sf
	# else: leave the scene's default SpriteFrames (boxer) in place — placeholder.
	_player_sprite.play("idle")


func _setup_enemy() -> void:
	_enemy_data = MoveData.ENEMIES[_battle_index].duplicate(true)
	_enemy_hp = _enemy_data["max_hp"]
	_enemy_attack_stage = 0
	_enemy_defense_stage = 0
	_enemy_accuracy_stage = 0
	_enemy_flinched = false
	var sf_path: String = _enemy_data.get("sprite_frames", "")
	if sf_path != "" and ResourceLoader.exists(sf_path):
		var sf: SpriteFrames = load(sf_path) as SpriteFrames
		if sf != null:
			_enemy_sprite.sprite_frames = sf
	# Ensure the enemy frames resource has an "attack" animation; if not, add one.
	if _enemy_sprite.sprite_frames != null and not _enemy_sprite.sprite_frames.has_animation("attack"):
		_enemy_sprite.sprite_frames.add_animation("attack")
		if _enemy_sprite.sprite_frames.get_frame_count("idle") > 0:
			var tex: Texture2D = _enemy_sprite.sprite_frames.get_frame_texture("idle", 0)
			_enemy_sprite.sprite_frames.add_frame("attack", tex, 1.0)
		_enemy_sprite.sprite_frames.set_animation_loop("attack", false)


func _setup_move_buttons() -> void:
	# Connect move slots 0-4 only (5 slots; SWITCH is now a separate button)
	for i: int in range(_move_buttons_container.get_child_count()):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn == null:
			continue
		btn.pressed.connect(_on_move_button_pressed.bind(i))

	_refresh_move_buttons()


## Refresh the move buttons for the current active member.
func _refresh_move_buttons() -> void:
	var active: CharacterState = _active()

	var all_pp_empty: bool = true
	for move_key: String in active.moves:
		if active.pp.get(move_key, 0) > 0:
			all_pp_empty = false
			break

	var move_count: int = mini(active.moves.size(), 6)  # up to 6 move slots
	for i: int in range(_move_buttons_container.get_child_count()):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn == null:
			continue
		if all_pp_empty and i == 0:
			btn.text = "STRUGGLE"
			btn.disabled = false
			btn.visible = true
		elif all_pp_empty:
			btn.visible = false
		elif i < move_count:
			var move_key: String = active.moves[i]
			var move: Dictionary = MoveData.MOVES[move_key]
			var pp_now: int = active.pp[move_key]
			var pp_max: int = move["max_pp"]
			btn.text = move["display"] + "\n(" + str(pp_now) + "/" + str(pp_max) + ")"
			btn.disabled = (pp_now <= 0)
			btn.visible = true
		else:
			btn.visible = false

	# Refresh SWITCH button state
	_show_switch_button(true)


func _show_switch_button(visible_val: bool) -> void:
	if _switch_button == null:
		return
	var living_benched: int = _count_living_benched()
	_switch_button.text = "SWITCH"
	_switch_button.visible = visible_val and living_benched > 0
	_switch_button.disabled = (living_benched == 0)


# =============================================================================
# Idle bob — gentle Y-scale pulse on player and enemy sprites
# =============================================================================

func _start_idle_bob() -> void:
	if _idle_bob_tween != null:
		_idle_bob_tween.kill()
	if _enemy_bob_tween != null:
		_enemy_bob_tween.kill()
	_idle_bob_tween = create_tween().set_loops()
	var base_scale: Vector2 = _player_base_scale
	var base_enemy_scale: Vector2 = _enemy_base_scale
	_idle_bob_tween.tween_property(_player_sprite, "scale",
		Vector2(base_scale.x, base_scale.y * 1.025), 0.55
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_bob_tween.tween_property(_player_sprite, "scale",
		base_scale, 0.55
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Stagger enemy bob slightly out of phase
	_enemy_bob_tween = create_tween().set_loops()
	_enemy_bob_tween.tween_interval(0.28)
	_enemy_bob_tween.tween_property(_enemy_sprite, "scale",
		Vector2(base_enemy_scale.x, base_enemy_scale.y * 1.025), 0.55
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_enemy_bob_tween.tween_property(_enemy_sprite, "scale",
		base_enemy_scale, 0.55
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# =============================================================================
# Coroutines — player, enemy, switch
# =============================================================================

func _run_player_move() -> void:
	var move_index: int = _queued_move_index
	_queued_move_index = -1
	var active: CharacterState = _active()

	# Flinch check — skip turn if flinched
	if active.flinched:
		active.flinched = false
		await _log(active.display_name + " is flinching and cannot move!")
		_update_hud()
		_transition_to(BattlePhase.ENEMY_MOVE)
		return

	if move_index == -1:
		var struggle_move: Dictionary = {
			"name": "Struggle",
			"display": "STRUGGLE",
			"base_power": 50,
			"type": "Normal",
			"pp": 0,
			"max_pp": 0,
			"effect": "none",
		}
		await _execute_player_move(struggle_move)
	else:
		var move_key: String = active.moves[move_index]
		active.pp[move_key] -= 1
		await _execute_player_move(MoveData.MOVES[move_key])

	if _enemy_hp <= 0:
		_transition_to(BattlePhase.WIN)
		return

	await get_tree().create_timer(0.35).timeout
	_transition_to(BattlePhase.ENEMY_MOVE)


func _run_enemy_move() -> void:
	# Flinch check — skip if flinched
	if _enemy_flinched:
		_enemy_flinched = false
		await _log(_enemy_data["name"] + " is flinching and cannot move!")
		_update_hud()
		_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)
		return

	var move: Dictionary = _pick_enemy_move()
	await _execute_enemy_move(move)
	_update_hud()

	if _active().current_hp <= 0:
		if _count_living_benched() > 0:
			_forced_switch = true
			await _log(_active().display_name + " fainted! Choose another fighter!")
			_transition_to(BattlePhase.AWAIT_SWITCH)
		else:
			_transition_to(BattlePhase.LOSE)
		return

	_active().enduring = false
	_update_hud()
	_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)


func _run_await_switch() -> void:
	# Build switch options from living benched members.
	# Re-use move button slots 0..N-1 as switch targets, hide the rest.
	# The last visible slot is always CANCEL (returns to AWAIT_PLAYER_INPUT).
	var benched: Array[int] = _living_benched_indices()
	var total_btns: int = _move_buttons_container.get_child_count()
	for i: int in range(total_btns):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn == null:
			continue
		if i < benched.size():
			var party_i: int = benched[i]
			var cs: CharacterState = _party[party_i]
			btn.text = cs.display_name + "\nHP:" + str(cs.current_hp) + "/" + str(cs.max_hp)
			btn.visible = true
			btn.disabled = false
		elif i == benched.size() and not _forced_switch:
			# CANCEL slot — only show for voluntary switch
			btn.text = "CANCEL"
			btn.visible = true
			btn.disabled = false
		else:
			btn.visible = false

	# SWITCH button hidden while picking
	_switch_button.visible = false


func _run_win() -> void:
	await _log("Victory! The animals prevail!")
	GameState.battle_wins += 1

	# Tutorial ramp — unlock roster members
	if _battle_index == 0 and not ("jessie" in GameState.party_roster):
		GameState.party_roster.append("jessie")
		await get_tree().create_timer(0.2).timeout
		await _log("Jessie the dog has joined the party!")
	elif _battle_index == 1 and not ("hen" in GameState.party_roster):
		GameState.party_roster.append("hen")
		await get_tree().create_timer(0.2).timeout
		await _log("A brave Hen has joined the party!")

	# Move unlock (character-aware)
	var unlock_data: Variant = MoveData.MOVE_UNLOCKS.get(_battle_index + 1, null)
	if unlock_data != null and unlock_data is Dictionary:
		var char_key: String = unlock_data["character"]
		var move_key: String = unlock_data["move"]
		if char_key in GameState.party_roster:
			if not GameState.party_moves.has(char_key):
				GameState.party_moves[char_key] = []
			var char_moves: Array = GameState.party_moves[char_key]
			if not (move_key in char_moves):
				char_moves.append(move_key)
				GameState.party_moves[char_key] = char_moves
				var move_display: String = MoveData.MOVES[move_key]["display"]
				await get_tree().create_timer(0.35).timeout
				await _log(char_key.capitalize() + " learned: " + move_display + "!")

	GameState.save_to_disk()
	await get_tree().create_timer(1.2).timeout
	SceneManager.go_to_scene("res://scenes/act3/cowshed_overworld.tscn")


func _run_lose() -> void:
	await _log("The animals have fallen...")
	await get_tree().create_timer(1.2).timeout
	SceneManager.go_to_scene("res://scenes/act3/battle/battle_loss.tscn")


# =============================================================================
# Private methods — move execution
# =============================================================================

func _on_move_button_pressed(move_index: int) -> void:
	if _phase == BattlePhase.AWAIT_SWITCH:
		var benched: Array[int] = _living_benched_indices()
		if move_index < benched.size():
			_do_switch(benched[move_index])
		elif move_index == benched.size() and not _forced_switch:
			# CANCEL — return to normal input
			_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)
		return

	if _phase != BattlePhase.AWAIT_PLAYER_INPUT:
		return

	# Check if in Struggle mode (all moves at 0 PP)
	var active: CharacterState = _active()
	var all_pp_empty: bool = true
	for move_key: String in active.moves:
		if active.pp.get(move_key, 0) > 0:
			all_pp_empty = false
			break

	if all_pp_empty:
		if move_index == 0:
			_queued_move_index = -1
			_transition_to(BattlePhase.PLAYER_MOVE)
		return

	if move_index >= active.moves.size():
		return
	var move_key: String = active.moves[move_index]
	if active.pp[move_key] <= 0:
		return

	_queued_move_index = move_index
	_transition_to(BattlePhase.PLAYER_MOVE)


func _on_switch_button_pressed() -> void:
	if _phase != BattlePhase.AWAIT_PLAYER_INPUT:
		return
	if _count_living_benched() > 0:
		_forced_switch = false
		_transition_to(BattlePhase.AWAIT_SWITCH)


## Perform a voluntary or forced switch.
func _do_switch(new_index: int) -> void:
	_set_buttons_disabled(true)
	var old_member: CharacterState = _active()
	old_member.reset_stages()   # Pokémon rule: stages reset on switch-out

	_active_index = new_index
	var new_member: CharacterState = _active()
	_setup_player_sprite_for(new_member)
	_update_hud()
	await _log(old_member.display_name + " switches out! Go, " + new_member.display_name + "!")
	_update_hud()

	# Refresh move labels for the incoming member, then re-disable: the phase is
	# still AWAIT_SWITCH here, so a click during the 0.35s timer below would be
	# misread as a bench pick. Buttons re-enable via the AWAIT_PLAYER_INPUT path.
	_refresh_move_buttons()
	_set_buttons_disabled(true)
	_switch_button.visible = false

	if _forced_switch:
		_forced_switch = false
		_transition_to(BattlePhase.AWAIT_PLAYER_INPUT)
	else:
		await get_tree().create_timer(0.35).timeout
		_transition_to(BattlePhase.ENEMY_MOVE)


func _execute_player_move(move: Dictionary) -> void:
	var active: CharacterState = _active()
	await _log(active.display_name + " uses " + move["name"] + "!")
	await get_tree().create_timer(0.2).timeout

	var effect: String = move.get("effect", "none")
	var is_damage_move: bool = move.get("base_power", 0) > 0

	if is_damage_move:
		# Lunge tween toward enemy then back
		await _play_attacker_lunge(_player_sprite, _enemy_sprite)

	match effect:
		"none":
			await _deal_player_damage(move)
		"flinch_30pct":
			await _deal_player_damage(move)
			if _enemy_hp > 0 and randf() < 0.30:
				_enemy_flinched = true
				await _log(_enemy_data["name"] + " flinched!")
		"double_next_turn":
			await _deal_player_damage(move)
			active.double_next_turn = true
			await _log(active.display_name + " is fired up — next attack deals double damage!")
		"miss_20pct":
			if randf() < 0.2:
				await _log("But it missed!")
			else:
				await _deal_player_damage(move)
		"raise_defense":
			active.defense_stage = mini(active.defense_stage + 1, 6)
			await _log(active.display_name + "'s defence rose!")
		"raise_attack":
			active.attack_stage = mini(active.attack_stage + 1, 6)
			await _log(active.display_name + "'s attack rose!")
		"raise_defense_2":
			active.defense_stage = mini(active.defense_stage + 2, 6)
			await _log(active.display_name + "'s defence sharply rose!")
		"lower_attack":
			_enemy_attack_stage = maxi(_enemy_attack_stage - 1, -6)
			await _log(_enemy_data["name"] + "'s attack fell!")
		"lower_accuracy":
			_enemy_accuracy_stage = maxi(_enemy_accuracy_stage - 1, -6)
			await _log(_enemy_data["name"] + "'s accuracy fell!")
		"survive_one_hit":
			active.enduring = true
			await _log(active.display_name + " braces — will endure this turn!")
		"heal_10hp":
			active.current_hp = mini(active.max_hp, active.current_hp + 10)
			await _log("Solidarity restores " + active.display_name + "'s spirit! (+10 HP)")
		"heal_15hp":
			active.current_hp = mini(active.max_hp, active.current_hp + 15)
			await _log(active.display_name + " rallies the troops! (+15 HP)")

	_update_hud()
	await get_tree().create_timer(0.15).timeout


func _execute_enemy_move(move: Dictionary) -> void:
	await _log(_enemy_data["name"] + " uses " + move["name"] + "!")
	await get_tree().create_timer(0.2).timeout

	var effect: String = move.get("effect", "none")
	var is_damage_move: bool = move.get("base_power", 0) > 0

	if is_damage_move:
		# Accuracy check
		if _enemy_accuracy_stage < 0:
			var miss_chance: float = float(-_enemy_accuracy_stage) * 0.15
			if randf() < miss_chance:
				await _log("The attack missed!")
				return

		# Enemy lunge toward player
		await _play_attacker_lunge(_enemy_sprite, _player_sprite)

	match effect:
		"none":
			await _deal_enemy_damage(move)
		"flinch_30pct":
			await _deal_enemy_damage(move)
			if _active().current_hp > 0 and randf() < 0.30:
				_active().flinched = true
				await _log(_active().display_name + " flinched!")
		"double_next_turn":
			await _deal_enemy_damage(move)
			# Enemy double_next_turn: stored in enemy data dict at runtime
			_enemy_data["double_next_turn_pending"] = true
			await _log(_enemy_data["name"] + " is powering up — next attack deals double damage!")
		"miss_20pct":
			if randf() < 0.2:
				await _log("But it missed!")
			else:
				await _deal_enemy_damage(move)
		"raise_defense", "raise_defense_2":
			var amount: int = 2 if effect == "raise_defense_2" else 1
			_enemy_defense_stage = mini(_enemy_defense_stage + amount, 6)
			var tag: String = "sharply " if amount == 2 else ""
			await _log(_enemy_data["name"] + "'s defence " + tag + "rose!")
		"raise_attack":
			_enemy_attack_stage = mini(_enemy_attack_stage + 1, 6)
			await _log(_enemy_data["name"] + "'s attack rose!")
		"lower_attack":
			var active: CharacterState = _active()
			active.attack_stage = maxi(active.attack_stage - 1, -6)
			await _log(active.display_name + "'s attack fell!")
		_:
			await _deal_enemy_damage(move)

	_update_hud()
	await get_tree().create_timer(0.15).timeout


func _deal_player_damage(move: Dictionary) -> void:
	var base_power: int = move.get("base_power", 0)
	if base_power == 0:
		return
	var active: CharacterState = _active()
	var atk: int = int(float(active.attack) * _stage_multiplier(active.attack_stage))
	var def: int = int(float(_enemy_data["defense"]) * _stage_multiplier(_enemy_defense_stage))
	var dmg: int = MoveData.calculate_damage(active.level, base_power, atk, def)

	# double_next_turn flag
	if active.double_next_turn:
		dmg = dmg * 2
		active.double_next_turn = false

	# Weapon matchup multiplier
	var multiplier: float = _player_attack_multiplier(active.weapon_type)
	dmg = int(float(dmg) * multiplier)
	dmg = maxi(1, dmg)

	_enemy_hp = maxi(0, _enemy_hp - dmg)
	var matchup_tag: String = ""
	if multiplier > 1.0:
		matchup_tag = " [b]It's super effective![/b]"
	await _log(active.display_name + " dealt " + str(dmg) + " damage!" + matchup_tag)

	# Impact juice on enemy sprite
	if dmg > 0:
		_play_hit_flash(_enemy_sprite)
		await _play_target_recoil(_enemy_sprite, Vector2(-18, 0))
		_play_camera_shake(0.22)


func _deal_enemy_damage(move: Dictionary) -> void:
	var base_power: int = move.get("base_power", 0)
	if base_power == 0:
		return
	var active: CharacterState = _active()
	var atk: int = int(float(_enemy_data["attack"]) * _stage_multiplier(_enemy_attack_stage))
	var def: int = int(float(active.defense) * _stage_multiplier(active.defense_stage))
	var dmg: int = MoveData.calculate_damage(_enemy_data["level"], base_power, atk, def)

	# Enemy double_next_turn flag
	if _enemy_data.get("double_next_turn_pending", false):
		dmg = dmg * 2
		_enemy_data.erase("double_next_turn_pending")

	# Weapon matchup — defensive multiplier
	var multiplier: float = _enemy_damage_multiplier(active.weapon_type)
	dmg = int(float(dmg) * multiplier)
	dmg = maxi(1, dmg)

	if active.enduring and (active.current_hp - dmg) <= 0:
		dmg = active.current_hp - 1
		await _log(active.display_name + " endured the hit!")
	active.current_hp = maxi(0, active.current_hp - dmg)
	var matchup_tag: String = ""
	if multiplier > 1.0:
		matchup_tag = " [b]It's super effective![/b]"
	elif multiplier < 1.0:
		matchup_tag = " It's not very effective..."
	await _log(_enemy_data["name"] + " dealt " + str(dmg) + " damage to " + active.display_name + "!" + matchup_tag)

	# Impact juice on player sprite
	if dmg > 0:
		_play_hit_flash(_player_sprite)
		await _play_target_recoil(_player_sprite, Vector2(18, 0))
		_play_camera_shake(0.22)


# =============================================================================
# Attack juice helpers
# =============================================================================

## Lunge attacker toward target, play attack animation, then return.
func _play_attacker_lunge(attacker: AnimatedSprite2D, target: AnimatedSprite2D) -> void:
	var origin: Vector2 = attacker.position
	var toward: Vector2 = (target.position - origin).normalized() * 36.0
	var lunge_pos: Vector2 = origin + toward

	# Kill any running bob tweens to avoid fighting over sprite scale
	if _idle_bob_tween != null:
		_idle_bob_tween.kill()
		_idle_bob_tween = null
	if _enemy_bob_tween != null:
		_enemy_bob_tween.kill()
		_enemy_bob_tween = null

	var tw: Tween = create_tween()
	tw.tween_property(attacker, "position", lunge_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: attacker.play("attack"))
	tw.tween_interval(0.14)
	tw.tween_property(attacker, "position", origin, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	attacker.play("idle")
	# Restart idle bob after lunge
	_start_idle_bob()


## Flash the target white briefly to signal a hit.
func _play_hit_flash(target: AnimatedSprite2D) -> void:
	target.modulate = Color(2.2, 2.2, 2.2, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.18).set_trans(Tween.TRANS_LINEAR)


## Recoil the target briefly in the given direction.
func _play_target_recoil(target: AnimatedSprite2D, offset: Vector2) -> void:
	var origin: Vector2 = target.position
	var tw: Tween = create_tween()
	tw.tween_property(target, "position", origin + offset, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "position", origin, 0.10).set_ease(Tween.EASE_IN)
	await tw.finished


## Short camera shake.
func _play_camera_shake(duration: float) -> void:
	if _camera == null:
		return
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = int(duration / 0.03)
	for i: int in range(steps):
		var rx: float = randf_range(-4.0, 4.0)
		var ry: float = randf_range(-3.0, 3.0)
		_shake_tween.tween_property(_camera, "position", Vector2(rx, ry), 0.03)
	_shake_tween.tween_property(_camera, "position", Vector2.ZERO, 0.05)


# =============================================================================
# Phase 5 — weapon matchup multipliers
# =============================================================================

func _player_attack_multiplier(weapon_type: String) -> float:
	var enemy_wc: String = _enemy_data.get("weapon_class", "")
	var counters_wc: String = MoveData.MATCHUP_COUNTERS.get(weapon_type, "")
	if counters_wc != "" and counters_wc == enemy_wc:
		return 1.5
	return 1.0


func _enemy_damage_multiplier(weapon_type: String) -> float:
	var enemy_wc: String = _enemy_data.get("weapon_class", "")
	var counters_wc: String = MoveData.MATCHUP_COUNTERS.get(weapon_type, "")
	var weak_to_wc: String = MoveData.MATCHUP_WEAK_TO.get(weapon_type, "")
	if counters_wc != "" and counters_wc == enemy_wc:
		return 0.5
	if weak_to_wc != "" and weak_to_wc == enemy_wc:
		return 1.5
	return 1.0


# =============================================================================
# Phase 7 — Light enemy AI
# =============================================================================

func _pick_enemy_move() -> Dictionary:
	var enemy_moves: Array = _enemy_data["moves"]
	var active: CharacterState = _active()

	var damage_moves: Array = []
	var status_moves: Array = []
	for m: Dictionary in enemy_moves:
		if m.get("base_power", 0) > 0:
			damage_moves.append(m)
		else:
			status_moves.append(m)

	var enemy_wc: String = _enemy_data.get("weapon_class", "")
	var weak_to: String = MoveData.MATCHUP_WEAK_TO.get(active.weapon_type, "")
	var matchup_favours_enemy: bool = (enemy_wc != "" and enemy_wc == weak_to)
	var low_hp: bool = float(_enemy_hp) / float(_enemy_data["max_hp"]) < 0.4

	if (matchup_favours_enemy or low_hp) and not damage_moves.is_empty():
		damage_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("base_power", 0) > b.get("base_power", 0))
		return damage_moves[0]

	if not status_moves.is_empty() and randf() < 0.25:
		return status_moves[randi() % status_moves.size()]

	if not damage_moves.is_empty():
		return damage_moves[randi() % damage_moves.size()]
	return enemy_moves[randi() % enemy_moves.size()]


# =============================================================================
# Sprite callbacks
# =============================================================================

func _on_player_animation_finished() -> void:
	if _player_sprite.animation == "attack":
		_player_sprite.play("idle")


func _on_enemy_animation_finished() -> void:
	if _enemy_sprite.animation == "attack":
		_enemy_sprite.play("idle")


# =============================================================================
# Private methods — HUD
# =============================================================================

func _update_hud() -> void:
	var active: CharacterState = _active()
	_active_name_label.text = active.display_name + "  Lv." + str(active.level)
	_active_hp_bar.max_value = active.max_hp
	_active_hp_bar.value = active.current_hp
	_active_hp_label.text = "HP  " + str(active.current_hp) + "/" + str(active.max_hp)

	_enemy_name_label.text = _enemy_data.get("name", "???") + "  Lv." + str(_enemy_data.get("level", "?"))
	_enemy_hp_bar.max_value = _enemy_data["max_hp"]
	_enemy_hp_bar.value = _enemy_hp
	_enemy_hp_label.text = "HP  " + str(_enemy_hp) + "/" + str(_enemy_data["max_hp"])

	_tint_hp_bar(_active_hp_bar, float(active.current_hp) / float(active.max_hp))
	_tint_hp_bar(_enemy_hp_bar, float(_enemy_hp) / float(_enemy_data["max_hp"]))

	_update_party_dots()
	_update_bench_panel()


func _update_party_dots() -> void:
	# Player party dots — one dot per member, green = alive, grey = fainted
	if _player_dots != null:
		for child: Node in _player_dots.get_children():
			child.queue_free()
		for i: int in range(_party.size()):
			var dot: Label = Label.new()
			dot.text = "●"
			if _party[i].current_hp > 0:
				dot.add_theme_color_override("font_color",
					Color(0.22, 0.70, 0.22, 1) if i == _active_index else Color(0.32, 0.56, 0.20, 1))
			else:
				dot.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46, 1))
			dot.add_theme_font_size_override("font_size", 14)
			_player_dots.add_child(dot)

	# Enemy panel dots — not applicable (single enemy), leave empty
	if _enemy_dots != null:
		for child: Node in _enemy_dots.get_children():
			child.queue_free()


func _update_bench_panel() -> void:
	if _bench_labels == null:
		return
	for child: Node in _bench_labels.get_children():
		child.queue_free()
	var has_bench: bool = false
	for i: int in range(_party.size()):
		if i == _active_index:
			continue
		var cs: CharacterState = _party[i]
		var lbl: Label = Label.new()
		var status: String = "fainted" if cs.current_hp <= 0 else str(cs.current_hp) + "/" + str(cs.max_hp)
		lbl.text = cs.display_name + "  " + status
		lbl.add_theme_color_override("font_color",
			Color(0.55, 0.5, 0.44) if cs.current_hp <= 0 else Color(0.18, 0.12, 0.06))
		lbl.add_theme_font_size_override("font_size", 16)
		_bench_labels.add_child(lbl)
		has_bench = true
	if _bench_panel != null:
		_bench_panel.visible = has_bench


func _tint_hp_bar(bar: ProgressBar, frac: float) -> void:
	var sb: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if sb == null:
		return
	if frac > 0.5:
		sb.bg_color = Color(0.28, 0.72, 0.20, 1)
	elif frac > 0.2:
		sb.bg_color = Color(0.82, 0.64, 0.24)
	else:
		sb.bg_color = Color(0.78, 0.18, 0.14)


func _log(text: String) -> void:
	_battle_log.append_text(text + "\n")
	await get_tree().process_frame
	_battle_log.scroll_to_line(_battle_log.get_line_count() - 1)


func _set_buttons_disabled(disabled: bool) -> void:
	for i: int in range(_move_buttons_container.get_child_count()):
		var btn: Button = _move_buttons_container.get_child(i) as Button
		if btn != null:
			btn.disabled = disabled
	if _switch_button != null:
		_switch_button.disabled = disabled


# =============================================================================
# Private methods — party helpers
# =============================================================================

func _count_living_benched() -> int:
	return _living_benched_indices().size()


func _living_benched_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in range(_party.size()):
		if i != _active_index and _party[i].is_alive():
			result.append(i)
	return result


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
