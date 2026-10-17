class_name Style
extends RefCounted
## Design system: "an inviting miniature café street".
## Every colour, type size, spacing step, radius and motion timing used by the
## UI comes from here, and the shared Theme below turns them into reusable
## variations (buttons, cards, labels, tabs, chips). Screens pick a variation
## by name; they never build their own colours. See docs/DESIGN_SYSTEM.md.

# ------------------------------------------------------------------ palette
# Static vars (not consts) so a skin can override any token by name
# (ArtSkin._apply_colors). Derived tokens (SUCCESS = TEAL) are overridden separately.
# Ground and paper
static var CREAM := Color("fbf4e8")        # screen background
static var CREAM_DEEP := Color("f2e5d0")   # recessed areas, empty tracks
static var LINEN := Color("f7eddc")        # soft panels
static var PAPER := Color("fffaf3")        # cards, dialogs
static var PAPER_EDGE := Color("eadcc6")   # hairline borders on paper
# Text: rich espresso (contrast on cream: INK 12.6:1, INK_SOFT 6.1:1)
static var INK := Color("3a2a22")
static var INK_SOFT := Color("6b584c")
static var INK_FAINT := Color("9c8a7c")    # decorative only, never for body text
# Teal: primary actions and "done"
static var TEAL := Color("1f7a72")
static var TEAL_DARK := Color("165a54")
static var TEAL_EDGE := Color("0f4540")
static var TEAL_SOFT := Color("d3ebe6")
# Coral (restrained): restoration, warm calls to action
static var TERRACOTTA := Color("c95f3f")
static var CORAL_EDGE := Color("94412a")
static var TERRA_SOFT := Color("f6dccf")
# Gold: stars, tokens, highlights
static var GOLD := Color("e3a83a")
static var GOLD_EDGE := Color("a8761b")
static var GOLD_SOFT := Color("f8e8c4")
# Wood (board furniture)
static var WOOD := Color("a8714a")
static var WOOD_DARK := Color("7c5034")
static var WOOD_LIGHT := Color("d9a87c")
# Semantic states
static var SUCCESS := TEAL
static var WARN := Color("cf7a22")
static var DANGER := Color("b8442c")
static var LOCKED := Color("b3a596")
static var SHADOW := Color(0.23, 0.14, 0.08, 0.16)
# Midnight Ledger: refined midnight blue with warm lantern light
static var NIGHT := Color("161e36")
static var NIGHT_2 := Color("1f2a49")
static var NIGHT_3 := Color("2b3860")
static var NIGHT_LINE := Color("3e4c7a")
static var MOON := Color("f3efe4")         # text on night (contrast 13:1)
static var MOON_SOFT := Color("bcc3dc")    # secondary text on night (7.4:1)
static var LANTERN := Color("f2b84b")
static var LANTERN_EDGE := Color("b07c1e")
static var PARCHMENT := Color("f6eedb")
static var PARCHMENT_EDGE := Color("dccaa4")
# Bakery accent
static var ROSE := Color("e7a3a8")
static var ROSE_SOFT := Color("f8e1df")

# ------------------------------------------------------------------ type scale (px at 720-wide base)
const T_DISPLAY := 52
const T_TITLE := 42
const T_HEADING := 33
const T_BODY := 29
const T_SMALL := 25
const T_CAPTION := 21

# ------------------------------------------------------------------ spacing, radii, sizes
const S1 := 8
const S2 := 12
const S3 := 16
const S4 := 24
const S5 := 32
const RADIUS := 24
const R_SM := 14
const R_LG := 32
const EDGE := 6          # tactile bottom edge on buttons
const MIN_TOUCH := 88    # px at 720-wide base ≈ 48dp on a typical phone
const CHIP := 88         # round icon button

# ------------------------------------------------------------------ motion (seconds; reduced motion collapses them)
const M_FAST := 0.10     # press feedback
const M_BASE := 0.18     # screen transitions, small pops
const M_SLOW := 0.32     # celebrations, card entrances

static var fonts_ready := false
static var font_regular: Font
static var font_bold: Font
static var font_black: Font
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
	var black := FontVariation.new()
	black.base_font = base
	black.variation_opentype = {wght: 900}
	font_regular = reg
	font_bold = bold
	font_black = black
	fonts_ready = true

static func fs(px: int) -> int:
	return int(round(px * text_scale))

## A rounded box. `shadow` adds the soft warm drop shadow used by cards.
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
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

## Tactile key: a face with a darker bottom edge. Pressed keys sink: the edge
## shrinks and the label moves down by the same amount.
static func key(face: Color, edge: Color, pressed: bool = false, border: Color = Color.TRANSPARENT,
		radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	var e := 2 if pressed else EDGE
	sb.border_color = edge
	sb.border_width_bottom = e
	if border != Color.TRANSPARENT:
		sb.border_color = border
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = e
		# the edge keeps its darker tone even with a border
		sb.border_blend = false
	if not pressed:
		sb.shadow_color = Color(SHADOW, 0.12)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12 + (EDGE - e)
	sb.content_margin_bottom = 12 + e
	return sb

static func _button_variant(t: Theme, name: String, face: Color, edge: Color, text: Color,
		border: Color = Color.TRANSPARENT, radius: int = RADIUS) -> void:
	if name != "Button":
		t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, key(face, edge, false, border, radius))
	t.set_stylebox("hover", name, key(face.lightened(0.04), edge, false, border, radius))
	t.set_stylebox("pressed", name, key(face.darkened(0.07), edge, true, border, radius))
	t.set_stylebox("hover_pressed", name, key(face.darkened(0.07), edge, true, border, radius))
	var ground := NIGHT if name.begins_with("Night") else CREAM_DEEP
	var dis := key(face.lerp(ground, 0.55), edge.lerp(ground, 0.6), false, Color.TRANSPARENT, radius)
	dis.shadow_size = 0
	t.set_stylebox("disabled", name, dis)
	t.set_stylebox("focus", name, box(Color.TRANSPARENT, radius + 4, GOLD, 4, false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, name, text)
	t.set_color("font_disabled_color", name, Color(text, 0.45) if name.begins_with("Night") else (text.lerp(INK_SOFT, 0.6) if text != Color.WHITE else Color(1, 1, 1, 0.85)))
	t.set_font("font", name, font_bold)
	t.set_font_size("font_size", name, fs(31))

static func build_theme() -> Theme:
	_load_fonts()
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = fs(T_BODY)
	# --- buttons (all tactile keys)
	_button_variant(t, "Button", TEAL, TEAL_EDGE, Color.WHITE)
	_button_variant(t, "SecondaryButton", PAPER, PAPER_EDGE.darkened(0.12), TEAL_DARK, PAPER_EDGE)
	_button_variant(t, "WarmButton", TERRACOTTA, CORAL_EDGE, Color.WHITE)
	_button_variant(t, "GoldButton", GOLD, GOLD_EDGE, INK)
	_button_variant(t, "ChipButton", PAPER, PAPER_EDGE.darkened(0.12), TEAL_DARK, PAPER_EDGE, 44)
	_button_variant(t, "TileButton", PAPER, PAPER_EDGE.darkened(0.12), INK, PAPER_EDGE, 28)
	_button_variant(t, "NightButton", NIGHT_3, NIGHT, MOON, NIGHT_LINE)
	_button_variant(t, "NightChip", NIGHT_3, NIGHT, MOON, NIGHT_LINE, 44)
	_button_variant(t, "LanternButton", LANTERN, LANTERN_EDGE, INK)
	# Ghost: text-only tertiary action, still a full-size touch target
	t.set_type_variation("GhostButton", "Button")
	for s in ["normal", "hover", "disabled"]:
		var g := box(Color.TRANSPARENT, RADIUS, Color.TRANSPARENT, 0, false)
		t.set_stylebox(s, "GhostButton", g)
	t.set_stylebox("pressed", "GhostButton", box(Color(TEAL, 0.10), RADIUS, Color.TRANSPARENT, 0, false))
	t.set_stylebox("hover_pressed", "GhostButton", box(Color(TEAL, 0.10), RADIUS, Color.TRANSPARENT, 0, false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "GhostButton", TEAL_DARK)
	t.set_color("font_disabled_color", "GhostButton", INK_FAINT)
	t.set_font("font", "GhostButton", font_bold)
	t.set_font_size("font_size", "GhostButton", fs(28))
	# Tabs (segmented control)
	_button_variant(t, "TabButton", Color(PAPER, 0.0), Color(PAPER, 0.0), INK_SOFT, Color.TRANSPARENT, 20)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := t.get_stylebox(s, "TabButton") as StyleBoxFlat
		sb.shadow_size = 0
		sb.border_width_bottom = 0
		sb.content_margin_bottom = 10
		sb.content_margin_top = 10
	_button_variant(t, "TabActive", TEAL, TEAL_EDGE, Color.WHITE, Color.TRANSPARENT, 20)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb2 := t.get_stylebox(s, "TabActive") as StyleBoxFlat
		sb2.border_width_bottom = 3
		sb2.content_margin_bottom = 10
		sb2.content_margin_top = 10
	t.set_font_size("font_size", "TabButton", fs(26))
	t.set_font_size("font_size", "TabActive", fs(26))
	# --- labels
	t.set_color("font_color", "Label", INK)
	# The Arabic fallback font has tall metrics; tighten Latin line spacing.
	t.set_constant("line_spacing", "Label", -12 if not Loc.is_rtl() else -4)
	t.set_font_size("font_size", "Label", fs(T_BODY))
	_label(t, "DisplayLabel", font_black, T_DISPLAY, INK)
	_label(t, "TitleLabel", font_black, T_TITLE, INK)
	_label(t, "HeaderLabel", font_bold, T_HEADING, INK)
	_label(t, "SoftLabel", font_regular, T_SMALL, INK_SOFT)
	_label(t, "CaptionLabel", font_bold, T_CAPTION, INK_SOFT)
	_label(t, "StrongLabel", font_bold, T_BODY, INK)
	_label(t, "NightTitle", font_black, T_TITLE, MOON)
	_label(t, "NightHeader", font_bold, T_HEADING, MOON)
	_label(t, "NightLabel", font_regular, T_BODY, MOON)
	_label(t, "NightSoft", font_regular, T_SMALL, MOON_SOFT)
	_label(t, "NightCaption", font_bold, T_CAPTION, LANTERN)
	# --- panels
	t.set_stylebox("panel", "PanelContainer", card_box(PAPER))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", card_box(PAPER))
	t.set_type_variation("SoftPanel", "PanelContainer")
	t.set_stylebox("panel", "SoftPanel", box(LINEN, RADIUS, PAPER_EDGE, 2, false))
	t.set_type_variation("HeroPanel", "PanelContainer")
	t.set_stylebox("panel", "HeroPanel", card_box(PAPER, R_LG))
	t.set_type_variation("TealPanel", "PanelContainer")
	t.set_stylebox("panel", "TealPanel", box(TEAL_SOFT, RADIUS, Color(TEAL, 0.25), 2, false))
	t.set_type_variation("WarmPanel", "PanelContainer")
	t.set_stylebox("panel", "WarmPanel", box(TERRA_SOFT, RADIUS, Color(TERRACOTTA, 0.25), 2, false))
	t.set_type_variation("NightCard", "PanelContainer")
	var nc := box(NIGHT_2, RADIUS, NIGHT_LINE, 2, true)
	nc.shadow_color = Color(0, 0, 0, 0.35)
	t.set_stylebox("panel", "NightCard", nc)
	t.set_type_variation("ParchmentCard", "PanelContainer")
	var pc := box(PARCHMENT, 18, PARCHMENT_EDGE, 2, true)
	pc.shadow_color = Color(0, 0, 0, 0.3)
	t.set_stylebox("panel", "ParchmentCard", pc)
	t.set_stylebox("panel", "Panel", card_box(PAPER))
	# --- sliders
	var track := box(CREAM_DEEP, 10, Color.TRANSPARENT, 0, false)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(TEAL, 10, Color.TRANSPARENT, 0, false)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _knob_texture()
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_constant("separation", "HBoxContainer", S3)
	t.set_constant("separation", "VBoxContainer", S3)
	# --- rich text
	t.set_font("normal_font", "RichTextLabel", font_regular)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", fs(28))
	t.set_font_size("bold_font_size", "RichTextLabel", fs(28))
	t.set_color("default_color", "RichTextLabel", INK)
	# --- scroll bars: slim and warm, never a grey slab
	var sc := box(Color(0, 0, 0, 0), 6, Color.TRANSPARENT, 0, false)
	sc.content_margin_left = 3
	sc.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sc)
	t.set_stylebox("scroll_focus", "VScrollBar", sc)
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var gr := box(Color(INK_SOFT, 0.28 if s == "grabber" else 0.45), 6, Color.TRANSPARENT, 0, false)
		gr.content_margin_left = 3
		gr.content_margin_right = 3
		t.set_stylebox(s, "VScrollBar", gr)
	return t

static func _label(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, fs(size))
	t.set_color("font_color", name, color)

## Paper card: hairline edge, soft warm shadow.
static func card_box(bg: Color, radius: int = 28) -> StyleBoxFlat:
	var sb := box(bg, radius, PAPER_EDGE, 2, true)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	return sb

static var _knob: ImageTexture
static func _knob_texture() -> ImageTexture:
	if _knob:
		return _knob
	var n := 44
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= 20.5:
				col = TEAL_DARK
			if d <= 17.0:
				col = PAPER
			if d > 19.5 and d <= 20.5:
				col.a = 20.5 - d
			img.set_pixel(x, y, col)
	_knob = ImageTexture.create_from_image(img)
	return _knob
