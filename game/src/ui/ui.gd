class_name UI
extends RefCounted
## Small helpers for code-built layouts.

static func label(text: String, variation: String = "", align: int = HORIZONTAL_ALIGNMENT_CENTER, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable, variation: String = "", min_h: int = Style.MIN_TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		App.audio.play("tap")
		App.haptic(10)
		cb.call())
	return b

## Square icon button with a drawn glyph and optional caption below.
static func icon_button(glyph: String, caption: String, cb: Callable, variation: String = "SecondaryButton", size: int = 96) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = caption
	var g := Glyph.new()
	g.kind = glyph
	g.color = Style.TEAL_DARK if variation == "SecondaryButton" else Color.WHITE
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	b.pressed.connect(func():
		App.audio.play("tap")
		App.haptic(10)
		cb.call())
	v.add_child(b)
	if caption != "":
		var l := label(caption, "SoftLabel")
		l.add_theme_font_size_override("font_size", Style.fs(22))
		v.add_child(l)
	v.set_meta("button", b)
	return v

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

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

## Standard screen header: back glyph + title.
static func header(title: String, on_back: Callable) -> HBoxContainer:
	var h := hbox(12)
	var back := icon_button("back", "", on_back, "SecondaryButton", 88)
	h.add_child(back)
	var t := label(title, "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	h.add_child(t)
	h.add_child(spacer(0)) # balance
	h.get_child(2).custom_minimum_size = Vector2(88, 0)
	return h

static func stars_text(n: int, of: int = 3) -> String:
	var s := ""
	for i in of:
		s += "★" if i < n else "☆"
	return s
