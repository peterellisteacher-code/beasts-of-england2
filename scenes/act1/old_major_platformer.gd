## Act 1 stealth coordinator. Old Major creeps from the stall to the barn,
## rousing 4 sleeping animals while evading Moses and static light pools.
## Wires signals, manages checkpoints, spawns question panels, runs the barn
## finale, and hands off to Act 2 via SceneManager.
##
## Spec: active.md §4 "old_major_platformer.gd".
class_name Act1Coordinator
extends Node2D

# =============================================================================
# Constants
# =============================================================================

const GROUP_COORDINATOR: StringName = &"act1_coordinator"
const GROUP_STEALTH_HUD: StringName = &"stealth_hud"

const WOVEN_QUESTION_SCENE: PackedScene = \
	preload("res://scenes/act1/ui/woven_question.tscn")

## Random caught-captions — picked at random by _on_player_caught.
const CAUGHT_CAPTIONS: Array[String] = [
	"Moses's harsh cry cuts the night. Slip back into the shadows, comrade.",
	"A light finds you. The farm stirs — try again, more quietly.",
	"Moses wheels overhead, cawing. You must not be seen reaching the barn.",
]

## Seconds before the tutorial hint shows after the ActIntro dismisses.
const TUTORIAL_HINT_DELAY: float = 6.0
const TUTORIAL_HINT_TEXT: String = \
	"Moses is circling. Wait in the shadow until he passes."

## Animal waking lines (each animal's own voice).
const ANIMAL_LINES: Dictionary = {
	&"hen":    "\"My eggs — taken again. Yes. I will come and hear him.\"",
	&"sheep":  "\"To the barn? If the others go, we go.\"",
	&"boxer":  "\"If old Major calls, I will be there. I will work harder for it.\"",
	&"clover": "\"Quietly now. Lead on, Major — I am with you.\"",
}

## Old Major's response after each animal wakes.
const OLD_MAJOR_LINES: Dictionary = {
	&"hen":    "\"Even your eggs are not your own while Man rules this farm.\"",
	&"sheep":  "\"They will teach you simple words, comrade. Take care whose words they are.\"",
	&"boxer":  "\"Strength like yours should not be spent for Man.\"",
	&"clover": "\"Soon, Clover, no foal of yours will be sold away. That is the dream.\"",
}

## Barn finale lines — Old Major's speech (Chapter 1 faithful).
const BARN_LINES: Array[String] = [
	"\"Comrades. My days are nearly over — but before I die, I will pass on what I have learned.\"",
	"\"Man is the only creature that consumes without producing. Man is our enemy. All animals are equal.\"",
	"\"Whatever goes upon two legs is an enemy. Whatever goes upon four legs, or has wings, is a friend. Remember it — and pass it on.\"",
]

const BARN_LINE_PAUSE: float = 3.2

# =============================================================================
# Public state
# =============================================================================

var comrades_roused: int = 0

# =============================================================================
# Private state
# =============================================================================

var _checkpoint: Vector2 = Vector2.ZERO
var _questions_done: int = 0
var _barn_triggered: bool = false

# =============================================================================
# @onready references
# =============================================================================

@onready var _player: OldMajor           = $World/OldMajor
@onready var _barn_door: Area2D          = $World/BarnDoor
@onready var _stealth_hud: StealthHUD    = $StealthHUD
@onready var _owl_hoot: AudioStreamPlayer = $OwlHoot
@onready var _moses: MosesRaven          = $World/MosesNest/Moses

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	add_to_group(GROUP_COORDINATOR)

	# Ensure no hearts dependency (stealth has no health).
	# GameState.hearts is not used in Act 1 stealth.

	# Store starting position as first checkpoint.
	_checkpoint = _player.global_position

	# Wire barn door.
	if _barn_door.body_entered.is_connected(on_barn_reached):
		pass  # already connected in scene
	else:
		_barn_door.body_entered.connect(on_barn_reached)

	# Wire player caught signal.
	if _player.has_signal("caught"):
		_player.caught.connect(_on_player_caught)

	# Wire rousable animals.
	var animals: Node = get_node_or_null("World/Animals")
	if animals != null:
		for animal: Node in animals.get_children():
			if animal.has_signal("roused"):
				animal.roused.connect(_on_animal_roused)

	# Connect ActIntro dismissed → tutorial hint timer.
	var intro: Node = get_node_or_null("ActIntro")
	if intro != null and intro.has_signal("dismissed"):
		intro.dismissed.connect(_on_intro_dismissed)

	# Dim Old Major's lantern (hooded — stealth context).
	var lantern: Node = get_node_or_null("World/OldMajor/LanternGlow")
	if lantern != null:
		lantern.set("energy", 0.55)
		lantern.set("texture_scale", 1.2)

	_schedule_owl_hoot()


func _process(_delta: float) -> void:
	# Keep StealthHUD updated every frame.
	if _stealth_hud != null and _player != null:
		if _stealth_hud.has_method("set_detection"):
			_stealth_hud.set_detection(_player.detection)
		if _stealth_hud.has_method("set_hidden"):
			_stealth_hud.set_hidden(_player.is_hidden)

# =============================================================================
# Public API — called by rousable animals
# =============================================================================

## Spawn and await the woven question for `animal_id`. Pauses the tree while
## the panel is open. Returns when the panel resolves (correct or auto-revealed).
func ask_question(animal_id: StringName) -> void:
	if not WOVEN_QUESTION_SCENE:
		return

	if _player != null:
		_player.freeze_for_question()

	get_tree().paused = true

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var panel: Control = WOVEN_QUESTION_SCENE.instantiate()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(panel)

	# Populate with question data.
	var qdata: Variant = Act1Questions.QUESTIONS.get(animal_id, null)
	if qdata != null and panel.has_method("setup"):
		panel.setup(qdata as Dictionary)

	await panel.answered

	layer.queue_free()
	get_tree().paused = false

	if _player != null:
		_player.unfreeze()

	_questions_done += 1


## Show the animal's waking line or Old Major's response line.
## `is_old_major` = true → show Old Major's line; false → animal's line.
func show_animal_line(animal_id: StringName, is_old_major: bool) -> void:
	var text: String
	if is_old_major:
		text = OLD_MAJOR_LINES.get(animal_id, "") as String
	else:
		text = ANIMAL_LINES.get(animal_id, "") as String
	if text.is_empty():
		return
	if _stealth_hud != null and _stealth_hud.has_method("show_caption"):
		_stealth_hud.show_caption(text, 2.2)

# =============================================================================
# Signal handlers
# =============================================================================

func _on_animal_roused(animal_id: StringName, world_pos: Vector2) -> void:
	comrades_roused += 1
	if _stealth_hud != null and _stealth_hud.has_method("set_comrades"):
		_stealth_hud.set_comrades(comrades_roused)
	# Advance checkpoint to where this animal was standing.
	_checkpoint = world_pos


func _on_player_caught() -> void:
	# Pick a random Orwellian caption.
	var idx: int = randi() % CAUGHT_CAPTIONS.size()
	if _stealth_hud != null and _stealth_hud.has_method("show_caption"):
		_stealth_hud.show_caption(CAUGHT_CAPTIONS[idx], 4.0)

	# Flash the screen dark (simple ColorRect tween — no GPUParticles).
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(0.0, 0.0, 0.0, 0.0)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.grow_horizontal = 2
	flash.grow_vertical = 2
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 80
	add_child(cl)
	cl.add_child(flash)

	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.85, 0.25)
	tw.tween_interval(0.4)
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.tween_callback(cl.queue_free)

	# Teleport the player to the last checkpoint.
	if _player != null:
		_player.respawn_at(_checkpoint)

	# Reset Moses to PATROL.
	if _moses != null and _moses.has_method("_enter_patrol"):
		_moses._enter_patrol()


## Connected to BarnDoor.body_entered. Runs once per valid player entry.
func on_barn_reached(body: Node2D) -> void:
	if _barn_triggered:
		return
	if not body.is_in_group(&"player"):
		return
	if comrades_roused < 4:
		var missing: int = 4 - comrades_roused
		var caption: String = "Old Major will not begin until all are gathered. %d still sleep." % missing
		if _stealth_hud != null and _stealth_hud.has_method("show_caption"):
			_stealth_hud.show_caption(caption, 5.0)
		return

	_barn_triggered = true
	_run_barn_finale()


func _run_barn_finale() -> void:
	if _player != null:
		_player.set_input_enabled(false)

	for line: String in BARN_LINES:
		if _stealth_hud != null and _stealth_hud.has_method("show_caption"):
			_stealth_hud.show_caption(line, BARN_LINE_PAUSE)
		await get_tree().create_timer(BARN_LINE_PAUSE + 0.3).timeout
		if not is_instance_valid(self):
			return

	GameState.corrupt_commandment(0)
	GameState.complete_act(1)
	SceneManager.go_to_act(2)


func _on_intro_dismissed() -> void:
	# Show tutorial hint after a short delay.
	await get_tree().create_timer(TUTORIAL_HINT_DELAY).timeout
	if not is_instance_valid(self):
		return
	if _stealth_hud != null and _stealth_hud.has_method("show_caption"):
		_stealth_hud.show_caption(TUTORIAL_HINT_TEXT, 6.0)

# =============================================================================
# Ambient OwlHoot scheduler
# =============================================================================

func _schedule_owl_hoot() -> void:
	var wait: float = randf_range(15.0, 30.0)
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(self):
		return
	if _owl_hoot != null and _owl_hoot.stream:
		_owl_hoot.play()
	_schedule_owl_hoot()
