## Ported from Lango-Zelda-RPG World/key.gd — persistent pickup pattern
class_name KeyPickup
extends Area2D

# =============================================================================
# Export variables
# =============================================================================

@export var key_id: int = 1

# =============================================================================
# @onready variables
# =============================================================================

@onready var sprite: Sprite2D = $Sprite2D

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	# Already collected this session — remove immediately without side-effects
	if GameState.collected_key_ids.has(key_id):
		queue_free()
		return
	add_to_group(&"keys")
	body_entered.connect(_on_body_entered)

# =============================================================================
# Signal callbacks
# =============================================================================

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		GameState.collected_key_ids.append(key_id)
		GameState.save_to_disk()
		body.collect_key()
		queue_free()
