class_name CommandmentsCorruption
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const ORIGINAL_COMMANDMENTS: Array[String] = [
	"Whatever goes upon two legs is an enemy.",
	"Whatever goes upon four legs, or has wings, is a friend.",
	"No animal shall wear clothes.",
	"No animal shall sleep in a bed.",
	"No animal shall drink alcohol.",
	"No animal shall kill any other animal.",
	"All animals are equal.",
]

const CORRUPTED_COMMANDMENTS: Array[String] = [
	"[DELETED]",
	"[DELETED]",
	"No animal shall wear clothes WITHOUT GOOD REASON.",
	"No animal shall sleep in a bed WITH SHEETS.",
	"No animal shall drink alcohol TO EXCESS.",
	"No animal shall kill any other animal WITHOUT CAUSE.",
	"All animals are equal, BUT SOME ANIMALS ARE MORE EQUAL THAN OTHERS.",
]

const COLOR_ORIGINAL: Color   = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_DELETED: Color    = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_ALTERED: Color    = Color(0.9, 0.7, 0.2, 1.0)
const COLOR_REDACTED: String  = "████████████████████"

const REVEAL_DELAY_SEC: float = 0.7
const FADE_DURATION_SEC: float = 0.5

# =============================================================================
# @onready variables
# =============================================================================

@onready var _list: VBoxContainer = %CommandmentsList
@onready var _continue_btn: Button = %ContinueButton

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_continue_btn.hide()
	_continue_btn.pressed.connect(_on_continue)
	_build_display()

# =============================================================================
# Private methods
# =============================================================================

func _build_display() -> void:
	for i: int in range(ORIGINAL_COMMANDMENTS.size()):
		var row: HBoxContainer = _make_commandment_row(i)
		_list.add_child(row)

		# Fade in with a staggered delay
		row.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tween: Tween = create_tween()
		tween.tween_property(row, "modulate:a", 1.0, FADE_DURATION_SEC)

		await get_tree().create_timer(REVEAL_DELAY_SEC).timeout

	await get_tree().create_timer(1.5).timeout
	_continue_btn.show()


func _make_commandment_row(index: int) -> HBoxContainer:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Original text (greyed out)
	var original_label: Label = Label.new()
	original_label.text = ORIGINAL_COMMANDMENTS[index]
	original_label.modulate = COLOR_ORIGINAL
	original_label.custom_minimum_size = Vector2(440.0, 0.0)
	original_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(original_label)

	# Arrow separator
	var arrow: Label = Label.new()
	arrow.text = "  →  "
	arrow.modulate = Color(0.6, 0.6, 0.6, 1.0)
	hbox.add_child(arrow)

	# Corrupted version
	var corrupted_label: Label = Label.new()
	corrupted_label.custom_minimum_size = Vector2(500.0, 0.0)
	corrupted_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var corrupted_text: String = CORRUPTED_COMMANDMENTS[index]
	if corrupted_text == "[DELETED]":
		corrupted_label.text = COLOR_REDACTED
		corrupted_label.modulate = COLOR_DELETED
	else:
		corrupted_label.text = corrupted_text
		corrupted_label.modulate = COLOR_ALTERED

	hbox.add_child(corrupted_label)
	return hbox

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_continue() -> void:
	SceneManager.go_to_scene("res://scenes/act5/napoleon_interrogation.tscn")
