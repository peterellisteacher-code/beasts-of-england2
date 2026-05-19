class_name CaseFileUI
extends CanvasLayer
## The investigation UI for Act 4's windmill case-file. Builds and runs the
## whole flow: two rooms of hotspots -> evidence collection -> the two-page
## Casebook -> the truth -> Squealer's version -> the proclamation painted
## over the finished casebook. Emits `case_complete` when the ending is done.

signal case_complete

const COL_BONE: Color = Color("f5f0e8")
const COL_SOIL: Color = Color("181009")
const COL_GOLD: Color = Color("c4a24a")
const COL_RED: Color = Color("8b1a1a")
const COL_MUTED: Color = Color("d8d0be")
const COL_STONE: Color = Color("5a5e58")

var _case: Dictionary = WindmillCaseData.CASE

var _collected: Dictionary = {}            # kw_id -> true
var _current_hotspot: int = -1
var _current_room: int = 1
var _active_scroll: int = 0
var _ended: bool = false
var _completed: bool = false               # guards _emit_complete against a double press

var _scrolls: Array[CaseScroll] = []
var _markers: Array[Dictionary] = []       # [{ "node": SceneHotspot, "room": int, "index": int }]
var _room_textures: Dictionary = {}        # room id -> Texture2D (preloaded)

# --- node refs (all built in code) --------------------------------------------
var _room_bg: TextureRect
var _hud: Control
var _controls_hud: CanvasLayer             # the shared ControlsHUD (a sibling node)
var _marker_layer: Control
var _room_tabs: Array[Button] = []
var _evidence_label: Label

var _hotspot_panel: Control
var _hp_title: Label
var _hp_body: RichTextLabel

var _casebook: Control
var _word_bank: CaseWordBank
var _tab_btns: Array[Button] = []
var _scroll_host: VBoxContainer
var _cb_message: Label

var _end_panel: Control
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 5
	_controls_hud = get_parent().get_node_or_null("ControlsHUD") as CanvasLayer
	_build_room_bg()
	_build_hud()
	_build_hotspot_panel()
	_build_casebook()
	_build_end_panel()
	_build_toast()
	_update_evidence_label()
	_show_room(1)


# =============================================================================
# Build — room background
# =============================================================================

func _build_room_bg() -> void:
	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.color = Color("232624")
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fallback)

	_room_bg = TextureRect.new()
	_room_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_room_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_room_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_room_bg)

	# Preload both room backgrounds so switching rooms never blocks the main
	# thread — a synchronous load() is a visible hitch in an HTML5 export.
	for room: Dictionary in _case["rooms"]:
		var path: String = room["background"]
		if ResourceLoader.exists(path):
			_room_textures[int(room["id"])] = load(path) as Texture2D


# =============================================================================
# Build — HUD (investigate mode)
# =============================================================================

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	# Persistent goal banner — the goal stays on screen the whole act.
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _flat(Color("181009e6"), COL_GOLD, 0, 2))
	banner.anchor_right = 1.0
	banner.offset_bottom = 46.0
	_hud.add_child(banner)
	var banner_label := Label.new()
	banner_label.text = _case["goal_banner"]
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 17)
	banner_label.add_theme_color_override("font_color", COL_GOLD)
	banner.add_child(banner_label)

	# Room switcher — two tabs, top-left.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.offset_left = 16.0
	tabs.offset_top = 56.0
	_hud.add_child(tabs)
	for room: Dictionary in _case["rooms"]:
		var tab := _make_button(room["label"], 17)
		tab.custom_minimum_size = Vector2(240, 44)
		tab.pressed.connect(_show_room.bind(int(room["id"])))
		tabs.add_child(tab)
		_room_tabs.append(tab)

	# Hotspot markers (all rooms; shown/hidden by _show_room).
	_marker_layer = Control.new()
	_marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_marker_layer)
	var hotspots: Array = _case["hotspots"]
	for i: int in hotspots.size():
		var hs: Dictionary = hotspots[i]
		var marker := SceneHotspot.new()
		marker.setup(hs["id"], hs["title"])
		var pos: Vector2 = hs["pos"]
		marker.position = pos - Vector2(23, 23)
		marker.pressed.connect(_open_hotspot.bind(i))
		_marker_layer.add_child(marker)
		_markers.append({"node": marker, "room": int(hs["room"]), "index": i})

	# Bottom-right: evidence count + Casebook button.
	var corner := VBoxContainer.new()
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -272.0
	corner.offset_top = -98.0
	corner.offset_right = -16.0
	corner.offset_bottom = -16.0
	corner.add_theme_constant_override("separation", 6)
	_hud.add_child(corner)

	_evidence_label = Label.new()
	_evidence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_evidence_label.add_theme_font_size_override("font_size", 16)
	_evidence_label.add_theme_color_override("font_color", COL_BONE)
	corner.add_child(_evidence_label)

	var casebook_btn := _make_button("OPEN  CASEBOOK", 24)
	casebook_btn.custom_minimum_size = Vector2(256, 52)
	casebook_btn.pressed.connect(_open_casebook)
	corner.add_child(casebook_btn)


func _show_room(room_id: int) -> void:
	_current_room = room_id
	if _room_textures.has(room_id):
		_room_bg.texture = _room_textures[room_id]
	for entry: Dictionary in _markers:
		(entry["node"] as Control).visible = entry["room"] == room_id
	for i: int in _room_tabs.size():
		_style_room_tab(_room_tabs[i], (i + 1) == room_id)


# Show / hide the whole investigate layer AND the shared controls HUD together,
# so the corner controls panel never overlaps a modal or the Casebook tabs.
func _set_investigate_visible(v: bool) -> void:
	_hud.visible = v
	if _controls_hud != null:
		_controls_hud.visible = v


# =============================================================================
# Build — hotspot panel
# =============================================================================

func _build_hotspot_panel() -> void:
	_hotspot_panel = Control.new()
	_hotspot_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hotspot_panel.visible = false
	add_child(_hotspot_panel)

	var scrim := _make_scrim()
	scrim.gui_input.connect(_on_hotspot_scrim_input)
	_hotspot_panel.add_child(scrim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color("231a0ff7"), COL_GOLD, 3, 2))
	_center(panel, 780, 470)
	_hotspot_panel.add_child(panel)

	var margin := _margin(panel, 26)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_hp_title = Label.new()
	_hp_title.add_theme_font_size_override("font_size", 26)
	_hp_title.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(_hp_title)

	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sc)

	_hp_body = RichTextLabel.new()
	_hp_body.bbcode_enabled = true
	_hp_body.fit_content = true
	_hp_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hp_body.meta_underlined = false
	_hp_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_body.add_theme_font_size_override("normal_font_size", 19)
	_hp_body.add_theme_font_size_override("bold_font_size", 19)
	_hp_body.add_theme_constant_override("line_separation", 5)
	_hp_body.add_theme_color_override("default_color", COL_BONE)
	_hp_body.meta_clicked.connect(_on_hotspot_meta)
	sc.add_child(_hp_body)

	var hint := Label.new()
	hint.text = "Click an underlined word to add it to your evidence."
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(hint)

	var close_btn := _make_button("Close", 18)
	close_btn.custom_minimum_size = Vector2(150, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_close_hotspot_panel)
	vbox.add_child(close_btn)


# =============================================================================
# Build — Casebook
# =============================================================================

func _build_casebook() -> void:
	_casebook = Control.new()
	_casebook.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_casebook.visible = false
	add_child(_casebook)
	_casebook.add_child(_make_scrim())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color("231a0ffb"), COL_GOLD, 3, 2))
	_center(panel, 1172, 650)
	_casebook.add_child(panel)

	var margin := _margin(panel, 22)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "THE CASEBOOK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_GOLD)
	header.add_child(title)
	var return_btn := _make_button("Return to the wreck", 17)
	return_btn.custom_minimum_size = Vector2(230, 44)
	return_btn.pressed.connect(_close_casebook)
	header.add_child(return_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	var scroll_defs: Array = _case["scrolls"]
	for i: int in scroll_defs.size():
		var tab := _make_button(scroll_defs[i]["title"], 16)
		tab.custom_minimum_size = Vector2(0, 42)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_scroll.bind(i))
		tabs.add_child(tab)
		_tab_btns.append(tab)
	_tab_btns[1].disabled = true

	_cb_message = Label.new()
	_cb_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cb_message.add_theme_font_size_override("font_size", 15)
	_cb_message.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(_cb_message)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	vbox.add_child(content)

	var bank_sc := ScrollContainer.new()
	bank_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bank_sc.custom_minimum_size = Vector2(376, 0)
	bank_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bank_sc)
	_word_bank = CaseWordBank.new()
	_word_bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_word_bank.size_flags_vertical = Control.SIZE_FILL
	_word_bank.selection_changed.connect(_on_word_selected)
	bank_sc.add_child(_word_bank)

	var scroll_sc := ScrollContainer.new()
	scroll_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll_sc)
	_scroll_host = VBoxContainer.new()
	_scroll_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_sc.add_child(_scroll_host)

	for i: int in scroll_defs.size():
		var cs := CaseScroll.new()
		cs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cs.setup(scroll_defs[i])
		cs.slot_clicked.connect(_on_slot_clicked.bind(i))
		cs.state_changed.connect(_on_scroll_state_changed.bind(i))
		_scroll_host.add_child(cs)
		_scrolls.append(cs)

	_select_scroll(0)


# =============================================================================
# Build — end panel, toast
# =============================================================================

func _build_end_panel() -> void:
	_end_panel = Control.new()
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.visible = false
	add_child(_end_panel)
	_end_panel.add_child(_make_scrim())


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", COL_BONE)
	_toast_label.add_theme_color_override("font_outline_color", COL_SOIL)
	_toast_label.add_theme_constant_override("outline_size", 6)
	# Sits just below the goal banner — clear of the centred modal panels.
	_toast_label.anchor_right = 1.0
	_toast_label.offset_top = 54.0
	_toast_label.offset_bottom = 92.0
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)


# =============================================================================
# Hotspots
# =============================================================================

func _open_hotspot(index: int) -> void:
	_current_hotspot = index
	var hs: Dictionary = _case["hotspots"][index]
	_hp_title.text = hs["title"]
	_hp_body.text = _render_hotspot_body(hs["body"])
	for entry: Dictionary in _markers:
		if entry["index"] == index:
			(entry["node"] as SceneHotspot).mark_visited()
	_set_investigate_visible(false)
	_hotspot_panel.visible = true


func _render_hotspot_body(body: String) -> String:
	var out: String = body
	for kw_id: String in _case["keywords"]:
		var marker: String = "[%s]" % kw_id
		if out.contains(marker):
			out = out.replace(marker, _keyword_markup(kw_id))
	return out


func _keyword_markup(kw_id: String) -> String:
	var kw: Dictionary = _case["keywords"][kw_id]
	if _collected.has(kw_id):
		return "[color=#6f6857]%s[/color]" % kw["text"]
	var col: String = WindmillCaseData.CATEGORY_COLOR[kw["category"]].to_html(false)
	return "[url=%s][b][color=#%s][u]%s[/u][/color][/b][/url]" % [kw_id, col, kw["text"]]


func _on_hotspot_meta(meta: Variant) -> void:
	var kw_id: String = str(meta)
	if not kw_id.begins_with("kw_") or not _case["keywords"].has(kw_id) or _collected.has(kw_id):
		return
	_collected[kw_id] = true
	_word_bank.add_keyword(kw_id)
	_update_evidence_label()
	if _current_hotspot >= 0:
		_hp_body.text = _render_hotspot_body(_case["hotspots"][_current_hotspot]["body"])
	_toast("Added to evidence: %s" % _case["keywords"][kw_id]["text"])


func _close_hotspot_panel() -> void:
	_hotspot_panel.visible = false
	_current_hotspot = -1
	_set_investigate_visible(true)


func _on_hotspot_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_hotspot_panel()


func _update_evidence_label() -> void:
	_evidence_label.text = "Evidence: %d of %d clues" % [_collected.size(), _case["keywords"].size()]


# =============================================================================
# Casebook
# =============================================================================

func _open_casebook() -> void:
	_word_bank.clear_selection()
	_set_investigate_visible(false)
	_casebook.visible = true
	_refresh_casebook_message()


func _close_casebook() -> void:
	_casebook.visible = false
	if not _ended:
		_set_investigate_visible(true)


func _select_scroll(index: int) -> void:
	if _tab_btns[index].disabled:
		return
	_active_scroll = index
	for i: int in _scrolls.size():
		_scrolls[i].visible = i == index
		_tab_btns[i].button_pressed = i == index
	_refresh_casebook_message()


func _refresh_casebook_message() -> void:
	if not _scrolls[0].is_solved():
		_cb_message.text = "Place words from the Evidence bank into the slots. Settle Page One to unlock Page Two."
	elif not _scrolls[1].is_solved():
		_cb_message.text = "Page One is settled. Build the account: make it valid, then make it sound."
	else:
		_cb_message.text = "The case is complete."


func _on_word_selected(kw_id: String) -> void:
	if kw_id != "":
		_toast("Selected: %s — now click a slot." % _case["keywords"][kw_id]["text"])


func _on_slot_clicked(slot_id: String, scroll_index: int) -> void:
	var scroll: CaseScroll = _scrolls[scroll_index]
	var slots: Dictionary = _case["scrolls"][scroll_index]["slots"]
	if not slots.has(slot_id):
		return
	var selected: String = _word_bank.get_selected()
	var current: String = scroll.get_slot(slot_id)

	if selected == "":
		if current != "":
			scroll.set_slot(slot_id, "")
			_toast("Slot cleared.")
		else:
			_toast("Pick a word from the Evidence bank first.")
		return

	var slot_cat: String = slots[slot_id]["category"]
	var kw_cat: String = _case["keywords"][selected]["category"]
	if kw_cat != slot_cat:
		_toast("That is the wrong kind of word — this slot needs a %s." % slot_cat)
		return

	scroll.set_slot(slot_id, selected)
	_word_bank.clear_selection()


func _on_scroll_state_changed(scroll_index: int) -> void:
	if _ended:
		return
	if scroll_index == 0 and _scrolls[0].is_solved():
		_scrolls[0].set_locked(true)
		if _tab_btns[1].disabled:
			_tab_btns[1].disabled = false
			_select_scroll(1)
	if scroll_index == 1 and _scrolls[1].is_solved() and _scrolls[0].is_solved():
		_finish_case()
	_refresh_casebook_message()


# =============================================================================
# Ending — truth, Squealer, the proclamation painted over the casebook
# =============================================================================

func _finish_case() -> void:
	if _ended:
		return
	_ended = true
	_scrolls[1].set_locked(true)
	await get_tree().create_timer(1.1).timeout
	if not is_instance_valid(self):
		return
	_casebook.visible = false
	_show_end(_case["truth"]["title"], "", _case["truth"]["body"], "Continue", _show_squealer)


func _show_squealer() -> void:
	var sq: Dictionary = _case["squealer"]
	_show_end(sq["title"], sq["speaker"], sq["body"], "Continue", _show_proclamation)


func _show_end(title_text: String, speaker: String, body_text: String, btn_text: String, on_continue: Callable) -> void:
	for child: Node in _end_panel.get_children():
		if child.name != "Scrim":
			child.queue_free()

	var is_squealer: bool = speaker != ""
	var accent: Color = COL_RED if is_squealer else COL_GOLD
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color("231a0ffb"), accent, 3, 2))
	_center(panel, 824, 484)
	_end_panel.add_child(panel)

	var margin := _margin(panel, 28)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	if is_squealer:
		var who := Label.new()
		who.text = speaker + " SPEAKS"
		who.add_theme_font_size_override("font_size", 16)
		who.add_theme_color_override("font_color", accent)
		vbox.add_child(who)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", accent)
	vbox.add_child(title)

	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sc)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 19)
	body.add_theme_constant_override("line_separation", 5)
	body.add_theme_color_override("default_color", COL_BONE)
	body.text = body_text
	sc.add_child(body)

	var btn := _make_button(btn_text, 19)
	btn.custom_minimum_size = Vector2(190, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(on_continue)
	vbox.add_child(btn)

	_end_panel.visible = true


# The dissonance beat: the casebook truth, then the proclamation stamped over it.
func _show_proclamation() -> void:
	for child: Node in _end_panel.get_children():
		if child.name != "Scrim":
			child.queue_free()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color("231a0ffb"), COL_RED, 3, 2))
	_center(panel, 880, 470)
	_end_panel.add_child(panel)
	var margin := _margin(panel, 28)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# The casebook line — the truth, plainly set.
	var casebook_line := Label.new()
	casebook_line.text = "YOUR CASEBOOK:  The windmill fell to its own thin walls and the storm."
	casebook_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	casebook_line.add_theme_font_size_override("font_size", 19)
	casebook_line.add_theme_color_override("font_color", COL_BONE)
	vbox.add_child(casebook_line)

	# The proclamation — painted, loud, red — stamped over the truth.
	var stamp := PanelContainer.new()
	stamp.add_theme_stylebox_override("panel", _flat(COL_RED, Color("c4a24a"), 18, 2))
	stamp.modulate.a = 0.0
	vbox.add_child(stamp)
	var stamp_label := Label.new()
	stamp_label.text = _case["proclamation"]["stamp_text"]
	stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stamp_label.add_theme_font_size_override("font_size", 32)
	stamp_label.add_theme_color_override("font_color", COL_BONE)
	stamp.add_child(stamp_label)

	var closing := Label.new()
	closing.text = _case["proclamation"]["closing"]
	closing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	closing.add_theme_font_size_override("font_size", 18)
	closing.add_theme_color_override("font_color", COL_MUTED)
	closing.modulate.a = 0.0
	vbox.add_child(closing)

	var btn := _make_button("Continue", 19)
	btn.custom_minimum_size = Vector2(190, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.modulate.a = 0.0
	btn.disabled = true
	btn.pressed.connect(_emit_complete)
	vbox.add_child(btn)

	_end_panel.visible = true
	# The proclamation lands heavily over the casebook, then the rest fades up.
	# The Continue button is held disabled until the beat has fully played.
	var tween: Tween = create_tween()
	tween.tween_interval(0.7)
	tween.tween_property(stamp, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(casebook_line, "modulate", Color(0.78, 0.74, 0.63, 1.0), 0.4)
	tween.tween_property(closing, "modulate:a", 1.0, 0.8)
	tween.tween_property(btn, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func() -> void: btn.disabled = false)


func _emit_complete() -> void:
	if _completed:
		return
	_completed = true
	_end_panel.visible = false
	case_complete.emit()


# =============================================================================
# Helpers
# =============================================================================

func _toast(msg: String) -> void:
	# While the Casebook is open, route messages to its own status line so the
	# floating toast never overlaps the casebook pages.
	if _casebook.visible:
		_cb_message.text = msg
		return
	_toast_label.text = msg
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func _make_scrim() -> ColorRect:
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.03, 0.025, 0.018, 0.84)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	return scrim


func _make_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := _flat(Color("382913"), COL_GOLD, 12, 2)
		if state == "hover":
			sb.bg_color = Color("4a3a1e")
		elif state == "pressed":
			sb.bg_color = Color("281c0d")
		elif state == "disabled":
			sb.bg_color = Color("2a2620")
			sb.border_color = COL_STONE
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", COL_BONE)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_BONE)
	btn.add_theme_color_override("font_focus_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_STONE)
	return btn


func _style_room_tab(tab: Button, active: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := _flat(Color("4a3a1e") if active else Color("281c0d"), COL_GOLD, 10, 2)
		if active:
			sb.set_border_width_all(3)
		if state == "hover":
			sb.bg_color = sb.bg_color.lightened(0.1)
		tab.add_theme_stylebox_override(state, sb)
	tab.add_theme_color_override("font_color", COL_GOLD if active else COL_BONE)


func _flat(bg: Color, border: Color, pad: int, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(pad)
	return sb


func _center(ctrl: Control, w: float, h: float) -> void:
	ctrl.anchor_left = 0.5
	ctrl.anchor_right = 0.5
	ctrl.anchor_top = 0.5
	ctrl.anchor_bottom = 0.5
	ctrl.offset_left = -w * 0.5
	ctrl.offset_right = w * 0.5
	ctrl.offset_top = -h * 0.5
	ctrl.offset_bottom = h * 0.5


func _margin(parent: Control, pad: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	parent.add_child(m)
	return m
