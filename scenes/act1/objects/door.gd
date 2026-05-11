extends StaticBody2D

@export var required_keys: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var interact_zone: Area2D = $InteractZone
@onready var prompt_label: Label = $PromptLabel

var is_open: bool = false

func _ready() -> void:
	interact_zone.body_entered.connect(_on_interact_zone_entered)
	interact_zone.body_exited.connect(_on_interact_zone_exited)

func _on_interact_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		prompt_label.visible = true

func _on_interact_zone_exited(body: Node2D) -> void:
	prompt_label.visible = false

func _process(_delta: float) -> void:
	if is_open:
		return
	if Input.is_action_just_pressed("interact") and prompt_label.visible:
		var parent = get_parent()
		if parent.has_method("on_key_collected") and parent.keys_collected >= required_keys:
			_open()
		else:
			_rattle()

func _open() -> void:
	is_open = true
	prompt_label.visible = false
	body_shape.set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.4)
	get_parent().on_door_unlocked()

func _rattle() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(3, 0), 0.05)
	tween.tween_property(self, "position", position - Vector2(3, 0), 0.05)
	tween.tween_property(self, "position", position, 0.05)
