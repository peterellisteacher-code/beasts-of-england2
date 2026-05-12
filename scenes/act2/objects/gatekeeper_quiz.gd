class_name GatekeeperQuiz
extends Control

# =============================================================================
# Constants — verbatim Animal Farm quotes as quiz questions
# =============================================================================

const QUESTIONS: Array[Dictionary] = [
	{
		"quote": "\"Four legs good, two legs bad.\"",
		"speaker": "The sheep chant this slogan. Who first taught them?",
		"options": ["Mr Jones", "Napoleon", "Snowball", "Old Major"],
		"correct": 2,
		"hint": "The same pig who organised the defence committees."
	},
	{
		"quote": "\"I will work harder.\"",
		"speaker": "Which animal's personal motto is this?",
		"options": ["Snowball", "Boxer", "Napoleon", "Squealer"],
		"correct": 1,
	},
	{
		"quote": "\"Comrades, you have heard already about the strange dream that I had last night.\"",
		"speaker": "Who speaks these words, and when?",
		"options": [
			"Napoleon in Chapter 2",
			"Old Major in Chapter 1",
			"Snowball in Chapter 3",
			"Squealer in Chapter 5"
		],
		"correct": 1,
	},
]

# Special scroll question — only shown when GameState.has_secret_scroll == true
const SECRET_QUESTION: Dictionary = {
	"quote": "\"Man is the only real enemy we have.\"",
	"speaker": "Where did you find this torn piece of parchment?",
	"options": [
		"In the barn loft — Old Major hid it there",
		"Under the hay in the pig pen — his private notes",
		"Inside the farmhouse — stolen from Mr Jones",
		"I do not know"
	],
	"correct": 1,
	"secret_answer": true,
}

# =============================================================================
# Signals
# =============================================================================

signal quiz_passed
@warning_ignore("unused_signal")
signal quiz_failed

# =============================================================================
# Private variables
# =============================================================================

var _current_question: int = 0
var _questions_to_ask: Array[Dictionary] = []

# =============================================================================
# Onready references
# =============================================================================

@onready var quote_label: RichTextLabel = $Panel/VBox/QuoteLabel
@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var options_container: VBoxContainer = $Panel/VBox/Options
@onready var feedback_label: Label = $Panel/VBox/FeedbackLabel

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	_questions_to_ask = QUESTIONS.duplicate()
	if GameState.has_secret_scroll:
		_questions_to_ask.insert(1, SECRET_QUESTION)

	# Wire option buttons — children of Options VBoxContainer
	for i: int in range(4):
		var btn: Button = options_container.get_child(i) as Button
		if btn == null:
			push_error("GatekeeperQuiz: Options child %d is not a Button" % i)
			continue
		var captured_index: int = i
		btn.pressed.connect(func() -> void: _on_option_selected(captured_index))

# =============================================================================
# Public methods
# =============================================================================

func start_quiz() -> void:
	_current_question = 0
	_show_question(0)

# =============================================================================
# Private methods
# =============================================================================

func _show_question(index: int) -> void:
	if index >= _questions_to_ask.size():
		quiz_passed.emit()
		get_parent().on_gatekeeper_passed()
		return

	var q: Dictionary = _questions_to_ask[index]
	quote_label.text = q["quote"] as String
	speaker_label.text = q["speaker"] as String
	feedback_label.text = ""

	var options: Array = q["options"] as Array
	for i: int in range(4):
		var btn: Button = options_container.get_child(i) as Button
		if btn == null:
			continue
		btn.text = options[i] as String
		btn.disabled = false
		btn.modulate = Color(1.0, 1.0, 1.0)


func _on_option_selected(option_index: int) -> void:
	var q: Dictionary = _questions_to_ask[_current_question]

	# Lock all buttons while processing answer
	for i: int in range(4):
		var btn: Button = options_container.get_child(i) as Button
		if btn != null:
			btn.disabled = true

	var correct_index: int = q["correct"] as int
	var selected_btn: Button = options_container.get_child(option_index) as Button

	if option_index == correct_index:
		if selected_btn != null:
			selected_btn.modulate = Color(0.2, 0.8, 0.2)

		if q.get("secret_answer", false):
			GameState.has_gatekeeper_bonus = true
			feedback_label.text = "The gatekeeper nods slowly. 'You've read the old boar's private words...'"
		else:
			feedback_label.text = "Correct! The gates swing open."

		await get_tree().create_timer(1.5).timeout
		if not is_instance_valid(self):
			return
		_current_question += 1
		_show_question(_current_question)
	else:
		if selected_btn != null:
			selected_btn.modulate = Color(0.8, 0.2, 0.2)
		feedback_label.text = "Wrong. The dogs growl. Try again..."

		await get_tree().create_timer(1.5).timeout
		if not is_instance_valid(self):
			return
		# Reset colours and re-enable buttons for retry
		for i: int in range(4):
			var btn: Button = options_container.get_child(i) as Button
			if btn != null:
				btn.modulate = Color(1.0, 1.0, 1.0)
				btn.disabled = false
