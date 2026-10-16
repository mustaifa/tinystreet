class_name UI
extends RefCounted
## Shared components for code-built layouts. Every screen composes these, so
## buttons, chips, pills, tags, progress bars, list rows and headers look and
## behave the same everywhere (see docs/DESIGN_SYSTEM.md).
##
## Buttons give immediate press feedback (the key sinks and scales slightly),
## and ignore a second press within DEBOUNCE_MS or while a screen transition
## is running, so double taps never trigger an action twice.

const DEBOUNCE_MS := 350

## Start-of-line alignment. Godot already mirrors LEFT to the right edge for
## controls with an RTL layout, so "start" is always LEFT here.
static func al() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT

static func label(text: String, variation: String = "", align: int = HORIZONTAL_ALIGNMENT_CENTER, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## True when a press should be ignored (double tap, or mid-transition).
static func _blocked(b: Control) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(b.get_meta("last_press", -100000)) < DEBOUNCE_MS:
		return true
	if App.main and App.main.has_method("input_locked") and App.main.input_locked():
		return true
	b.set_meta("last_press", now)
	return false

## Press feedback: a quick sink-and-scale, skipped with reduced motion.
static func press_feedback(b: Control) -> void:
	b.button_down.connect(func():
		if App.reduced_motion():
			return
		b.pivot_offset = b.size / 2
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.965, 0.965), Style.M_FAST).set_ease(Tween.EASE_OUT))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, Style.M_BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

static func _wire(b: Button, cb: Callable, sound: String = "tap") -> void:
	b.focus_mode = Control.FOCUS_NONE
	press_feedback(b)
	b.pressed.connect(func():
		if _blocked(b):
			return
		App.audio.play(sound)
		App.haptic(10)
		cb.call())

static func button(text: String, cb: Callable, variation: String = "", min_h: int = Style.MIN_TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wire(b, cb)
	return b

## A button with a drawn icon before its text (icon mirrors in RTL through
## the container's layout direction). `sub` adds a smaller second line.
static func icon_text_button(glyph: String, text: String, cb: Callable, variation: String = "",
		min_h: int = Style.MIN_TOUCH, sub: String = "", icon_size: int = 44) -> Button:
	var b := Button.new()
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	_wire(b, cb)
	var fg: Color = _text_color(variation)
	var row := hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_bottom = -Style.EDGE
	if glyph != "" and sub != "":
		# hero buttons lead with the icon in a light medallion
		var face := Color.WHITE if fg == Color.WHITE else Style.TEAL_SOFT
		var ink: Color = Style.TEAL if fg == Color.WHITE else fg
		if variation == "WarmButton":
			ink = Style.TERRACOTTA
		var m := medallion(glyph, face, ink, icon_size + 20)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(m)
	elif glyph != "":
		var g := Glyph.new()
		g.kind = glyph
		# coins keep their gold so they read as currency on any key
		g.color = Style.GOLD if glyph == "coin" else fg
		g.custom_minimum_size = Vector2(icon_size, icon_size)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(g)
	var col := vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := label(text, "", HORIZONTAL_ALIGNMENT_CENTER if sub == "" else al(), false)
	t.add_theme_font_override("font", Style.font_bold)
	t.add_theme_font_size_override("font_size", Style.fs(31) if min_h < 110 else Style.fs(34))
	t.add_theme_color_override("font_color", fg)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sub != "":
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(t)
	if sub != "":
		var s := label(sub, "", al(), false)
		s.add_theme_font_size_override("font_size", Style.fs(Style.T_CAPTION))
		s.add_theme_color_override("font_color", Color(fg, 0.85))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(s)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	b.add_child(row)
	b.set_meta("label", t)
	return b

static func _text_color(variation: String) -> Color:
	match variation:
		"", "Button", "WarmButton", "TabActive": return Color.WHITE
		"GoldButton", "LanternButton", "TileButton": return Style.INK
		"NightButton", "NightChip": return Style.MOON
	return Style.TEAL_DARK

## Round icon button (88 px) with an optional count badge. Returns the button.
static func chip(glyph: String, cb: Callable, variation: String = "ChipButton", size: int = Style.CHIP,
		badge_n: int = 0, tip: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tip
	_wire(b, cb)
	var g := Glyph.new()
	g.kind = glyph
	g.color = _text_color(variation)
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.offset_bottom = -Style.EDGE / 2.0
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	b.set_meta("glyph", g)
	if badge_n > 0:
		badge(b, badge_n)
	return b

## Legacy-compatible icon button: chip plus an optional caption below.
## Returns the wrapper; the Button is in meta "button".
static func icon_button(glyph: String, caption: String, cb: Callable, variation: String = "SecondaryButton", size: int = 96) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var chip_var := "ChipButton" if variation in ["SecondaryButton", "ChipButton"] else variation
	var b := chip(glyph, cb, chip_var, size, 0, caption)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	if caption != "":
		var l := label(caption, "CaptionLabel")
		v.add_child(l)
	v.set_meta("button", b)
	return v

## Count bubble (or a plain dot when n < 0) on the top corner of a control.
static func badge(on: Control, n: int) -> Control:
	var b := Bubble.new()
	b.n = n
	var d := 24 if n < 0 else (36 if n < 10 else 44)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -d + 6
	b.offset_right = 6
	b.offset_top = -6
	b.offset_bottom = 30 if n >= 0 else 18
	if Loc.is_rtl():
		b.anchor_left = 0.0
		b.anchor_right = 0.0
		b.offset_left = -6
		b.offset_right = d - 6
	on.add_child(b)
	return b

## Rounded pill with an icon and a value, e.g. the token count.
static func pill(glyph: String, text: String, glyph_color: Color = Style.GOLD, variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var night := variation == "night"
	var sb := Style.box(Style.NIGHT_3 if night else Style.PAPER, 40, Style.NIGHT_LINE if night else Style.PAPER_EDGE, 2, not night)
	sb.content_margin_left = 10
	sb.content_margin_right = 20
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := hbox(8)
	if glyph != "":
		var g := Glyph.new()
		g.kind = glyph
		g.color = glyph_color
		g.custom_minimum_size = Vector2(48, 48)
		h.add_child(g)
	var l := label(text, "StrongLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	l.add_theme_font_size_override("font_size", Style.fs(30))
	if night:
		l.add_theme_color_override("font_color", Style.MOON)
	h.add_child(l)
	p.add_child(h)
	p.set_meta("label", l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Small rounded tag: "NEW", "Ready", "Lesson", "Owned".
static func tag(text: String, bg: Color = Style.GOLD_SOFT, fg: Color = Style.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.font_bold)
	l.add_theme_font_size_override("font_size", Style.fs(20))
	l.add_theme_color_override("font_color", fg)
	var sb := Style.box(bg, 14, Color.TRANSPARENT, 0, false)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Rounded progress bar (drawn; mirrors in RTL).
static func progress(v: float, goal: float, color: Color = Style.TEAL, h: int = 18, track: Color = Color(Style.INK_SOFT, 0.14)) -> Control:
	var b := ProgressPill.new()
	b.value = v
	b.goal = goal
	b.fill = color
	b.track = track
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## Progress bar with a "v/goal" caption.
static func progress_row(v: int, goal: int, color: Color = Style.TEAL) -> Control:
	var wrap := hbox(12)
	wrap.add_child(progress(v, goal, color))
	wrap.add_child(label("%d/%d" % [v, goal], "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
	return wrap

## Circle medallion with an icon: list-row and card leaders.
static func medallion(glyph: String, bg: Color = Style.TEAL_SOFT, fg: Color = Style.TEAL_DARK, size: int = 72) -> Control:
	var m := Medallion.new()
	m.kind = glyph
	m.bg = bg
	m.fg = fg
	m.custom_minimum_size = Vector2(size, size)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m

## Section heading with an optional leading icon.
static func section(text: String, glyph: String = "", variation: String = "HeaderLabel", color: Color = Style.TEAL_DARK) -> Control:
	var h := hbox(10)
	if glyph != "":
		var g := Glyph.new()
		g.kind = glyph
		g.color = color
		g.custom_minimum_size = Vector2(40, 40)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(g)
	var l := label(text, variation, al(), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h

## A list row: leader (medallion), title + subtitle, optional trailing control.
static func row(leader: Control, title: String, sub: String = "", trailing: Control = null,
		title_var: String = "StrongLabel", sub_var: String = "SoftLabel") -> HBoxContainer:
	var r := hbox(16)
	if leader:
		r.add_child(leader)
	var v := vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(label(title, title_var, al()))
	if sub != "":
		v.add_child(label(sub, sub_var, al()))
	r.add_child(v)
	if trailing:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(trailing)
	return r

static func vbox(sep: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h: int = 0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m

static func card(child: Control, variation: String = "CardPanel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	p.add_child(child)
	return p

## Vertical scroll area. A small side margin keeps card shadows and the slim
## scroll bar from touching the content.
static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m := margin(child, 4, 4, 14, 24)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(m)
	return s

## Standard screen header: back chip, title, and an optional trailing control
## (a pill or chip); a balancing spacer keeps the title centred otherwise.
static func header(title: String, on_back: Callable, trailing: Control = null, night: bool = false) -> HBoxContainer:
	var h := hbox(12)
	var back := chip("back", on_back, "NightChip" if night else "ChipButton")
	h.add_child(back)
	var t := label(title, "NightTitle" if night else "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	fit_font(t, 720 - 2 * Style.CHIP - 120 - (110 if trailing else 0), Style.T_TITLE, 28)
	h.add_child(t)
	if trailing:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(trailing)
	else:
		h.add_child(spacer(0))
		h.get_child(2).custom_minimum_size = Vector2(Style.CHIP, 0)
	return h

## Shrinks a one-line label's font until the text fits `width` (down to `min_px`).
static func fit_font(l: Label, width: float, max_px: int, min_px: int) -> void:
	var f: Font = Style.font_black if l.theme_type_variation in ["TitleLabel", "NightTitle", "DisplayLabel"] else Style.font_bold
	var px := max_px
	while px > min_px and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(px)).x > width:
		px -= 2
	l.add_theme_font_size_override("font_size", Style.fs(px))

static func stars_text(n: int, of: int = 3) -> String:
	var s := ""
	for i in of:
		s += "★" if i < n else "☆"
	return s

## Drawn star row: filled gold stars, empty ones as soft outlines.
static func star_row(n: int, size: int = 40, of: int = 3) -> HBoxContainer:
	var h := hbox(4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in of:
		var g := Glyph.new()
		g.kind = "star" if i < n else "star_empty"
		g.color = Style.GOLD if i < n else Color(Style.INK_SOFT, 0.45)
		g.custom_minimum_size = Vector2(size, size)
		h.add_child(g)
	return h

## Two-to-four options as a segmented control. `on_pick(value)`.
static func segmented(options: Array, current: String, on_pick: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Style.box(Style.CREAM_DEEP, 26, Color.TRANSPARENT, 0, false)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := hbox(6)
	for o in options:
		var val: String = o[0]
		var b := button(o[1], func(): on_pick.call(val), "TabActive" if val == current else "TabButton", 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	p.add_child(h)
	return p

class ProgressPill extends Control:
	var value := 0.0
	var goal := 1.0
	var fill := Style.TEAL
	var track := Color(Style.INK_SOFT, 0.14)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := int(size.y / 2)
		draw_style_box(Style.box(track, r, Color.TRANSPARENT, 0, false), Rect2(Vector2.ZERO, size))
		var k := clampf(value / maxf(goal, 0.001), 0.0, 1.0)
		if k <= 0.0:
			return
		var w := maxf(size.y, size.x * k)
		var x := size.x - w if Loc.is_rtl() else 0.0
		draw_style_box(Style.box(fill, r, Color.TRANSPARENT, 0, false), Rect2(x, 0, w, size.y))
		# a soft highlight along the top of the fill
		draw_line(Vector2(x + r, size.y * 0.3), Vector2(x + w - r, size.y * 0.3), Color(1, 1, 1, 0.25), maxf(2.0, size.y * 0.16), true)

class Medallion extends Control:
	var kind := "star"
	var bg := Style.TEAL_SOFT
	var fg := Style.TEAL_DARK

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		draw_circle(c + Vector2(0, 2), r, Color(Style.SHADOW, 0.10))
		draw_circle(c, r, bg)
		Glyph.paint(self, kind, Rect2(c - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), fg)

class Bubble extends Control:
	var n := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var r := Rect2(Vector2.ZERO, Vector2(size.x, h))
		var sb := Style.box(Style.TERRACOTTA, int(h / 2), Style.PAPER, 3, false)
		draw_style_box(sb, r)
		if n >= 0:
			draw_string(Style.font_bold, Vector2(0, h / 2 + 8), str(n), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)

## An On/Off switch. The word "On"/"Off" sits inside the track, so the state
## never depends on colour alone. `on_change(bool)`.
static func switch(value: bool, on_change: Callable) -> Button:
	var s := Switch.new()
	s.toggle_mode = true
	s.button_pressed = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(132, Style.MIN_TOUCH)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.toggled.connect(func(on: bool):
		App.audio.play("tap")
		App.haptic(10)
		s.animate()
		on_change.call(on))
	return s

class Switch extends Button:
	var _k := -1.0

	func _ready() -> void:
		flat = true
		_k = 1.0 if button_pressed else 0.0
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func animate() -> void:
		var target := 1.0 if button_pressed else 0.0
		if App.reduced_motion():
			_k = target
			queue_redraw()
			return
		var tw := create_tween()
		tw.tween_method(func(v): _k = v; queue_redraw(), _k, target, Style.M_BASE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var h := 56.0
		var w := 120.0
		var r := Rect2((size.x - w) / 2, (size.y - h) / 2, w, h)
		var on := _k >= 0.5
		var track := Style.TEAL.lerp(Style.CREAM_DEEP, 1.0 - _k)
		draw_style_box(Style.box(track, int(h / 2), Style.PAPER_EDGE if not on else Style.TEAL_EDGE, 2, false), r)
		var rtl := Loc.is_rtl()
		var kx := lerpf(r.position.x + h / 2, r.end.x - h / 2, _k if not rtl else 1.0 - _k)
		draw_circle(Vector2(kx, r.get_center().y + 2), h / 2 - 5, Color(0, 0, 0, 0.12))
		draw_circle(Vector2(kx, r.get_center().y), h / 2 - 5, Style.PAPER)
		var word := Loc.t("on") if on else Loc.t("off")
		var tx := r.position.x + 8 if (on != rtl) else r.position.x + h - 4
		draw_string(Style.font_bold, Vector2(tx, r.get_center().y + 8), word, HORIZONTAL_ALIGNMENT_CENTER, w - h - 4, Style.fs(21),
			Color.WHITE if on else Style.INK_SOFT)
