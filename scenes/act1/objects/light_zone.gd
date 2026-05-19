## Marks this Area2D as a light zone (static spotlight / farmhouse window glow).
## Old Major's BodySensor reads overlapping areas and filters by the "light" group.
## Standing in a light pool exposes the player independently of Moses.
## Spec: active.md §4 player/old_major.gd, §3 LightPools.
extends Area2D

func _ready() -> void:
	add_to_group(&"light")
