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
# Signals
# =============================================================================

signal turn_ended
signal game_over

# =============================================================================
# Private variables
# =============================================================================

var _grid_cols: int = INITIAL_COLS
var _turn_number: int = 0
var _player_turn: bool = true
var _phase: String = "move"
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

@onready var _turn_label: Label              = %TurnLabel
@onready var _hp_label: Label                = %SnowballHPLabel
@onready var _action_panel: PanelContainer   = %ActionPanel
@onready var _feedback_label: Label          = %FeedbackLabel
@onready var _game_over_panel: PanelContainer = %GameOverPanel
@onready var _battle_cry_btn: Button         = %BattleCryBtn
@onready var _windmill_btn: Button           = %WindmillBtn
@onready var _wait_btn: Button               = %WaitBtn

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_connect_buttons()
	_setup_units()
	_draw_grid_state()
	_start_player_turn()


func _draw() -> void:
	_draw_shrunk_area()
	_draw_active_cells()
	_draw_valid_move_highlights()


func _input(event: InputEvent) -> void:
	if not _player_turn:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_handle_click(get_local_mouse_position())

# =============================================================================
# Public methods
# =============================================================================

func get_grid_offset_x() -> int:
	return 80 + (INITIAL_COLS - _grid_cols) * CELL_SIZE

# =============================================================================
# Private methods — setup
# =============================================================================

func _connect_buttons() -> void:
	_battle_cry_btn.pressed.connect(_on_action_battle_cry)
	_windmill_btn.pressed.connect(_on_action_windmill)
	_wait_btn.pressed.connect(_on_action_wait)


func _setup_units() -> void:
	_snowball = %Snowball as UnitBase
	_squealer = %Squealer as UnitBase

	var dog1: UnitBase = %Dog1 as UnitBase
	var dog2: UnitBase = %Dog2 as UnitBase
	_dogs = [dog1, dog2]

	# Place Snowball on the right side
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
	unit.position = Vector2(
		float(offset_x + unit.grid_pos.x * CELL_SIZE + CELL_SIZE / 2),
		float(80 + unit.grid_pos.y * CELL_SIZE + CELL_SIZE / 2)
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
# Private methods — turn flow
# =============================================================================

func _start_player_turn() -> void:
	_player_turn = true
	_phase = "move"
	_action_panel.hide()
	_turn_label.text = "Turn %d — SNOWBALL'S MOVE" % (_turn_number + 1)
	_valid_moves = _compute_valid_moves(_snowball)
	queue_redraw()


func _handle_click(click_pos: Vector2) -> void:
	var offset_x: int = get_grid_offset_x()
	var col: int = int((click_pos.x - float(offset_x)) / float(CELL_SIZE))
	var row: int = int((click_pos.y - 80.0) / float(CELL_SIZE))
	var clicked_cell: Vector2i = Vector2i(col, row)

	if _phase == "move" and clicked_cell in _valid_moves:
		_move_unit(_snowball, clicked_cell)
		_phase = "action"
		_feedback_label.text = ""
		_action_panel.show()

# =============================================================================
# Private methods — player actions
# =============================================================================

func _on_action_battle_cry() -> void:
	# Push the nearest adjacent dog back 1 square in the direction away from Snowball
	for dog: UnitBase in _dogs:
		if dog.hp <= 0:
			continue
		if _manhattan(dog.grid_pos, _snowball.grid_pos) == 1:
			var push_dir: Vector2i = dog.grid_pos - _snowball.grid_pos
			var new_pos: Vector2i = dog.grid_pos + push_dir
			if _is_valid_cell(new_pos) and not _unit_positions.has(new_pos):
				_move_unit(dog, new_pos)
			_feedback_label.text = "Snowball cries out — the dog recoils!"
			break
	_end_player_turn()


func _on_action_windmill() -> void:
	_snowball.defense_bonus = 2
	_feedback_label.text = "Snowball shows his Windmill blueprints... (+2 Defence next turn)"
	_end_player_turn()


func _on_action_wait() -> void:
	_end_player_turn()


func _end_player_turn() -> void:
	_action_panel.hide()
	_player_turn = false
	_valid_moves.clear()
	queue_redraw()
	await get_tree().create_timer(0.5).timeout
	_run_enemy_turn()

# =============================================================================
# Private methods — enemy AI
# =============================================================================

func _run_enemy_turn() -> void:
	# Move each living dog toward Snowball, then attack if adjacent
	for dog: UnitBase in _dogs:
		if dog.hp <= 0:
			continue
		await _move_dog_toward_snowball(dog)
		await get_tree().create_timer(0.3).timeout
		_try_dog_attack(dog)

	# Squealer propaganda: temporarily removes 1 move from Snowball (min 1)
	if _squealer.hp > 0 and _squealer.visible:
		_snowball.move_range = maxi(1, _snowball.move_range - 1)
		_turn_label.text = "Squealer spreads lies! Snowball feels confused..."
		await get_tree().create_timer(0.8).timeout

	# Clear Snowball's defence bonus from Windmill Plans
	_snowball.defense_bonus = 0

	_update_hp_label()

	# Check death from HP
	if _snowball.hp <= 0:
		await get_tree().create_timer(0.8).timeout
		_trigger_game_over()
		return

	# Advance turn counter then check grid shrink
	_turn_number += 1
	if _turn_number % 3 == 0:
		await _shrink_grid()
		# _shrink_grid may trigger game over internally; check after
		if _snowball.hp <= 0 or not _snowball.visible:
			return

	_start_player_turn()


func _move_dog_toward_snowball(dog: UnitBase) -> void:
	var dir: Vector2i = _snowball.grid_pos - dog.grid_pos
	# Move along the axis with greater distance (x preferred on ties)
	var step: Vector2i
	if abs(dir.x) >= abs(dir.y):
		step = Vector2i(sign(dir.x), 0)
	else:
		step = Vector2i(0, sign(dir.y))
	var target: Vector2i = dog.grid_pos + step
	if _is_valid_cell(target) and not _unit_positions.has(target):
		_move_unit(dog, target)


func _try_dog_attack(dog: UnitBase) -> void:
	if _manhattan(dog.grid_pos, _snowball.grid_pos) != 1:
		return
	var dmg: int = maxi(1, dog.attack - _snowball.defense_bonus)
	_snowball.hp -= dmg
	_snowball.hp = maxi(0, _snowball.hp)
	_turn_label.text = "A dog attacks Snowball! (-%d HP)" % dmg


func _shrink_grid() -> void:
	_grid_cols -= 1
	_turn_label.text = "Napoleon's grip tightens — a column of the farm is LOST!"
	queue_redraw()
	await get_tree().create_timer(0.6).timeout

	# Re-position all visible units to account for the new grid offset
	_reposition_all_units()

	# Check if Snowball is now off the grid (expelled)
	if _snowball.grid_pos.x >= _grid_cols:
		await get_tree().create_timer(0.5).timeout
		_turn_label.text = "Snowball is pushed off the farm!"
		await get_tree().create_timer(0.8).timeout
		_trigger_game_over()
		return

	# Remove any enemy units pushed off-grid
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
	# Brief pause before transitioning to the corruption scene
	await get_tree().create_timer(2.5).timeout
	SceneManager.go_to_scene("res://scenes/act4/commandments_corruption.tscn")
