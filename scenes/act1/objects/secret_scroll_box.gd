extends StaticBody2D

## Breakable box — hit 3 times from above to break.
## If contains_scroll is true, sets GameState.has_secret_scroll on break.
@export var contains_scroll: bool = false

var hit_count: int = 0
var is_broken: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_zone: Area2D = $HitZone

func _ready() -> void:
	hit_zone.body_entered.connect(_on_hit_zone_body_entered)

func _on_hit_zone_body_entered(body: Node2D) -> void:
	if is_broken:
		return
	# Only trigger if body is falling onto the box from above
	if body.is_in_group("player") and body.velocity.y > 20.0:
		_take_hit()

func _take_hit() -> void:
	hit_count += 1
	if hit_count >= 3:
		_break()
	else:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

func _break() -> void:
	is_broken = true

	if contains_scroll:
		GameState.has_secret_scroll = true
		_show_scroll_message()

	sprite.play("break")
	collision.set_deferred("disabled", true)
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _show_scroll_message() -> void:
	var lbl := Label.new()
	lbl.text = "✦ Torn scroll found! Old Major's private words..."
	lbl.modulate = Color(0.96, 0.82, 0.35, 1.0)
	lbl.position = Vector2(-90.0, -55.0)
	get_parent().add_child(lbl)

	var tween = create_tween()
	tween.tween_property(lbl, "position", lbl.position + Vector2(0, -30), 2.0)
	tween.parallel().tween_property(lbl, "modulate", Color(0.96, 0.82, 0.35, 0.0), 2.0)
	tween.tween_callback(lbl.queue_free)
