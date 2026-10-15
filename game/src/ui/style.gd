class_name Style
extends RefCounted
## Visual identity: cream ground, teal accents, terracotta and warm wood,
## soft shadows, rounded shapes. All UI colours come from here.

const CREAM := Color("fbf4e8")
const CREAM_DEEP := Color("f2e6d2")
const PAPER := Color("fffaf2")
const INK := Color("3b2f2a")          # primary text (contrast >= 10:1 on cream)
const INK_SOFT := Color("6e5d52")     # secondary text (>= 5:1 on cream)
const TEAL := Color("1f7a72")
const TEAL_DARK := Color("165a54")
const TEAL_SOFT := Color("cfe7e3")
const TERRACOTTA := Color("c8643f")
const TERRA_SOFT := Color("f3d5c6")
const WOOD := Color("a8714a")
const WOOD_DARK := Color("7c5034")
const WOOD_LIGHT := Color("d9a87c")
const GOLD := Color("e0a93b")
const SHADOW := Color(0.23, 0.16, 0.1, 0.18)
const WARN := Color("d9822b")

const RADIUS := 22
const MIN_TOUCH := 88  # px at 720-wide base ≈ 48dp on a typical phone

static var fonts_ready := false
static var font_regular: Font
static var font_bold: Font
static var text_scale := 1.0

static func _load_fonts() -> void:
	if fonts_ready:
		return
	var arabic := load("res://assets/fonts/NotoSansArabic.ttf") as FontFile
	var base := load("res://assets/fonts/Nunito.ttf") as FontFile
	base.fallbacks = [arabic]
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	var reg := FontVariation.new()
	reg.base_font = base
	reg.variation_opentype = {wght: 600}
	var bold := FontVariation.new()
	bold.base_font = base
	bold.variation_opentype = {wght: 800}
	font_regular = reg
	font_bold = bold
	fonts_ready = true

static func fs(px: int) -> int:
	return int(round(px * text_scale))

static func box(bg: Color, radius: int = RADIUS, border: Color = Color.TRANSPARENT,
		border_w: int = 0, shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

static func build_theme() -> Theme:
	_load_fonts()
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = fs(30)
	# Buttons: primary teal
	t.set_stylebox("normal", "Button", box(TEAL))
	t.set_stylebox("hover", "Button", box(TEAL.lightened(0.08)))
	t.set_stylebox("pressed", "Button", box(TEAL_DARK, RADIUS, Color.TRANSPARENT, 0, false))
	t.set_stylebox("disabled", "Button", box(Color("b9c9c6"), RADIUS, Color.TRANSPARENT, 0, false))
	var focus := box(Color.TRANSPARENT, RADIUS, GOLD, 4, false)
	t.set_stylebox("focus", "Button", focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("f4f4f4"))
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", fs(32))
	# Secondary button variant
	t.set_type_variation("SecondaryButton", "Button")
	t.set_stylebox("normal", "SecondaryButton", box(PAPER, RADIUS, TEAL, 3))
	t.set_stylebox("hover", "SecondaryButton", box(PAPER, RADIUS, TEAL_DARK, 3))
	t.set_stylebox("pressed", "SecondaryButton", box(TEAL_SOFT, RADIUS, TEAL_DARK, 3, false))
	t.set_stylebox("disabled", "SecondaryButton", box(CREAM_DEEP, RADIUS, Color("c9bfb2"), 3, false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "SecondaryButton", TEAL_DARK)
	t.set_color("font_disabled_color", "SecondaryButton", Color("9a8f86"))
	# Warm accent variant
	t.set_type_variation("WarmButton", "Button")
	t.set_stylebox("normal", "WarmButton", box(TERRACOTTA))
	t.set_stylebox("hover", "WarmButton", box(TERRACOTTA.lightened(0.08)))
	t.set_stylebox("pressed", "WarmButton", box(TERRACOTTA.darkened(0.15), RADIUS, Color.TRANSPARENT, 0, false))
	t.set_stylebox("disabled", "WarmButton", box(Color("d8c3b8"), RADIUS, Color.TRANSPARENT, 0, false))
	# Labels
	t.set_color("font_color", "Label", INK)
	# The Arabic fallback font has tall metrics; tighten Latin line spacing.
	t.set_constant("line_spacing", "Label", -14 if not Loc.is_rtl() else -4)
	t.set_font_size("font_size", "Label", fs(30))
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font_bold)
	t.set_font_size("font_size", "TitleLabel", fs(46))
	t.set_color("font_color", "TitleLabel", INK)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", font_bold)
	t.set_font_size("font_size", "HeaderLabel", fs(34))
	t.set_type_variation("SoftLabel", "Label")
	t.set_color("font_color", "SoftLabel", INK_SOFT)
	t.set_font_size("font_size", "SoftLabel", fs(26))
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PAPER))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", box(PAPER, 28))
	t.set_type_variation("SoftPanel", "PanelContainer")
	t.set_stylebox("panel", "SoftPanel", box(CREAM_DEEP, 24, Color.TRANSPARENT, 0, false))
	t.set_stylebox("panel", "Panel", box(PAPER))
	# Sliders / checks
	t.set_stylebox("slider", "HSlider", box(CREAM_DEEP, 8, Color.TRANSPARENT, 0, false))
	t.set_stylebox("grabber_area", "HSlider", box(TEAL, 8, Color.TRANSPARENT, 0, false))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(TEAL, 8, Color.TRANSPARENT, 0, false))
	t.set_constant("separation", "HBoxContainer", 16)
	t.set_constant("separation", "VBoxContainer", 16)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_focus_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", fs(30))
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", focus)
	# Rich text
	t.set_font("normal_font", "RichTextLabel", font_regular)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", fs(28))
	t.set_font_size("bold_font_size", "RichTextLabel", fs(28))
	t.set_color("default_color", "RichTextLabel", INK)
	# Scroll bars kept slim
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.04), 6, Color.TRANSPARENT, 0, false))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.23, 0.16, 0.1, 0.25), 6, Color.TRANSPARENT, 0, false))
	return t
