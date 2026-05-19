## Marks this Area2D as a shadow zone. Old Major's BodySensor reads overlapping
## areas and filters by the "shadow" group to determine if the player is hidden.
## Spec: active.md §4 player/old_major.gd, §3 ShadowPools.
extends Area2D

func _ready() -> void:
	add_to_group(&"shadow")
