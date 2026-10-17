extends Control
## Settings, grouped: Sound (music and effects volume), Comfort (vibration,
## reduced motion, larger text), Language, and More (help, credits, privacy).
## Resetting progress is a separate, clearly marked action with a confirmation.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("settings"), func(): App.main.back()))
	var v := UI.vbox(18)
	root.add_child(UI.scroll(v))
	var s: Dictionary = App.data.settings
	var sound := UI.vbox(10)
	sound.add_child(UI.section(Loc.t("settings_sound"), "sound"))
	sound.add_child(_slider("music", Loc.t("music"), s.music, func(x): App.set_setting("music", x)))
	sound.add_child(_slider("sound", Loc.t("sounds"), s.sfx, func(x): App.set_setting("sfx", x)))
	v.add_child(UI.card(sound))
	var comfort := UI.vbox(6)
	comfort.add_child(UI.section(Loc.t("settings_comfort"), "heart"))
	comfort.add_child(_toggle("vibrate", Loc.t("haptics"), s.haptics, func(b): App.set_setting("haptics", b)))
	comfort.add_child(_toggle("motion", Loc.t("reduced_motion"), s.reduced_motion, func(b): App.set_setting("reduced_motion", b)))
	comfort.add_child(_toggle("text", Loc.t("large_text"), s.large_text, func(b): App.set_setting("large_text", b)))
	v.add_child(UI.card(comfort))
	var lang := UI.vbox(12)
	lang.add_child(UI.section(Loc.t("language"), "globe"))
	lang.add_child(UI.segmented([["en", "English"], ["ar", "العربية"]], Loc.lang, func(l: String): App.set_setting("lang", l)))
	if Loc.lang == "ar":
		lang.add_child(UI.label(Loc.t("ar_review_note"), "SoftLabel", UI.al()))
	v.add_child(UI.card(lang))
	var more := UI.vbox(10)
	more.add_child(UI.section(Loc.t("more"), "info"))
	for item in [["help", "help", "help"], ["credits", "credits", "star"], ["privacy", "privacy", "shield"]]:
		more.add_child(_link(item[2], Loc.t(item[0]), func(): App.main.goto(item[1])))
	if App.consent.privacy_options_required:
		more.add_child(_link("shield", Loc.t("privacy_choices"), func(): App.consent.show_privacy_options()))
	if App.billing.is_available():
		more.add_child(_link("plus", Loc.t("shop"), func(): App.main.goto("shop")))
	v.add_child(UI.card(more))
	var reset := UI.icon_text_button("reset", Loc.t("reset_progress"), _confirm_reset, "GhostButton")
	var rl: Label = reset.get_meta("label")
	rl.add_theme_color_override("font_color", Style.DANGER)
	(reset.get_child(0).get_child(0) as Glyph).color = Style.DANGER
	v.add_child(reset)
	v.add_child(UI.label(Loc.t("version", [App.VERSION, Engine.get_version_info().string]), "CaptionLabel"))

func _slider(glyph: String, text: String, value: float, cb: Callable) -> Control:
	var col := UI.vbox(4)
	var head := UI.hbox(12)
	head.add_child(UI.medallion(glyph, Style.TEAL_SOFT, Style.TEAL_DARK, 52))
	var l := UI.label(text, "StrongLabel", UI.al(), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var pct := UI.label("%d%%" % int(round(value * 100)), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	head.add_child(pct)
	col.add_child(head)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(0, 64)
	sl.value_changed.connect(func(x: float):
		pct.text = "%d%%" % int(round(x * 100))
		cb.call(x))
	col.add_child(sl)
	return col

func _toggle(glyph: String, text: String, value: bool, cb: Callable) -> Control:
	var row := UI.hbox(12)
	row.add_child(UI.medallion(glyph, Style.TEAL_SOFT, Style.TEAL_DARK, 52))
	var l := UI.label(text, "StrongLabel", UI.al())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UI.switch(value, cb))
	return row

## A full-width list row that navigates somewhere (icon, label, chevron).
func _link(glyph: String, text: String, cb: Callable) -> Control:
	var b := Button.new()
	b.theme_type_variation = "TileButton"
	b.custom_minimum_size = Vector2(0, 88)
	UI._wire(b, cb)
	var r := UI.hbox(14)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 14
	r.offset_right = -16
	r.offset_bottom = -Style.EDGE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := UI.medallion(glyph, Style.LINEN, Style.TEAL_DARK, 52)
	r.add_child(m)
	var l := UI.label(text, "StrongLabel", UI.al(), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(l)
	var ch := Glyph.new()
	ch.kind = "chevron"
	ch.color = Style.INK_SOFT
	ch.custom_minimum_size = Vector2(30, 30)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(ch)
	b.add_child(r)
	return b

func _confirm_reset() -> void:
	App.main.show_overlay(Dialog.make(Loc.t("reset_title"), Loc.t("reset_body"), [
		[Loc.t("cancel"), func(): pass, "SecondaryButton"],
		[Loc.t("reset_confirm"), func():
			var keep_settings: Dictionary = App.data.settings.duplicate()
			var keep_purchases: Dictionary = App.data.purchases.duplicate(true)
			App.data = GameData.fresh()
			App.data.settings = keep_settings
			App.data.purchases = keep_purchases
			App.save_now()
			App.main.goto("home", {}, false), "WarmButton"],
	], null, "reset"))
