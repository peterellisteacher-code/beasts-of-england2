## Reusable act introduction overlay. Pauses gameplay until dismissed and
## tells the player which chapter they are in, who they are playing as, and
## how to control their character.
class_name ActIntro
extends CanvasLayer

# =============================================================================
# Signals
# =============================================================================

signal dismissed

# =============================================================================
# Exported configuration (set from each act's scene)
# =============================================================================

@export var act_label_text: String = "ACT 1 — CHAPTER 1"
@export var title_text: String = "OLD MAJOR'S DREAM"
@export var protagonist_text: String = "You are OLD MAJOR — the wise old boar."
@export_multiline var story_text: String = ""
@export_multiline var goal_text: String = ""
@export var controls: Array[String] = [
	"Move: WASD or Arrow Keys",
	"Jump: Space / Enter",
	"Interact: E",
]

# =============================================================================
# Private state
# =============================================================================

# Guard so a held key on the opening screen doesn't dismiss the next intro
# the instant it appears.
var _ready_to_dismiss: bool = false
var _dismissed: bool = false
# Track whether THIS node set the pause so _exit_tree can clean up if the node
# is removed by an external scene change before _dismiss() is called (which
# would otherwise leave the tree permanently paused — a hard softlock).
var _paused_by_intro: bool = false

# =============================================================================
# @onready references
# =============================================================================

@onready var _act_label: Label = $Panel/Margin/VBox/ActLabel
@onready var _title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var _protagonist_label: Label = $Panel/Margin/VBox/ProtagonistLabel
@onready var _story_label: Label = $Panel/Margin/VBox/StoryLabel
@onready var _goal_label: Label = $Panel/Margin/VBox/GoalLabel
@onready var _controls_list: VBoxContainer = $Panel/Margin/VBox/ControlsBox/ControlsList
@onready var _begin_button: Button = $Panel/Margin/VBox/BeginButton

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# Pause the rest of the scene tree while the intro is visible.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_paused_by_intro = true

	_apply_text()
	_apply_controls()
	_begin_button.pressed.connect(_on_begin_pressed)
	_begin_button.grab_focus()

	# Wait a frame so any key held over from the opening screen has time to
	# transition from "pressed" to "just-pressed" without instant-dismissing.
	await get_tree().process_frame
	_ready_to_dismiss = true


func _input(event: InputEvent) -> void:
	if not _ready_to_dismiss or _dismissed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_dismiss()
	elif event is InputEventMouseButton and event.pressed:
		# Let the Begin button handle its own click — but if the click landed
		# anywhere else, dismiss the intro.
		var button_rect: Rect2 = _begin_button.get_global_rect()
		if not button_rect.has_point(event.position):
			get_viewport().set_input_as_handled()
			_dismiss()

# =============================================================================
# Private methods
# =============================================================================

func _apply_text() -> void:
	_act_label.text = act_label_text
	_title_label.text = title_text
	_protagonist_label.text = protagonist_text
	_story_label.text = story_text
	_goal_label.text = "GOAL:  " + goal_text


func _apply_controls() -> void:
	# Wipe any placeholder children that came with the scene.
	for child: Node in _controls_list.get_children():
		child.queue_free()
	for line: String in controls:
		var label: Label = Label.new()
		label.text = "• " + line
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.961, 0.929, 0.808, 1))
		_controls_list.add_child(label)


func _on_begin_pressed() -> void:
	_dismiss()


func _exit_tree() -> void:
	# Safety net: if this node is removed from the tree by any means other than
	# _dismiss() (e.g. an external scene change), ensure the global pause is
	# cleared so the next scene is not permanently frozen.
	if _paused_by_intro:
		get_tree().paused = false
		_paused_by_intro = false


func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	if _paused_by_intro:
		get_tree().paused = false
		_paused_by_intro = false
	dismissed.emit()
	queue_free()
