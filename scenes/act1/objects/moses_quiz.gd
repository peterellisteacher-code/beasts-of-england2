## Moses-the-raven quiz card. Old Major reaches the barn door at the end of his
## night walk; Moses lands on the rail and asks 3 questions drawn at random from
## a pool of 8. Any wrong answer → reroll a fresh 3 from the pool, no other
## penalty. All 3 correct → emit `quiz_passed`, caller transitions to Act 2.
##
## Pattern cloned from scenes/act2/objects/gatekeeper_quiz.gd.
class_name MosesQuiz
extends Control

# =============================================================================
# Constants — verbatim Animal Farm chapter-1 questions
# =============================================================================

const QUESTIONS: Array[Dictionary] = [
	{
		"q": "On page 8, which two characters was it said that Mr. Jones was \"breeding up for sale\"?",
		"a": "Napoleon and Snowball",
		"wrong": ["Squealer and Pinkeye", "Boxer and Clover", "Bluebell and Pincher"],
	},
	{
		"q": "On page 18, what is it said that Muriel can do better than the dogs?",
		"a": "Reading",
		"wrong": ["Counting", "Walking on hind legs", "Singing"],
	},
	{
		"q": "On page 28, what is said to be the second book that Snowball read?",
		"a": "Every Man His Own Bricklayer",
		"wrong": ["The Aeneid", "Animal Husbandry Quarterly", "Wheat for Wonder Crops"],
	},
	{
		"q": "On page 31, what does Boxer shake several times?",
		"a": "His forelock",
		"wrong": ["His mane", "His hoof", "His tail"],
	},
	{
		"q": "On page 12, what did the animals decide the farmhouse should be turned into?",
		"a": "A museum",
		"wrong": ["A granary", "A barn", "A council chamber"],
	},
	{
		"q": "On page 21, what is the name of the owner of Foxwood?",
		"a": "Mr. Pilkington",
		"wrong": ["Mr. Frederick", "Mr. Whymper", "Mr. Jones"],
	},
	{
		"q": "On page 24, what is the name given to the best medal an animal can receive?",
		"a": "Animal Hero, First Class",
		"wrong": ["Animal Hero, Second Class", "Hero of Animalism", "Order of the Green Banner"],
	},
	{
		"q": "On page 17 it is said that the hoof and horn signify the future what?",
		"a": "Republic of the Animals",
		"wrong": ["Reign of Animalism", "Glory of the Revolution", "Kingdom of Manor Farm"],
	},
]

const QUESTIONS_PER_RUN: int = 3

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
var _run: Array[Dictionary] = []

# =============================================================================
# Onready references
# =============================================================================

@onready var _question_label: RichTextLabel = $Panel/VBox/QuestionLabel
@onready var _progress_label: Label = $Panel/VBox/ProgressLabel
@onready var _options: VBoxContainer = $Panel/VBox/Options
@onready var _feedback_label: Label = $Panel/VBox/FeedbackLabel

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	for i: int in range(4):
		var btn: Button = _options.get_child(i) as Button
		if btn == null:
			push_error("MosesQuiz: option child %d is not a Button" % i)
			continue
		var captured_index: int = i
		btn.pressed.connect(func() -> void: _on_option_selected(captured_index))

	_reroll_run()
	_show_question(0)

# =============================================================================
# Private methods
# =============================================================================

func _reroll_run() -> void:
	# Pick QUESTIONS_PER_RUN unique questions at random from the pool.
	var pool: Array[Dictionary] = QUESTIONS.duplicate()
	pool.shuffle()
	_run.clear()
	for i: int in range(QUESTIONS_PER_RUN):
		_run.append(pool[i])
	_current_question = 0


func _show_question(index: int) -> void:
	if index >= _run.size():
		quiz_passed.emit()
		return

	var q: Dictionary = _run[index]
	_question_label.text = q["q"] as String
	_progress_label.text = "Question %d of %d" % [index + 1, QUESTIONS_PER_RUN]
	_feedback_label.text = ""

	# Build the 4 options: 1 correct + 3 distractors, shuffled
	var correct_text: String = q["a"] as String
	var wrongs: Array = q["wrong"] as Array
	var labels: Array[String] = [correct_text]
	for w: String in wrongs:
		labels.append(w)
	labels.shuffle()

	for i: int in range(4):
		var btn: Button = _options.get_child(i) as Button
		if btn == null:
			continue
		btn.text = labels[i]
		btn.set_meta("is_correct", labels[i] == correct_text)
		btn.disabled = false
		btn.modulate = Color(1.0, 1.0, 1.0)


func _on_option_selected(option_index: int) -> void:
	for i: int in range(4):
		var btn: Button = _options.get_child(i) as Button
		if btn != null:
			btn.disabled = true

	var selected_btn: Button = _options.get_child(option_index) as Button
	var is_correct: bool = selected_btn != null and selected_btn.get_meta("is_correct", false) as bool

	if is_correct:
		selected_btn.modulate = Color(0.2, 0.8, 0.2)
		_feedback_label.text = "Correct. Moses tilts his head and waits…"
		await get_tree().create_timer(1.1).timeout
		if not is_instance_valid(self):
			return
		_current_question += 1
		_show_question(_current_question)
	else:
		if selected_btn != null:
			selected_btn.modulate = Color(0.85, 0.25, 0.25)
		_feedback_label.text = "\"No, no,\" rasps Moses. \"Try again with three fresh questions.\""
		await get_tree().create_timer(1.4).timeout
		if not is_instance_valid(self):
			return
		_reroll_run()
		_show_question(0)
