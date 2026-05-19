class_name CaseWordBank
extends PanelContainer
## The evidence bank — collected keyword-clues, grouped by category. Tap a
## chip to select it (tap again to deselect). The Casebook reads the current
## selection to place a word into a page slot. Words are copies — the bank
## never empties, so one clue can fill more than one slot.

signal selection_changed(kw_id: String)

var _selected: String = ""
var _chips: Dictionary = {}      # kw_id -> Button
var _sections: Dictionary = {}   # category -> { "box": VBoxContainer, "flow": HFlowContainer }
var _empty_label: Label

func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("181009f4")
	bg.border_color = Color("c4a24a")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(2)
	bg.set_content_margin_all(14)
	add_theme_stylebox_override("panel", bg)
	_build()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var header := Label.new()
	header.text = "EVIDENCE"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color("f5f0e8"))
	vbox.add_child(header)

	_empty_label = Label.new()
	_empty_label.text = "No clues yet. Investigate the rooms — click a glowing mark to gather evidence."
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_font_size_override("font_size", 16)
	_empty_label.add_theme_color_override("font_color", Color("9a9282"))
	vbox.add_child(_empty_label)

	for category: String in ["person", "thing", "place"]:
		var box := VBoxContainer.new()
		box.visible = false
		box.add_theme_constant_override("separation", 4)
		var cat_label := Label.new()
		cat_label.text = WindmillCaseData.CATEGORY_LABEL[category]
		cat_label.add_theme_font_size_override("font_size", 14)
		cat_label.add_theme_color_override("font_color", WindmillCaseData.CATEGORY_COLOR[category])
		box.add_child(cat_label)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		box.add_child(flow)
		vbox.add_child(box)
		_sections[category] = {"box": box, "flow": flow}


func add_keyword(kw_id: String) -> void:
	if _chips.has(kw_id):
		return
	if not WindmillCaseData.CASE["keywords"].has(kw_id):
		push_warning("CaseWordBank: unknown keyword '%s'" % kw_id)
		return
	var kw: Dictionary = WindmillCaseData.CASE["keywords"][kw_id]
	var category: String = kw["category"]
	var chip := Button.new()
	chip.text = kw["text"]
	chip.tooltip_text = kw["source"]
	chip.focus_mode = Control.FOCUS_ALL
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_font_size_override("font_size", 17)
	chip.pressed.connect(_on_chip_pressed.bind(kw_id))
	_chips[kw_id] = chip
	_style_chip(kw_id, false)
	_sections[category]["flow"].add_child(chip)
	_sections[category]["box"].visible = true
	_empty_label.visible = false


func has_keyword(kw_id: String) -> bool:
	return _chips.has(kw_id)


func get_selected() -> String:
	return _selected


func clear_selection() -> void:
	if _selected == "":
		return
	var prev: String = _selected
	_selected = ""
	if _chips.has(prev):
		_style_chip(prev, false)
	selection_changed.emit("")


func _on_chip_pressed(kw_id: String) -> void:
	var prev: String = _selected
	if prev == kw_id:
		_selected = ""
	else:
		_selected = kw_id
	if prev != "" and _chips.has(prev):
		_style_chip(prev, false)
	if _selected != "":
		_style_chip(_selected, true)
	selection_changed.emit(_selected)


func _style_chip(kw_id: String, selected: bool) -> void:
	var chip: Button = _chips[kw_id]
	var kw: Dictionary = WindmillCaseData.CASE["keywords"][kw_id]
	var base: Color = WindmillCaseData.CATEGORY_COLOR[kw["category"]]
	var text_col: Color = Color("181009") if selected else Color("f5f0e8")
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(7)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		if selected:
			sb.bg_color = base
			sb.border_color = Color("f5f0e8")
			sb.set_border_width_all(2)
		else:
			sb.bg_color = base.darkened(0.5)
			sb.border_color = base
			sb.set_border_width_all(1)
		if state == "hover":
			sb.bg_color = sb.bg_color.lightened(0.12)
		chip.add_theme_stylebox_override(state, sb)
	chip.add_theme_color_override("font_color", text_col)
	chip.add_theme_color_override("font_hover_color", text_col)
	chip.add_theme_color_override("font_pressed_color", text_col)
	chip.add_theme_color_override("font_focus_color", text_col)
