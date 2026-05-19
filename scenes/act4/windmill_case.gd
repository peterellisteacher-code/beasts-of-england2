class_name WindmillCase
extends Node
## Act 4 — "The Windmill" case-file (Animal Farm, Chapter 6).
##
## A two-room point-and-click investigation that replaces the old
## politics_tactics level. The player investigates the wreck of the windmill,
## builds the two-page Casebook, proves the truth — and watches the
## proclamation painted over it.
##
## End-of-act contract (verified against the act flow):
##   snowball_expelled = true -> corrupt_commandment(3) -> complete_act(4)
##   -> the commandments-corruption screen -> Act 5 (Napoleon).

@onready var _case_ui: CaseFileUI = %CaseFileUI

func _ready() -> void:
	_case_ui.case_complete.connect(_on_case_complete)


# The Casebook is solved and the truth / Squealer / proclamation panels are done.
func _on_case_complete() -> void:
	GameState.snowball_expelled = true
	# Chapter 6 corrupts the Fourth Commandment ("No animal shall sleep in a
	# bed"). Index 3 is unclaimed by Acts 1-3.
	GameState.corrupt_commandment(3)
	GameState.complete_act(4)
	SceneManager.go_to_scene("res://scenes/act4/commandments_corruption.tscn")
