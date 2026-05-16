## Ported from gdquest-demos/godot-open-rpg src/combat/combat.gd
class_name PoliticsTactics
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const INITIAL_COLS: int = 8
const ROWS: int = 6
const CELL_SIZE: int = 80

# Grid drawing colours
const COLOR_GRID_BORDER: Color     = Color(0.2, 0.1, 0.05, 0.8)
const COLOR_SHRUNK_AREA: Color     = Color(0.05, 0.0, 0.0, 0.9)
const COLOR_VALID_MOVE: Color      = Color(0.3, 0.7, 0.3, 0.4)
const COLOR_SELECTED_UNIT: Color   = Color(0.9, 0.9, 0.3, 0.5)

# =============================================================================
# Enums
# =============================================================================

## Combat phase tracker. Mirrors open-rpg combat.gd phase pattern.
enum TacticsPhase { AWAIT_PLAYER_MOVE, AWAIT_PLAYER_ACTION, AI_TURN, ANIMATING }

# =============================================================================
# Signals
# =============================================================================

@warning_ignore("unused_signal")
signal turn_ended
signal game_over

# =============================================================================
# Private variables
# =============================================================================

var _grid_cols: int = INITIAL_COLS
var _round_count: int = 0
var _phase: TacticsPhase = TacticsPhase.AWAIT_PLAYER_MOVE
var _valid_moves: Array[Vector2i] = []

# Unit references
var _snowball: UnitBase = null
var _dogs: Array[UnitBase] = []
var _squealer: UnitBase = null

# Grid occupancy: Vector2i → UnitBase
var _unit_positions: Dictionary = {}

# =============================================================================
# @onready variables
# =============================================================================

@onready var _turn_label: Label               = %TurnLabel
@onready var _hp_label: Label                 = %SnowballHPLabel
@onready var _action_panel: PanelContainer    = %ActionPanel
@onready var _feedback_label: Label           = %FeedbackLabel
@onready var _game_over_panel: PanelContainer = %GameOverPanel
@onready var _battle_cry_btn: Button          = %BattleCryBtn
@onready var _windmill_btn: Button            = %WindmillBtn
@onready var _wait_btn: Button                = %WaitBtn

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_connect_buttons()
	_setup_units()
	_draw_grid_state()
	_update_hp_label()
	_next_round()


func _draw() -> void:
	_draw_shrunk_area()
	_draw_active_cells()
	_draw_valid_move_highlights()


func _input(event: InputEvent) -> void:
	if _phase != TacticsPhase.AWAIT_PLAYER_MOVE:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_handle_click(get_local_mouse_position())

# =============================================================================
# Public methods — coordinator API (called by action/AI nodes)
# =============================================================================

func get_grid_offset_x() -> int:
	return 80 + (INITIAL_COLS - _grid_cols) * CELL_SIZE


## Returns the living dogs array. Used by BattleCryAction.
func get_dogs() -> Array[UnitBase]:
	return _dogs


## Moves unit to target cell if valid and unoccupied. Called by BattleCryAction.
## Returns true if the push succeeded, false if blocked.
func push_unit(unit: UnitBase, target: Vector2i) -> bool:
	if _is_valid_cell(target) and not _unit_positions.has(target):
		_move_unit(unit, target)
		return true
	return false


## Writes to the feedback label. Called by action subclasses.
func show_feedback(text: String) -> void:
	_feedback_label.text = text


## Moves dog one step toward Snowball. Called by TacticsAI.
func move_dog_toward_snowball(dog: UnitBase) -> void:
	var dir: Vector2i = _snowball.grid_pos - dog.grid_pos
	var step: Vector2i
	if abs(dir.x) >= abs(dir.y):
		step = Vector2i(sign(dir.x), 0)
	else:
		step = Vector2i(0, sign(dir.y))
	var target: Vector2i = dog.grid_pos + step
	if _is_valid_cell(target) and not _unit_positions.has(target):
		_move_unit(dog, target)


## Attacks Snowball if dog is adjacent. Called by TacticsAI.
func try_dog_attack(dog: UnitBase) -> void:
	if _manhattan(dog.grid_pos, _snowball.grid_pos) != 1:
		return
	var dmg: int = maxi(1, dog.attack - _snowball.defense_bonus)
	_snowball.take_damage(dmg)
	_turn_label.text = "A dog attacks Snowball! (-%d HP)" % dmg

# =============================================================================
# Private methods — setup
# =============================================================================

func _connect_buttons() -> void:
	_battle_cry_btn.pressed.connect(_on_action_selected.bind(BattleCryAction.new()))
	_windmill_btn.pressed.connect(_on_action_selected.bind(WindmillAction.new()))
	_wait_btn.pressed.connect(_on_action_selected.bind(WaitAction.new()))


func _setup_units() -> void:
	_snowball = %Snowball as UnitBase
	_squealer = %Squealer as UnitBase

	var dog1: UnitBase = %Dog1 as UnitBase
	var dog2: UnitBase = %Dog2 as UnitBase
	_dogs = [dog1, dog2]

	# Attach TacticsAI to each dog — required for _run_ai_turn() to drive them.
	# Scene has no TacticsAI child nodes, so we add them here at runtime.
	for dog: UnitBase in _dogs:
		var ai := TacticsAI.new()
		ai.name = "TacticsAI"
		dog.add_child(ai)

	# Place Snowball on the right side
	@warning_ignore("integer_division")
	_place_unit(_snowball, Vector2i(_grid_cols - 1, ROWS / 2))

	# Dogs start on the left
	_place_unit(dog1, Vector2i(1, 2))
	_place_unit(dog2, Vector2i(1, 3))

	# Squealer at the far left
	_place_unit(_squealer, Vector2i(0, 2))

# =============================================================================
# Private methods — grid
# =============================================================================

func _place_unit(unit: UnitBase, cell: Vector2i) -> void:
	unit.grid_pos = cell
	_unit_positions[cell] = unit
	_apply_visual_position(unit)


func _apply_visual_position(unit: UnitBase) -> void:
	var offset_x: int = get_grid_offset_x()
	var half_cell: float = CELL_SIZE / 2.0
	unit.position = Vector2(
		float(offset_x + unit.grid_pos.x * CELL_SIZE) + half_cell,
		float(80 + unit.grid_pos.y * CELL_SIZE) + half_cell
	)


func _move_unit(unit: UnitBase, target: Vector2i) -> void:
	_unit_positions.erase(unit.grid_pos)
	unit.grid_pos = target
	_unit_positions[target] = unit
	_apply_visual_position(unit)
	_valid_moves.clear()
	queue_redraw()


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _grid_cols and cell.y >= 0 and cell.y < ROWS


func _compute_valid_moves(unit: UnitBase) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var range_val: int = unit.move_range
	var pos: Vector2i = unit.grid_pos
	for dx: int in range(-range_val, range_val + 1):
		for dy: int in range(-range_val, range_val + 1):
			# Exclude standing cell (dx==0, dy==0): moving there wastes the turn.
			if dx == 0 and dy == 0:
				continue
			if abs(dx) + abs(dy) <= range_val:
				var target: Vector2i = Vector2i(pos.x + dx, pos.y + dy)
				if _is_valid_cell(target) and not _unit_positions.has(target):
					moves.append(target)
	return moves


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

# =============================================================================
# Private methods — drawing
# =============================================================================

func _draw_grid_state() -> void:
	queue_redraw()


func _draw_shrunk_area() -> void:
	var lost_cols: int = INITIAL_COLS - _grid_cols
	if lost_cols <= 0:
		return
	var shrunk_rect: Rect2 = Rect2(
		80.0, 80.0,
		float(lost_cols * CELL_SIZE),
		float(ROWS * CELL_SIZE)
	)
	draw_rect(shrunk_rect, COLOR_SHRUNK_AREA)


func _draw_active_cells() -> void:
	var offset_x: int = get_grid_offset_x()
	for col: int in range(_grid_cols):
		for row: int in range(ROWS):
			var rect: Rect2 = Rect2(
				float(offset_x + col * CELL_SIZE),
				float(80 + row * CELL_SIZE),
				float(CELL_SIZE - 2),
				float(CELL_SIZE - 2)
			)
			draw_rect(rect, COLOR_GRID_BORDER, false, 2.0)


func _draw_valid_move_highlights() -> void:
	var offset_x: int = get_grid_offset_x()
	for cell: Vector2i in _valid_moves:
		var rect: Rect2 = Rect2(
			float(offset_x + cell.x * CELL_SIZE),
			float(80 + cell.y * CELL_SIZE),
			float(CELL_SIZE - 2),
			float(CELL_SIZE - 2)
		)
		draw_rect(rect, COLOR_VALID_MOVE)

# =============================================================================
# Private methods — round / turn flow (mirrors open-rpg combat.gd)
# =============================================================================

## Starts the player's move phase for a new round. Mirrors open-rpg next_round().
## If Snowball is completely boxed in (no valid moves), auto-advances to the
## action phase so the player can still act — prevents a permanent softlock.
func _next_round() -> void:
	_phase = TacticsPhase.AWAIT_PLAYER_MOVE
	_action_panel.hide()
	_turn_label.text = "Round %d — SNOWBALL'S MOVE" % (_round_count + 1)
	_valid_moves = _compute_valid_moves(_snowball)
	queue_redraw()
	if _valid_moves.is_empty():
		_turn_label.text = "Round %d — Snowball is surrounded! Choose an action." % (_round_count + 1)
		_phase = TacticsPhase.AWAIT_PLAYER_ACTION
		_feedback_label.text = ""
		_action_panel.show()


func _handle_click(click_pos: Vector2) -> void:
	var offset_x: int = get_grid_offset_x()
	var col: int = int((click_pos.x - float(offset_x)) / float(CELL_SIZE))
	var row: int = int((click_pos.y - 80.0) / float(CELL_SIZE))
	var clicked_cell: Vector2i = Vector2i(col, row)

	if _phase == TacticsPhase.AWAIT_PLAYER_MOVE and clicked_cell in _valid_moves:
		_move_unit(_snowball, clicked_cell)
		_phase = TacticsPhase.AWAIT_PLAYER_ACTION
		_feedback_label.text = ""
		_action_panel.show()

# =============================================================================
# Private methods — player action dispatch (mirrors open-rpg two-phase chain)
# =============================================================================

## Unified action handler. Wired to all three buttons via BattleCryAction,
## WindmillAction, WaitAction. Mirrors open-rpg combat.gd player→enemy chain.
func _on_action_selected(action: TacticsAction) -> void:
	# Guard: only accept actions during the player-action phase.
	# Prevents re-entrant coroutine launches from rapid double-press.
	if _phase != TacticsPhase.AWAIT_PLAYER_ACTION:
		return
	_snowball.cached_action = action
	_phase = TacticsPhase.ANIMATING
	_snowball.act(self)
	_action_panel.hide()
	_phase = TacticsPhase.AI_TURN
	await _run_ai_turn()
	_update_hp_label()

	if _snowball.hp <= 0:
		await get_tree().create_timer(0.8).timeout
		_trigger_game_over()
		return

	_round_count += 1
	if _round_count % 3 == 0:
		await _shrink_grid()
		if _snowball.hp <= 0 or not _snowball.visible:
			return

	_next_round()

# =============================================================================
# Private methods — AI turn (delegates to TacticsAI child nodes)
# =============================================================================

## Enemy turn loop. Each dog's TacticsAI node drives its own turn.
## Mirrors open-rpg combat.gd enemy coroutine phase.
func _run_ai_turn() -> void:
	for dog: UnitBase in _dogs:
		if dog.hp <= 0:
			continue
		var ai: TacticsAI = dog.get_node_or_null("TacticsAI") as TacticsAI
		if ai:
			await ai.take_turn(dog, self)

	# Squealer propaganda: reduce Snowball's move range each round
	if _squealer.hp > 0 and _squealer.visible:
		_snowball.move_range = maxi(1, _snowball.move_range - 1)
		_turn_label.text = "Squealer spreads lies! Snowball feels confused..."
		await get_tree().create_timer(0.8).timeout

	# Clear Snowball's defence bonus from Windmill Plans
	_snowball.defense_bonus = 0

# =============================================================================
# Private methods — grid shrink
# =============================================================================

func _shrink_grid() -> void:
	_grid_cols -= 1
	_turn_label.text = "Napoleon's grip tightens — a column of the farm is LOST!"
	queue_redraw()
	await get_tree().create_timer(0.6).timeout

	_reposition_all_units()

	if _snowball.grid_pos.x >= _grid_cols:
		await get_tree().create_timer(0.5).timeout
		_turn_label.text = "Snowball is pushed off the farm!"
		# Hide Snowball BEFORE the next await so the post-shrink visibility
		# check in _on_action_selected (`not _snowball.visible`) fires correctly
		# and stops progression to _next_round() before the scene changes.
		_snowball.visible = false
		await get_tree().create_timer(0.8).timeout
		_trigger_game_over()
		return

	var all_enemies: Array[UnitBase] = []
	for dog: UnitBase in _dogs:
		all_enemies.append(dog)
	all_enemies.append(_squealer)

	for unit: UnitBase in all_enemies:
		if unit.hp > 0 and unit.grid_pos.x >= _grid_cols:
			_unit_positions.erase(unit.grid_pos)
			unit.hp = 0
			unit.visible = false


func _reposition_all_units() -> void:
	var all_units: Array[UnitBase] = [_snowball]
	for dog: UnitBase in _dogs:
		all_units.append(dog)
	all_units.append(_squealer)
	for unit: UnitBase in all_units:
		if unit.visible and unit.hp > 0:
			_apply_visual_position(unit)

# =============================================================================
# Private methods — game over
# =============================================================================

func _update_hp_label() -> void:
	_hp_label.text = "Snowball HP: %d/%d" % [_snowball.hp, _snowball.max_hp]


func _trigger_game_over() -> void:
	game_over.emit()
	GameState.snowball_expelled = true
	GameState.complete_act(4)
	_game_over_panel.show()
	await get_tree().create_timer(2.5).timeout
	SceneManager.go_to_scene("res://scenes/act4/commandments_corruption.tscn")
