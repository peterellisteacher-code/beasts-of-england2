## Woven question panel — a small in-world MCQ card that appears when Old Major
## rouses a sleeping animal. Does NOT go full-screen; the game world stays
## visible behind a light dim. 3 shuffled buttons (1 correct + 2 wrong).
##
## Retry logic: wrong → show hint, disable that button, let player retry.
## After 2 wrong answers the correct option is highlighted and the panel
## auto-proceeds after a short pause. Progress is never blocked.
##
## Spec: active.md §4 "ui/woven_question.gd".
class_name WovenQuestion
extends Control

# =============================================================================
# Constants
# =============================================================================

const FONT_SIZE_QUESTION: int = 20
const FONT_SIZE_BUTTON: int = 18
const FONT_SIZE_HINT: int = 17

## After 2 wrong answers, highlight correct and wait this long before auto-close.
const AUTO_CLOSE_DELAY: float = 1.8

## Colours — propaganda palette.
const COL_CORRECT: Color = Color(0.2, 0.72, 0.2)
const COL_WRONG: Color   = Color(0.85, 0.25, 0.25)
const COL_HINT: Color    = Color(0.769, 0.639, 0.290)

# =============================================================================
# Signals
# =============================================================================

## Emitted when the question is resolved (correct answer chosen or auto-revealed).
## was_correct = false when the correct answer was auto-revealed.
signal answered(was_correct: bool)

# =============================================================================
# Private state
# =============================================================================

var _correct_text: String = ""
var _wrong_count: int = 0
## Which button indices map to which text (after shuffle).
var _button_texts: Array[String] = []
## Buttons that have been eliminated (disabled wrong answers).
var _eliminated: Array[int] = []

# =============================================================================
# @onready references
# =============================================================================

@onready var _bg: ColorRect               = $BG
@onready var _speaker_label: Label        = $Panel/VBox/SpeakerLabel
@onready var _question_label: Label       = $Panel/VBox/QuestionLabel
@onready var _hint_label: Label           = $Panel/VBox/HintLabel
@onready var _buttons_container: HBoxContainer = $Panel/VBox/Buttons
@onready var _btn_a: Button               = $Panel/VBox/Buttons/BtnA
@onready var _btn_b: Button               = $Panel/VBox/Buttons/BtnB
@onready var _btn_c: Button               = $Panel/VBox/Buttons/BtnC

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# This panel runs while tree is paused (coordinator pauses tree during questions).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hint_label.text = ""
	_btn_a.pressed.connect(func() -> void: _on_button(0))
	_btn_b.pressed.connect(func() -> void: _on_button(1))
	_btn_c.pressed.connect(func() -> void: _on_button(2))

# =============================================================================
# Public API
# =============================================================================

## Populate the panel with question data from Act1Questions.QUESTIONS.
## qdata must have keys: q, correct, wrong (Array of 2 Strings), hint, speaker.
func setup(qdata: Dictionary) -> void:
	_correct_text = qdata["correct"] as String
	_wrong_count = 0
	_eliminated.clear()

	_speaker_label.text = (qdata["speaker"] as String).to_upper()
	_question_label.text = qdata["q"] as String
	_hint_label.text = ""
	_hint_label.modulate = COL_HINT

	# Build and shuffle 3 options: 1 correct + 2 wrong.
	var options: Array[String] = [_correct_text]
	for w: String in (qdata["wrong"] as Array):
		options.append(w as String)
	options.shuffle()

	_button_texts.clear()
	var btns: Array[Button] = [_btn_a, _btn_b, _btn_c]
	for i: int in range(3):
		_button_texts.append(options[i])
		btns[i].text = options[i]
		btns[i].disabled = false
		btns[i].modulate = Color.WHITE
		btns[i].add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)

	# Store hint text for later display.
	_hint_label.add_theme_font_size_override("font_size", FONT_SIZE_HINT)
	set_meta("_hint_text", qdata["hint"] as String)
	_question_label.add_theme_font_size_override("font_size", FONT_SIZE_QUESTION)

# =============================================================================
# Private methods
# =============================================================================

func _on_button(index: int) -> void:
	var chosen: String = _button_texts[index]
	if chosen == _correct_text:
		_resolve(true, index)
	else:
		_wrong_count += 1
		# Visually mark this button wrong and disable it.
		var btns: Array[Button] = [_btn_a, _btn_b, _btn_c]
		btns[index].modulate = COL_WRONG
		btns[index].disabled = true
		_eliminated.append(index)

		if _wrong_count >= 2:
			# Reveal the correct answer.
			_hint_label.text = "The answer is: " + _correct_text
			_hint_label.modulate = COL_CORRECT
			# Highlight the correct button.
			for i: int in range(3):
				if _button_texts[i] == _correct_text:
					btns[i].modulate = COL_CORRECT
					break
			# Disable all and auto-close after delay.
			for btn: Button in btns:
				btn.disabled = true
			await get_tree().create_timer(AUTO_CLOSE_DELAY, true).timeout
			if not is_instance_valid(self):
				return
			answered.emit(false)
		else:
			# Show hint, remove one wrong option (already eliminated above).
			_hint_label.text = get_meta("_hint_text", "") as String


func _resolve(was_correct: bool, correct_index: int) -> void:
	var btns: Array[Button] = [_btn_a, _btn_b, _btn_c]
	btns[correct_index].modulate = COL_CORRECT
	for btn: Button in btns:
		btn.disabled = true
	await get_tree().create_timer(0.9, true).timeout
	if not is_instance_valid(self):
		return
	answered.emit(was_correct)
