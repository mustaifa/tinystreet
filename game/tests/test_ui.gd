extends "res://tests/test_base.gd"
## v5 design system: every theme variation the screens use exists, the
## colour pairs used for text meet contrast targets, and UI keys ignore a
## second press within the debounce window.

static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)

static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func test_theme_has_every_variation() -> void:
	var t := Style.build_theme()
	for v in ["SecondaryButton", "WarmButton", "GoldButton", "ChipButton", "TileButton", "NightButton", "NightChip",
			"LanternButton", "GhostButton", "TabButton", "TabActive"]:
		check(t.has_stylebox("normal", v) and t.has_stylebox("pressed", v) and t.has_stylebox("disabled", v), "button variation " + v)
	for v in ["DisplayLabel", "TitleLabel", "HeaderLabel", "SoftLabel", "CaptionLabel", "StrongLabel",
			"NightTitle", "NightHeader", "NightLabel", "NightSoft", "NightCaption"]:
		check(t.has_font_size("font_size", v), "label variation " + v)
	for v in ["CardPanel", "SoftPanel", "HeroPanel", "TealPanel", "WarmPanel", "NightCard", "ParchmentCard"]:
		check(t.has_stylebox("panel", v), "panel variation " + v)
	# pressed keys sink: the label moves down as the edge shrinks
	var n := t.get_stylebox("normal", "Button") as StyleBoxFlat
	var p := t.get_stylebox("pressed", "Button") as StyleBoxFlat
	check(p.content_margin_top > n.content_margin_top and p.border_width_bottom < n.border_width_bottom, "tactile press")

func test_text_contrast() -> void:
	var pairs := [
		[Style.INK, Style.CREAM, 7.0], [Style.INK, Style.PAPER, 7.0], [Style.INK_SOFT, Style.CREAM, 4.5],
		[Style.INK_SOFT, Style.LINEN, 4.5], [Color.WHITE, Style.TEAL, 4.5], [Style.TEAL_DARK, Style.PAPER, 4.5],
		[Color.WHITE, Style.TERRACOTTA, 3.0], [Style.INK, Style.GOLD, 4.5], [Style.MOON, Style.NIGHT_2, 7.0],
		[Style.MOON_SOFT, Style.NIGHT_2, 4.5], [Style.INK, Style.LANTERN, 4.5], [Style.LANTERN, Style.NIGHT_2, 4.5],
		[Style.INK, Style.PARCHMENT, 7.0], [Style.INK_SOFT, Style.PARCHMENT, 4.5],
	]
	for pr in pairs:
		var r := contrast(pr[0], pr[1])
		check(r >= float(pr[2]), "contrast %s on %s is %.2f (< %.1f)" % [pr[0].to_html(false), pr[1].to_html(false), r, pr[2]])

func test_buttons_ignore_double_press() -> void:
	var b := Button.new()
	check(not UI._blocked(b), "first press goes through")
	check(UI._blocked(b), "second press inside the window is ignored")
	b.set_meta("last_press", Time.get_ticks_msec() - UI.DEBOUNCE_MS - 1)
	check(not UI._blocked(b), "a later press goes through")
	b.free()

func test_start_alignment_is_left_for_rtl_mirroring() -> void:
	# Godot mirrors LEFT to the right edge for RTL controls; "start" must be LEFT.
	eq(UI.al(), HORIZONTAL_ALIGNMENT_LEFT)
