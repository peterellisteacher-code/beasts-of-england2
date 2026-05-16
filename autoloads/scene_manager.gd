extends Node

# =============================================================================
# Constants
# =============================================================================

const ACT_SCENES: Dictionary = {
	1: "res://scenes/act1/old_major_platformer.tscn",
	2: "res://scenes/act2/boxer_revolution.tscn",
	3: "res://scenes/act3/cowshed_overworld.tscn",
	4: "res://scenes/act4/politics_tactics.tscn",
}

# =============================================================================
# Public methods
# =============================================================================

func go_to_act(act_number: int) -> void:
	if not ACT_SCENES.has(act_number):
		push_error("SceneManager.go_to_act: act %d is not mapped" % act_number)
		return
	GameState.current_act = act_number
	# Persist immediately so that a browser tab refresh/close between acts does
	# not roll current_act back to the previously-saved value.
	GameState.save_to_disk()
	go_to_scene(ACT_SCENES[act_number])


func go_to_scene(path: String) -> void:
	if path.is_empty():
		push_error("SceneManager.go_to_scene: path is empty")
		return
	# Deferred so signal-handler callers (body_entered, etc.) don't tear down
	# CollisionObjects during a physics callback.
	get_tree().call_deferred("change_scene_to_file", path)
