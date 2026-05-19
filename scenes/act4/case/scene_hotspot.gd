class_name SceneHotspot
extends Button
## An examination mark on a windmill-case room — a gold surveyor's bracket
## that frames a point of evidence. It breathes while unexamined and dims to
## a flat frame once opened. Lives on the case-file CanvasLayer so the storm
## CanvasModulate cannot darken it.

const COL_GOLD: Color = Color("c4a24a")
const COL_DIM: Color = Color(0.5, 0.46, 0.36, 0.7)
const MARK_SIZE: float = 46.0
const ARM: float = 12.0

var hotspot_id: String = ""

var _phase: float = 0.0
var _visited: bool = false

func setup(id: String, title: String) -> void:
	hotspot_id = id
	tooltip_text = title


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	size = Vector2(MARK_SIZE, MARK_SIZE)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_phase = randf() * TAU


func _process(delta: float) -> void:
	if _visited:
		return
	_phase += delta * 2.0
	queue_redraw()


func mark_visited() -> void:
	if _visited:
		return
	_visited = true
	queue_redraw()


func _draw() -> void:
	# A soft dark disc keeps the gold bracket legible over bright sky or dark stone.
	draw_circle(Vector2(MARK_SIZE * 0.5, MARK_SIZE * 0.5), MARK_SIZE * 0.46, Color(0.05, 0.04, 0.03, 0.5))
	var col: Color = COL_DIM if _visited else COL_GOLD
	var w: float = 2.0 if _visited else 3.0
	var inset: float = 5.0
	if not _visited:
		inset = 5.0 + 3.0 * (0.5 + 0.5 * sin(_phase))
	var lo: float = inset
	var hi: float = MARK_SIZE - inset
	# Four corner brackets — a viewfinder framing the point of evidence.
	draw_line(Vector2(lo, lo), Vector2(lo + ARM, lo), col, w)
	draw_line(Vector2(lo, lo), Vector2(lo, lo + ARM), col, w)
	draw_line(Vector2(hi, lo), Vector2(hi - ARM, lo), col, w)
	draw_line(Vector2(hi, lo), Vector2(hi, lo + ARM), col, w)
	draw_line(Vector2(lo, hi), Vector2(lo + ARM, hi), col, w)
	draw_line(Vector2(lo, hi), Vector2(lo, hi - ARM), col, w)
	draw_line(Vector2(hi, hi), Vector2(hi - ARM, hi), col, w)
	draw_line(Vector2(hi, hi), Vector2(hi, hi - ARM), col, w)
	if not _visited:
		draw_circle(Vector2(MARK_SIZE * 0.5, MARK_SIZE * 0.5), 2.5, col)
	if has_focus():
		draw_rect(Rect2(2.0, 2.0, MARK_SIZE - 4.0, MARK_SIZE - 4.0), Color("f5f0e8"), false, 2.0)
