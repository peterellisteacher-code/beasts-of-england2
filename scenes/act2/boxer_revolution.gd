## Ported from Lango-Zelda-RPG Levels/Levels.gd
class_name BoxerRevolution
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const JONES_MEN_NEEDED: int = 5
const MAX_REGROUPED: int = 3

# =============================================================================
# Private variables
# =============================================================================

var _jones_men_regrouped: int = 0
# FIX: one-shot guard so simultaneous driven-off events cannot re-trigger the
# gatekeeper quiz or fire the loss scene while the quiz / reveal is active.
var _gatekeeper_triggered: bool = false
var _act_locked: bool = false  # true once gatekeeper fires; blocks loss trigger

# =============================================================================
# Onready references
# =============================================================================

@onready var boxer_player: CharacterBody2D = $BoxerPlayer
@onready var gatekeeper_quiz: Control = $GatekeeperQuiz
@onready var commandments_reveal: Control = $CommandmentsReveal

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# FIX: reset the persistent counter so retries start clean.
	GameState.jones_men_driven = 0
	gatekeeper_quiz.hide()
	commandments_reveal.hide()

# =============================================================================
# Public methods — called by child nodes
# =============================================================================

func on_jones_man_driven_off() -> void:
	# FIX: ignore once gatekeeper is already active (prevents double-trigger from
	# simultaneous boundary crossings in the same physics frame).
	if _gatekeeper_triggered:
		return
	GameState.jones_men_driven += 1
	if GameState.jones_men_driven >= JONES_MEN_NEEDED:
		_trigger_gatekeeper()


func on_jones_man_regrouped() -> void:
	# FIX: ignore regrouped notifications once the quiz / reveal is active so
	# slow-reading students cannot be kicked back to the loss screen mid-quiz.
	if _act_locked:
		return
	_jones_men_regrouped += 1
	if _jones_men_regrouped >= MAX_REGROUPED:
		_trigger_loss()


func on_gatekeeper_passed() -> void:
	gatekeeper_quiz.hide()
	commandments_reveal.show()
	commandments_reveal.start_reveal()


func on_commandments_revealed() -> void:
	GameState.corrupt_commandment(1)
	GameState.complete_act(2)
	SceneManager.go_to_scene("res://scenes/act3/cowshed_overworld.tscn")

# =============================================================================
# Private methods
# =============================================================================

func _trigger_gatekeeper() -> void:
	_gatekeeper_triggered = true
	_act_locked = true
	boxer_player.can_move = false
	gatekeeper_quiz.show()
	gatekeeper_quiz.start_quiz()


func _trigger_loss() -> void:
	SceneManager.go_to_scene("res://scenes/act2/revolution_loss.tscn")
