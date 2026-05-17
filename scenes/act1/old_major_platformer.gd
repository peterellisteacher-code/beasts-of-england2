## Act 1 coordinator. The night walk: Old Major carries his lantern across
## Manor Farm at night with Moses circling overhead. On reaching the barn
## door, the camera locks, player input freezes, and Moses lands to deliver
## a 3-from-8 question quiz before the act-2 transition.
class_name OldMajorPlatformer
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const GROUP_SCENE_COORDINATOR: StringName = &"act1_coordinator"
const MOSES_QUIZ_SCENE: PackedScene = preload("res://scenes/act1/objects/moses_quiz.tscn")

# =============================================================================
# Signals
# =============================================================================

@warning_ignore("unused_signal")
signal key_count_changed(new_count: int)

# =============================================================================
# Private variables
# =============================================================================

var _quiz_triggered: bool = false

# =============================================================================
# Public variables — coordinator state
# =============================================================================

## Number of keys the player has picked up this level. Read by Door nodes.
var keys_collected: int = 0

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(GROUP_SCENE_COORDINATOR)
	if GameState.hearts <= 0:
		GameState.hearts = 3
	_schedule_owl_hoot()


func _schedule_owl_hoot() -> void:
	var wait: float = randf_range(15.0, 30.0)
	await get_tree().create_timer(wait).timeout
	var owl: AudioStreamPlayer = get_node_or_null("OwlHoot")
	if owl and owl.stream:
		owl.play()
	_schedule_owl_hoot()

# =============================================================================
# Public methods — coordinator API (called by Old Major)
# =============================================================================

func on_key_collected() -> void:
	keys_collected += 1
	key_count_changed.emit(keys_collected)


func on_door_unlocked() -> void:
	pass


func on_lamb_rescued() -> void:
	pass


func on_player_died() -> void:
	# No-fail walk: damage is a no-op.
	pass

# =============================================================================
# Barn-door signal handler
# =============================================================================

## Connected to BarnDoor.body_entered. Spawns the Moses quiz on first valid
## entry; subsequent triggers are ignored.
func on_barn_reached(body: Node2D) -> void:
	if _quiz_triggered:
		return
	# Use group membership so the check is robust regardless of class_name
	# resolution order at runtime (class_name lookup can silently miss if the
	# script hasn't fully registered when body_entered fires).
	if not body.is_in_group(&"player"):
		return
	_spawn_moses_quiz(body)


func _spawn_moses_quiz(player: Node2D) -> void:
	player.can_move = false

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MosesQuizLayer"
	layer.layer = 10
	add_child(layer)

	var quiz: Control = MOSES_QUIZ_SCENE.instantiate()
	quiz.quiz_passed.connect(_on_quiz_passed)
	layer.add_child(quiz)
	# Set the flag AFTER successful spawn so a spawn failure doesn't
	# permanently lock the player out of the quiz trigger.
	_quiz_triggered = true


func _on_quiz_passed() -> void:
	GameState.corrupt_commandment(0)
	GameState.complete_act(1)
	# Use go_to_act so SceneManager also updates current_act consistently.
	SceneManager.go_to_act(2)
