## napoleon_interrogation.gd
## Controller for the Napoleon Interrogation finale scene.
## Instances napoleon_client.gd as a child, wires its 5 signals into the UI,
## and manages the briefing / dialogue / death / leave flow.

extends Control

# ── NAPOLEON'S SCRIPTED OPENING LINE (extracted from system-prompt.js line 19-20) ──
const NAPOLEON_FIRST_MESSAGE: String = \
	"*Napoleon stands on the low wooden platform at the end of the big barn, the nine dogs settled in the straw around his trotters. He does not step down to meet you. His small eyes move over you once, unhurried, and he waits until the silence in the barn belongs to him before he speaks.* \"So. Another visitor, come to the farm with questions. I am Napoleon. I have no quarrel with questions — a farm with nothing to hide has nothing to fear from them. Ask what you came to ask. But ask it plainly, and do not forget whose barn you are standing in.\""

# ── CROSSFADE STATE ──────────────────────────────────────────────────────────
var _active_portrait: int = 0   # 0 = portrait_a is showing, 1 = portrait_b
var _input_locked: bool = false
var _game_over: bool = false

# ── CHILD NODES (resolved in _ready) ────────────────────────────────────────
var _client: Node        # NapoleonClient (napoleon_client.gd)

# ── @ONREADY ─────────────────────────────────────────────────────────────────
@onready var portrait_a:     TextureRect   = %PortraitA
@onready var portrait_b:     TextureRect   = %PortraitB
@onready var gradient_strip: TextureRect   = %GradientStrip

@onready var briefing_overlay: Panel       = %BriefingOverlay
@onready var enter_btn:        Button      = %EnterBtn

@onready var dialogue_box:   Panel        = %DialogueBox
@onready var speech_label:   RichTextLabel= %SpeechLabel
@onready var thinking_label: Label        = %ThinkingLabel
@onready var band_label:     Label        = %BandLabel
@onready var score_label:    Label        = %ScoreLabel
@onready var msg_input:      LineEdit     = %MsgInput
@onready var send_btn:       Button       = %SendBtn
@onready var leave_btn_small: Button      = %LeaveBtnSmall

@onready var death_overlay:  Panel        = %DeathOverlay
@onready var death_text:     RichTextLabel= %DeathText
@onready var death_score:    Label        = %DeathScore
@onready var continue_btn:   Button       = %ContinueBtn

# ── LIFECYCLE ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Instantiate the logic client as a child node
	var ClientScript: GDScript = load("res://scenes/act5/napoleon_client.gd")
	_client = ClientScript.new()
	_client.name = "NapoleonClient"
	add_child(_client)

	# Connect signals
	_client.napoleon_spoke.connect(_on_napoleon_spoke)
	_client.game_state_updated.connect(_on_game_state_updated)
	_client.portrait_changed.connect(_on_portrait_changed)
	_client.player_died.connect(_on_player_died)
	_client.error_occurred.connect(_on_error_occurred)

	# UI initial state
	briefing_overlay.show()
	death_overlay.hide()
	thinking_label.hide()
	speech_label.bbcode_enabled = true
	speech_label.text = ""

	# Buttons
	enter_btn.pressed.connect(_on_enter_btn_pressed)
	send_btn.pressed.connect(_on_send_pressed)
	msg_input.text_submitted.connect(_on_text_submitted)
	leave_btn_small.pressed.connect(_on_leave_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	_set_band("composed", 0)
	_style_panels()

	# Load base portrait (cold_authority) directly so it shows before Enter is pressed
	var base_path: String = "res://assets/napoleon/portraits/cold_authority.png"
	if ResourceLoader.exists(base_path):
		portrait_a.texture = load(base_path)

	# Build a vertical dark gradient as a texture on the GradientStrip TextureRect.
	# This mirrors index.html's linear-gradient dark overlay at the bottom.
	_build_gradient_strip()

# ── BRIEFING → GAME START ────────────────────────────────────────────────────

func _on_enter_btn_pressed() -> void:
	briefing_overlay.hide()
	_client.start_game(NAPOLEON_FIRST_MESSAGE)
	msg_input.grab_focus()

# ── SEND ──────────────────────────────────────────────────────────────────────

func _on_send_pressed() -> void:
	_send()

func _on_text_submitted(_text: String) -> void:
	_send()

func _send() -> void:
	if _input_locked or _game_over:
		return
	var text: String = msg_input.text.strip_edges()
	if text.is_empty():
		return
	msg_input.text = ""
	_lock_input(true)
	thinking_label.show()
	_client.send_message(text)

func _lock_input(locked: bool) -> void:
	_input_locked = locked
	send_btn.disabled = locked
	msg_input.editable = not locked

# ── SIGNAL HANDLERS ───────────────────────────────────────────────────────────

func _on_napoleon_spoke(text: String) -> void:
	thinking_label.hide()
	if not _game_over:
		speech_label.text = _format_napoleon(text)
	if not _game_over:
		_lock_input(false)
		msg_input.grab_focus()

func _on_game_state_updated(band: String, _menace: int, score: int) -> void:
	_set_band(band, score)

func _on_portrait_changed(texture: Texture2D, _portrait_id: String) -> void:
	_crossfade_portrait(texture)

func _on_player_died(text: String, final_score: int) -> void:
	_game_over = true
	_lock_input(true)
	thinking_label.hide()
	speech_label.text = _format_napoleon(text)
	# Cross-fade to dogs portrait is already triggered by portrait_changed signal
	# Show death overlay after brief delay
	var t: SceneTreeTimer = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		death_text.bbcode_enabled = true
		death_text.text = _format_napoleon(text)
		death_score.text = "Lies exposed: %d" % final_score
		death_overlay.show()
	)

func _on_error_occurred(message: String) -> void:
	thinking_label.hide()
	speech_label.text = speech_label.text + "\n[color=#c04040][i]Error: %s[/i][/color]" % message
	if not _game_over:
		_lock_input(false)

# ── LEAVE / CONTINUE ─────────────────────────────────────────────────────────

func _on_leave_pressed() -> void:
	SceneManager.go_to_scene("res://scenes/act4/credits.tscn")

func _on_continue_pressed() -> void:
	SceneManager.go_to_scene("res://scenes/act4/credits.tscn")

# ── PANEL STYLING (applied in code to avoid .tscn inline resource issues) ───

func _style_panels() -> void:
	# Briefing overlay — very dark semi-opaque background
	var briefing_style: StyleBoxFlat = StyleBoxFlat.new()
	briefing_style.bg_color = Color(0.024, 0.012, 0.004, 0.88)
	briefing_overlay.add_theme_stylebox_override("panel", briefing_style)

	# Briefing card (PanelContainer child) — parchment
	var card_node: Node = briefing_overlay.get_node("BriefingCard")
	if card_node:
		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = Color(0.91, 0.851, 0.69)
		card_style.border_color = Color(0.545, 0.42, 0.227)
		card_style.set_border_width_all(3)
		card_style.set_corner_radius_all(2)
		card_node.add_theme_stylebox_override("panel", card_style)

	# Enter button — leather
	var enter_btn_style: StyleBoxFlat = StyleBoxFlat.new()
	enter_btn_style.bg_color = Color(0.42, 0.24, 0.098)
	enter_btn_style.border_color = Color(0.545, 0.42, 0.227)
	enter_btn_style.set_border_width_all(2)
	enter_btn.add_theme_stylebox_override("normal", enter_btn_style)
	var enter_btn_hover: StyleBoxFlat = StyleBoxFlat.new()
	enter_btn_hover.bg_color = Color(0.52, 0.30, 0.12)
	enter_btn_hover.border_color = Color(0.545, 0.42, 0.227)
	enter_btn_hover.set_border_width_all(2)
	enter_btn.add_theme_stylebox_override("hover", enter_btn_hover)

	# Dialogue box — parchment background
	var dialogue_style: StyleBoxFlat = StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.91, 0.851, 0.69)
	dialogue_style.border_color = Color(0.545, 0.42, 0.227)
	dialogue_style.border_width_top = 3
	dialogue_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	dialogue_style.shadow_size = 8
	get_node("%DialogueBox").add_theme_stylebox_override("panel", dialogue_style)

	# Death overlay — deep blood-red
	var death_style: StyleBoxFlat = StyleBoxFlat.new()
	death_style.bg_color = Color(0.314, 0.0, 0.0, 0.92)
	death_overlay.add_theme_stylebox_override("panel", death_style)

	# Send button — leather
	var send_style: StyleBoxFlat = StyleBoxFlat.new()
	send_style.bg_color = Color(0.42, 0.24, 0.098)
	send_style.border_color = Color(0.227, 0.102, 0.024)
	send_style.set_border_width_all(1)
	send_btn.add_theme_stylebox_override("normal", send_style)
	var send_hover: StyleBoxFlat = StyleBoxFlat.new()
	send_hover.bg_color = Color(0.52, 0.30, 0.12)
	send_hover.border_color = Color(0.227, 0.102, 0.024)
	send_hover.set_border_width_all(1)
	send_btn.add_theme_stylebox_override("hover", send_hover)

	# Status chips (MOOD / LIES EXPOSED) — raised darker-parchment panels
	var chip: StyleBoxFlat = StyleBoxFlat.new()
	chip.bg_color = Color(0.788, 0.706, 0.475)
	chip.border_color = Color(0.545, 0.42, 0.227)
	chip.set_border_width_all(2)
	chip.set_corner_radius_all(2)
	chip.content_margin_left = 12
	chip.content_margin_right = 12
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	var band_panel: PanelContainer = %BandPanel
	var score_panel: PanelContainer = %ScorePanel
	band_panel.add_theme_stylebox_override("panel", chip)
	score_panel.add_theme_stylebox_override("panel", chip.duplicate())

	# Message input — recessed tan field with a worn border
	var input_normal: StyleBoxFlat = StyleBoxFlat.new()
	input_normal.bg_color = Color(0.804, 0.722, 0.518)
	input_normal.border_color = Color(0.545, 0.42, 0.227)
	input_normal.set_border_width_all(1)
	input_normal.set_corner_radius_all(2)
	input_normal.content_margin_left = 10
	input_normal.content_margin_right = 10
	input_normal.content_margin_top = 6
	input_normal.content_margin_bottom = 6
	var input_focus: StyleBoxFlat = input_normal.duplicate()
	input_focus.bg_color = Color(0.871, 0.792, 0.588)
	input_focus.set_border_width_all(2)
	msg_input.add_theme_stylebox_override("normal", input_normal)
	msg_input.add_theme_stylebox_override("focus", input_focus)
	msg_input.add_theme_stylebox_override("read_only", input_normal.duplicate())
	msg_input.add_theme_color_override("font_color", Color(0.11, 0.063, 0.031))
	msg_input.add_theme_color_override("font_uneditable_color", Color(0.302, 0.224, 0.122))
	msg_input.add_theme_color_override("font_placeholder_color", Color(0.341, 0.255, 0.129, 0.6))
	msg_input.add_theme_color_override("caret_color", Color(0.11, 0.063, 0.031))

	# Leave button — small, subtle parchment chip
	var leave_normal: StyleBoxFlat = StyleBoxFlat.new()
	leave_normal.bg_color = Color(0.831, 0.761, 0.529)
	leave_normal.border_color = Color(0.545, 0.42, 0.227)
	leave_normal.set_border_width_all(1)
	leave_normal.set_corner_radius_all(2)
	leave_normal.content_margin_left = 10
	leave_normal.content_margin_right = 10
	leave_normal.content_margin_top = 3
	leave_normal.content_margin_bottom = 3
	var leave_hover: StyleBoxFlat = leave_normal.duplicate()
	leave_hover.bg_color = Color(0.894, 0.824, 0.604)
	leave_btn_small.add_theme_stylebox_override("normal", leave_normal)
	leave_btn_small.add_theme_stylebox_override("hover", leave_hover)
	leave_btn_small.add_theme_stylebox_override("pressed", leave_hover.duplicate())
	leave_btn_small.add_theme_color_override("font_color", Color(0.42, 0.24, 0.098))
	leave_btn_small.add_theme_color_override("font_hover_color", Color(0.42, 0.24, 0.098))

# ── GRADIENT STRIP (dark vignette at bottom, mirrors index.html ::after) ────

func _build_gradient_strip() -> void:
	var grad: Gradient = Gradient.new()
	grad.add_point(0.0,  Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.38, Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.55, Color(0.039, 0.024, 0.008, 0.55))
	grad.add_point(0.72, Color(0.031, 0.016, 0.004, 0.85))
	grad.add_point(1.0,  Color(0.024, 0.012, 0.004, 0.96))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to   = Vector2(0.5, 1.0)
	gradient_strip.texture = tex

# ── PORTRAIT CROSSFADE (mirrors index.html crossfadePortrait, 300 ms) ───────

func _crossfade_portrait(texture: Texture2D) -> void:
	var incoming: TextureRect = portrait_b if _active_portrait == 0 else portrait_a
	var outgoing: TextureRect = portrait_a if _active_portrait == 0 else portrait_b

	incoming.texture = texture
	incoming.modulate.a = 0.0
	incoming.z_index = 2
	outgoing.z_index = 1

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "modulate:a", 1.0, 0.3)
	tween.tween_property(outgoing, "modulate:a", 0.0, 0.3)

	_active_portrait = 1 - _active_portrait

# ── HUD UPDATE ────────────────────────────────────────────────────────────────

func _set_band(band: String, score: int) -> void:
	score_label.text = str(score)
	match band:
		"composed":
			band_label.text = "COMPOSED"
			band_label.add_theme_color_override("font_color", Color(0.227, 0.361, 0.102))
		"wary":
			band_label.text = "WARY"
			band_label.add_theme_color_override("font_color", Color(0.545, 0.353, 0.039))
		"dangerous":
			band_label.text = "DANGEROUS"
			band_label.add_theme_color_override("font_color", Color(0.478, 0.102, 0.102))
		_:
			band_label.text = band.to_upper()

# ── TEXT FORMATTING (*italic* → BBCode) ──────────────────────────────────────

func _format_napoleon(raw: String) -> String:
	# Convert *text* markers to [i]text[/i] BBCode
	var result: String = raw
	var open: bool = false
	var out: String = ""
	var i: int = 0
	while i < result.length():
		if result[i] == "*":
			if open:
				out += "[/i]"
				open = false
			else:
				out += "[i]"
				open = true
		else:
			out += result[i]
		i += 1
	if open:
		out += "[/i]"
	return out
