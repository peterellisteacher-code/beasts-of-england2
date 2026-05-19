## Stealth HUD for Act 1 — replaces the hearts HUD (stealth has no health).
## Shows the "COMRADES GATHERED" counter, a detection bar, a HIDDEN tag, and
## a transient caption line for tutorial beats, caught-captions, and the finale.
##
## Spec: active.md §4 "ui/stealth_hud.gd".
class_name StealthHUD
extends CanvasLayer

# =============================================================================
# Constants — propaganda palette
# =============================================================================

const COL_WHEAT: Color      = Color(0.769, 0.639, 0.290)   # wheat-gold
const COL_BONE: Color       = Color(0.941, 0.910, 0.788)   # bone-white
const COL_RED: Color        = Color(0.55, 0.08, 0.08)      # propaganda-red
const COL_ALERT: Color      = Color(0.85, 0.2, 0.2)

const FONT_SIZE_COMRADES: int = 22
const FONT_SIZE_HINT: int     = 20
const FONT_SIZE_HIDDEN: int   = 16

## Seconds the tutorial hint is shown before fading.
const DEFAULT_CAPTION_SECONDS: float = 5.0

# =============================================================================
# @onready references
# =============================================================================

@onready var _comrades_label: Label  = $Margin/TopLeft/ComradesLabel
@onready var _hidden_label: Label    = $Margin/TopLeft/HiddenLabel
@onready var _detect_bar: ColorRect  = $Margin/TopLeft/DetectBar
@onready var _detect_fill: ColorRect = $Margin/TopLeft/DetectBar/DetectFill
@onready var _alert_icon: Label      = $Margin/TopLeft/AlertIcon
@onready var _caption: Label         = $CaptionAnchor/Caption

# =============================================================================
# Private state
# =============================================================================

var _caption_tween: Tween = null

# =============================================================================
# Built-in virtual methods
# =============================================================================

func _ready() -> void:
	layer = 20
	# Join the group SecretScroll looks the HUD up by for its pickup caption.
	add_to_group(&"stealth_hud")
	# HUD stays responsive when tree is paused (question panel).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_comrades_label.add_theme_font_size_override("font_size", FONT_SIZE_COMRADES)
	_comrades_label.add_theme_color_override("font_color", COL_WHEAT)
	_hidden_label.add_theme_font_size_override("font_size", FONT_SIZE_HIDDEN)
	_hidden_label.add_theme_color_override("font_color", COL_BONE)
	_caption.add_theme_font_size_override("font_size", FONT_SIZE_HINT)
	_caption.add_theme_color_override("font_color", COL_BONE)
	_alert_icon.add_theme_color_override("font_color", COL_ALERT)
	set_comrades(0)
	set_detection(0.0)
	set_hidden(false)
	_caption.modulate.a = 0.0

# =============================================================================
# Public API
# =============================================================================

## Update the comrades-gathered counter display.
func set_comrades(n: int) -> void:
	_comrades_label.text = "COMRADES GATHERED   %d / 4" % n


## Update the detection indicator (0.0 = none, 1.0 = caught).
func set_detection(f: float) -> void:
	var clamped: float = clampf(f, 0.0, 1.0)
	if clamped <= 0.0:
		_detect_bar.visible = false
		_alert_icon.visible = false
		return
	_detect_bar.visible = true
	_detect_fill.size.x = _detect_bar.size.x * clamped
	# Colour shifts orange → red as detection rises.
	var t: float = clamped
	_detect_fill.color = Color(0.75 + t * 0.25, 0.55 - t * 0.45, 0.1 - t * 0.08)
	_alert_icon.visible = clamped >= 0.6


## Show or hide the HIDDEN status tag.
func set_hidden(is_hidden: bool) -> void:
	_hidden_label.text = "HIDDEN" if is_hidden else ""


## Show a transient caption for `seconds`. A new call replaces any running one.
func show_caption(text: String, seconds: float = DEFAULT_CAPTION_SECONDS) -> void:
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption.text = text
	_caption.modulate.a = 1.0
	_caption_tween = create_tween()
	_caption_tween.tween_interval(seconds)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.8)
