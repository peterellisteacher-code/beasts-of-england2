class_name CommandmentsReveal
extends Control

# =============================================================================
# Constants
# =============================================================================

const COMMANDMENTS: Array[String] = [
	"1. Whatever goes upon two legs is an enemy.",
	"2. Whatever goes upon four legs, or has wings, is a friend.",
	"3. No animal shall wear clothes.",
	"4. No animal shall sleep in a bed.",
	"5. No animal shall drink alcohol.",
	"6. No animal shall kill any other animal.",
	"7. All animals are equal.",
]

const FADE_DURATION: float = 0.8
const STAGGER_DELAY: float = 0.6
const HOLD_AFTER_REVEAL: float = 2.0

# =============================================================================
# Signals
# =============================================================================

signal reveal_complete

# =============================================================================
# Onready references
# =============================================================================

@onready var vbox: VBoxContainer = $Panel/VBox

# =============================================================================
# Public methods
# =============================================================================

func start_reveal() -> void:
	for i: int in range(COMMANDMENTS.size()):
		var label: Label = Label.new()
		label.text = COMMANDMENTS[i]
		label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		vbox.add_child(label)

		var tween: Tween = create_tween()
		tween.tween_property(label, "modulate", Color(0.96, 0.94, 0.91, 1.0), FADE_DURATION)

		await get_tree().create_timer(STAGGER_DELAY).timeout
		if not is_instance_valid(self):
			return

	await get_tree().create_timer(HOLD_AFTER_REVEAL).timeout
	if not is_instance_valid(self):
		return
	# reveal_complete is connected by the scene controller — depth-independent.
	reveal_complete.emit()
