## Ported from Lango-Zelda-RPG World/Door.gd — persistent unlock + state check pattern
class_name Door
extends StaticBody2D

# =============================================================================
# Export variables
# =============================================================================

@export var door_id: int = 1
@export var required_keys: int = 1

# =============================================================================
# Public variables
# =============================================================================

var is_open: bool = false

# =============================================================================
# @onready variables
# =============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var interact_zone: Area2D = $InteractZone
@onready var prompt_label: Label = $PromptLabel

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# Already unlocked in a previous run — open silently with no animation
	if GameState.opened_door_ids.has(door_id):
		is_open = true
		prompt_label.visible = false
		body_shape.set_deferred("disabled", true)
		sprite.modulate = Color(1, 1, 1, 0)
		return
	add_to_group(&"doors")
	interact_zone.body_entered.connect(_on_interact_zone_entered)
	interact_zone.body_exited.connect(_on_interact_zone_exited)

func _process(_delta: float) -> void:
	if is_open:
		return
	if Input.is_action_just_pressed("interact") and prompt_label.visible:
		var parent: Node = get_parent()
		if parent.has_method("on_key_collected") and parent.keys_collected >= required_keys:
			_open()
		else:
			_rattle()

# =============================================================================
# Private methods
# =============================================================================

func _open() -> void:
	is_open = true
	prompt_label.visible = false
	body_shape.set_deferred("disabled", true)
	GameState.opened_door_ids.append(door_id)
	GameState.save_to_disk()
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.4)
	get_parent().on_door_unlocked()


func _rattle() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(3, 0), 0.05)
	tween.tween_property(self, "position", position - Vector2(3, 0), 0.05)
	tween.tween_property(self, "position", position, 0.05)

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_interact_zone_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		prompt_label.visible = true


func _on_interact_zone_exited(body: Node2D) -> void:
	prompt_label.visible = false
