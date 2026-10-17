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

## 0.8.1: keyboard / D-pad play. Every shared key takes focus, so Enter,
## Space or a pad's A can press it; the ring shows only after key or pad
## input, never after a tap.
func test_keys_take_keyboard_focus() -> void:
	var b := UI.button("x", func(): pass)
	eq(b.focus_mode, Control.FOCUS_ALL, "button")
	var c := UI.chip("help", func(): pass)
	eq(c.focus_mode, Control.FOCUS_ALL, "chip")
	var t := UI.icon_text_button("play", "x", func(): pass)
	eq(t.focus_mode, Control.FOCUS_ALL, "icon text button")
	var s := UI.switch(true, func(_on): pass)
	eq(s.focus_mode, Control.FOCUS_ALL, "switch")
	for n in [b, c, t, s]:
		n.free()
	eq(int(ProjectSettings.get_setting("gui/common/show_focus_state_on_pointer_event")), 0, "no focus ring after a tap")

func test_focus_ring_is_visible_on_every_key() -> void:
	var th := Style.build_theme()
	for v in ["Button", "SecondaryButton", "WarmButton", "GoldButton", "ChipButton", "TileButton", "NightButton",
			"NightChip", "LanternButton", "TabButton", "TabActive"]:
		var f := th.get_stylebox("focus", v) as StyleBoxFlat
		check(f != null and f.border_width_top >= 4 and f.expand_margin_top > 0 and not f.draw_center, "focus ring on " + v)
	check(th.get_stylebox("focus", "HSlider") is StyleBoxFlat, "focus ring on sliders")
	# the ring sits outside the key, on the cream ground: non-text contrast >= 3:1
	check(contrast(Style.GOLD_EDGE, Style.CREAM) >= 3.0, "ring vs cream %.2f" % contrast(Style.GOLD_EDGE, Style.CREAM))
	check(contrast(Style.LANTERN, Style.NIGHT) >= 3.0, "night ring vs night")

func test_dialog_focuses_its_main_action() -> void:
	var d := Dialog.make("t", "body", [["Main", func(): pass, ""], ["Other", func(): pass, "SecondaryButton"]])
	check(d.default_focus is Button and (d.default_focus as Button).text == "Main", "first button is the default focus")
	check(d.scroll.follow_focus, "a focused key inside a long dialog scrolls into view")
	d.free()

## Builds share one version: App.VERSION, and every Android preset's name and code.
func test_version_matches_export_presets() -> void:
	var ver: String = load("res://src/app/app.gd").VERSION
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK)
	var codes := {}
	for sec in cfg.get_sections():
		if not sec.ends_with(".options") or not cfg.has_section_key(sec, "version/code"):
			continue
		codes[int(cfg.get_value(sec, "version/code"))] = true
		check(str(cfg.get_value(sec, "version/name")).begins_with(ver), "%s version/name %s vs %s" % [sec, cfg.get_value(sec, "version/name"), ver])
		eq(str(cfg.get_value(sec, "package/unique_name")), "com.tinystreet.sortrestore", sec)
	eq(codes.size(), 1, "one versionCode across Android presets")
