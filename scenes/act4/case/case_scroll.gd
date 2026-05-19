class_name CaseScroll
extends VBoxContainer
## One page of the Casebook: prose with fill-in [slot:xxx] targets.
## Feedback is "three_tier" (one light) or "dual_light" (VALID + SOUND).
## A case that holds glows gold ("stands"); one that does not is stone-grey
## ("does not hold") — never green/red, because in this world red is the lie.

signal slot_clicked(slot_id: String)
signal state_changed

const COL_STANDS: Color = Color("c4a24a")   # gold — sound, the case stands
const COL_PARTIAL: Color = Color("9a7a34")  # dim ember — close
const COL_FALLEN: Color = Color("5a5e58")   # stone-grey — does not hold
const COL_OFF: Color = Color("38352d")      # unlit — not yet attempted

var _def: Dictionary = {}
var _fills: Dictionary = {}      # slot_id -> kw_id ("" = empty)
var _locked: bool = false
var _solved: bool = false

var _prose: RichTextLabel
var _message: Label
var _light_valid: ColorRect
var _light_sound: ColorRect
var _light_single: ColorRect

func setup(scroll_def: Dictionary) -> void:
	_def = scroll_def
	for slot_id: String in _def["slots"]:
		_fills[slot_id] = ""
	add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = _def["title"]
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("c4a24a"))
	add_child(title)

	var intro := Label.new()
	intro.text = _def["intro"]
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 16)
	intro.add_theme_color_override("font_color", Color("d8d0be"))
	add_child(intro)

	_prose = RichTextLabel.new()
	_prose.bbcode_enabled = true
	_prose.fit_content = true
	_prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prose.meta_underlined = false
	_prose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prose.custom_minimum_size = Vector2(0, 60)
	_prose.add_theme_font_size_override("normal_font_size", 19)
	_prose.add_theme_font_size_override("bold_font_size", 19)
	_prose.add_theme_color_override("default_color", Color("f5f0e8"))
	_prose.add_theme_constant_override("line_separation", 6)
	_prose.meta_clicked.connect(_on_meta_clicked)
	add_child(_prose)

	var fb := HBoxContainer.new()
	fb.add_theme_constant_override("separation", 14)
	add_child(fb)
	if _def["mode"] == "dual_light":
		_light_valid = _make_light(fb, "VALID")
		_light_sound = _make_light(fb, "SOUND")
	else:
		_light_single = _make_light(fb, "")
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", Color("d8d0be"))
	fb.add_child(_message)

	_render()
	_evaluate()


func _make_light(parent: HBoxContainer, label_text: String) -> ColorRect:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(22, 22)
	rect.color = COL_OFF
	box.add_child(rect)
	if label_text != "":
		var lbl := Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color("d8d0be"))
		box.add_child(lbl)
	parent.add_child(box)
	return rect


func set_locked(locked: bool) -> void:
	_locked = locked


func is_solved() -> bool:
	return _solved


func get_slot(slot_id: String) -> String:
	return _fills.get(slot_id, "")


func set_slot(slot_id: String, kw_id: String) -> void:
	if not _fills.has(slot_id):
		return
	_fills[slot_id] = kw_id
	_render()
	_evaluate()
	state_changed.emit()


func _on_meta_clicked(meta: Variant) -> void:
	if _locked:
		return
	var m: String = str(meta)
	if m.begins_with("slot:"):
		slot_clicked.emit(m.substr(5))


func _render() -> void:
	var body: String = _def["body"]
	for slot_id: String in _def["slots"]:
		body = body.replace("[slot:%s]" % slot_id, _slot_markup(slot_id))
	_prose.text = body


func _slot_markup(slot_id: String) -> String:
	var kw_id: String = _fills[slot_id]
	if kw_id == "":
		var cat: String = _def["slots"][slot_id]["category"]
		return "[url=slot:%s][u][color=#9a8c6a]( %s )[/color][/u][/url]" % [slot_id, cat]
	var kw: Dictionary = WindmillCaseData.CASE["keywords"][kw_id]
	var col: String = WindmillCaseData.CATEGORY_COLOR[kw["category"]].to_html(false)
	return "[url=slot:%s][b][color=#%s]%s[/color][/b][/url]" % [slot_id, col, kw["text"]]


func _evaluate() -> void:
	var total: int = _def["slots"].size()
	var filled: int = 0
	var wrong: int = 0
	var bad_category: int = 0
	for slot_id: String in _def["slots"]:
		var kw_id: String = _fills[slot_id]
		var slot: Dictionary = _def["slots"][slot_id]
		if kw_id == "":
			wrong += 1
			continue
		filled += 1
		if not (kw_id in slot["accepts"]):
			wrong += 1
		var kw: Dictionary = WindmillCaseData.CASE["keywords"][kw_id]
		if kw["category"] != slot["category"]:
			bad_category += 1

	if _def["mode"] == "dual_light":
		var all_filled: bool = filled == total
		var is_valid: bool = all_filled and bad_category == 0
		var is_sound: bool = all_filled and wrong == 0
		_light_valid.color = COL_STANDS if is_valid else COL_FALLEN
		_light_sound.color = COL_STANDS if is_sound else COL_FALLEN
		_solved = is_valid and is_sound
		if not all_filled:
			_message.text = "Place a word in every slot."
		elif is_sound:
			_message.text = "The case stands — valid, and sound."
		elif is_valid:
			_message.text = "Valid, but not yet sound — the right kinds of word are placed; now find the true ones."
		else:
			_message.text = "Not valid — a slot holds the wrong kind of word."
	else:
		if filled < total:
			_light_single.color = COL_OFF
			_message.text = "Place a word in every slot (%d of %d done)." % [filled, total]
			_solved = false
		elif wrong == 0:
			_light_single.color = COL_STANDS
			_message.text = "Every name is right. The page is set."
			_solved = true
		elif wrong <= 2:
			_light_single.color = COL_PARTIAL
			_message.text = "Close — one or two names are wrong. Read the wreck again."
			_solved = false
		else:
			_light_single.color = COL_FALLEN
			_message.text = "Several names are wrong. Look again."
			_solved = false
