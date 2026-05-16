extends Node
## Dev-only screenshot harness — NOT part of the shipped game.
## Loads a target scene, dismisses its ActIntro, and saves the full root
## viewport framebuffer (includes every CanvasLayer — unlike OS window capture).
## Usage: godot --path <proj> res://scenes/_shot.tscn ++ <target.tscn> <out.png>

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target: String = args[0] if args.size() > 0 else "res://scenes/act2/boxer_revolution.tscn"
	var out: String = args[1] if args.size() > 1 else "user://shot.png"
	var scene: Node = (load(target) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(2.0).timeout
	var intro: Node = scene.get_node_or_null("ActIntro")
	if intro != null:
		intro.queue_free()  # _exit_tree() clears the global pause
	await get_tree().create_timer(1.6).timeout
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(out)
	print("[SHOT] target=", target, " out=", out, " size=", img.get_size(), " err=", err)
	get_tree().quit()
