## Persistent on-screen controls reminder. Sits in the corner during gameplay
## and can be toggled with the H key. Each act sets `controls` to the lines
## relevant to its mechanic.
class_name ControlsHUD
extends CanvasLayer

# =============================================================================
# Exported configuration
# =============================================================================

@export var controls: Array[String] = [
	"WASD / Arrows: Move",
	"E: Interact",
	"H: Hide controls",
]

# =============================================================================
# @onready references
# =============================================================================

@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/Margin/ControlsList

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# Keep the HUD responsive even when the scene tree is paused (e.g. while
	# the act intro is up). Players still see the controls reminder.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		_panel.visible = not _panel.visible

# =============================================================================
# Public methods
# =============================================================================

func set_controls(lines: Array[String]) -> void:
	controls = lines
	if is_inside_tree():
		_rebuild()

# =============================================================================
# Private methods
# =============================================================================

func _rebuild() -> void:
	for child: Node in _list.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "CONTROLS  (H to hide)"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.545, 0.102, 0.102, 1))
	_list.add_child(header)

	for line: String in controls:
		var label: Label = Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.941, 0.910, 0.788, 1))
		_list.add_child(label)
