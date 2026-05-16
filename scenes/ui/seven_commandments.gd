class_name SevenCommandments
extends CanvasLayer

# =============================================================================
# Constants
# =============================================================================

const COMMANDMENT_TEXTS: Array[String] = [
	"1. Whatever goes upon two legs is an enemy.",
	"2. Whatever goes upon four legs, or has wings, is a friend.",
	"3. No animal shall wear clothes.",
	"4. No animal shall sleep in a bed.",
	"5. No animal shall drink alcohol.",
	"6. No animal shall kill any other animal.",
	"7. All animals are equal.",
]

const COLOR_INTACT: Color    = Color(0.941, 0.910, 0.788, 1.0)
const COLOR_CORRUPTED: Color = Color(0.5, 0.0, 0.0, 1.0)

# =============================================================================
# @onready variables
# =============================================================================

@onready var commandment_labels: Array[Label] = []

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_build_label_references()
	_refresh_display()
	GameState.commandment_corrupted.connect(_on_commandment_corrupted)


func _exit_tree() -> void:
	if GameState.commandment_corrupted.is_connected(_on_commandment_corrupted):
		GameState.commandment_corrupted.disconnect(_on_commandment_corrupted)

# =============================================================================
# Private methods
# =============================================================================

func _build_label_references() -> void:
	# Collect the seven Label children from the CommandmentList VBoxContainer.
	var list: Node = $Panel/CommandmentList
	for i: int in range(COMMANDMENT_TEXTS.size()):
		var label: Label = list.get_node("Commandment%d" % (i + 1)) as Label
		if label == null:
			push_error("SevenCommandments: missing Label node 'Commandment%d'" % (i + 1))
			continue
		commandment_labels.append(label)


func _refresh_display() -> void:
	# Use the per-index array rather than a count so the correct commandments are
	# highlighted after a save/load round-trip (the old count-based check assumed
	# the first N were always corrupted, which was wrong when a later commandment
	# was corrupted before earlier ones).
	for i: int in range(commandment_labels.size()):
		_apply_commandment_style(i, GameState.corrupted_commandment_indices.has(i))


func _apply_commandment_style(index: int, corrupted: bool) -> void:
	if index >= commandment_labels.size():
		return
	var label: Label = commandment_labels[index]
	if corrupted:
		label.modulate = COLOR_CORRUPTED
		# Visual strikethrough via a combining-strikethrough prefix string.
		# Godot 4 Label does not expose a built-in strikethrough property without
		# RichTextLabel, so we indicate corruption with a leading cross marker
		# and the dark-red modulate that reads clearly on the barn-wall backdrop.
		if not label.text.begins_with("[X] "):
			label.text = "[X] " + COMMANDMENT_TEXTS[index]
	else:
		label.modulate = COLOR_INTACT
		label.text = COMMANDMENT_TEXTS[index]

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_commandment_corrupted(index: int) -> void:
	# The signal passes which commandment was just corrupted.
	# GameState.commandments_corrupted has already been incremented before emit.
	_apply_commandment_style(index, true)
