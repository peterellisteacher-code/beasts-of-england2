extends CanvasLayer

## Three-heart HUD for Act 1.
## Listens to GameState.hearts_changed signal and dims/restores hearts.

const FULL_COLOR  := Color(0.87, 0.07, 0.07, 1.0)   # propaganda red
const EMPTY_COLOR := Color(0.25, 0.05, 0.05, 0.45)

@onready var heart1: Label = $HBox/Heart1
@onready var heart2: Label = $HBox/Heart2
@onready var heart3: Label = $HBox/Heart3

var _hearts: Array[Label] = []

func _ready() -> void:
	_hearts = [heart1, heart2, heart3]
	GameState.hearts_changed.connect(update_hearts)
	update_hearts(GameState.hearts)

func update_hearts(new_count: int) -> void:
	for i in range(3):
		_hearts[i].modulate = FULL_COLOR if i < new_count else EMPTY_COLOR

func _exit_tree() -> void:
	if GameState.hearts_changed.is_connected(update_hearts):
		GameState.hearts_changed.disconnect(update_hearts)
