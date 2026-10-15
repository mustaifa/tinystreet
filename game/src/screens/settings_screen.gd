extends Control
## Settings: separate music/SFX volume, haptics, reduced motion, large text,
## language (English / Arabic), privacy, and links to help/credits.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("settings"), func(): App.main.back()))
	var v := UI.vbox(18)
	root.add_child(UI.scroll(v))
	var s: Dictionary = App.data.settings
	v.add_child(_slider(Loc.t("music"), s.music, func(x): App.set_setting("music", x)))
	v.add_child(_slider(Loc.t("sounds"), s.sfx, func(x): App.set_setting("sfx", x)))
	v.add_child(_toggle(Loc.t("haptics"), s.haptics, func(b): App.set_setting("haptics", b)))
	v.add_child(_toggle(Loc.t("reduced_motion"), s.reduced_motion, func(b): App.set_setting("reduced_motion", b)))
	v.add_child(_toggle(Loc.t("large_text"), s.large_text, func(b): App.set_setting("large_text", b)))
	v.add_child(UI.label(Loc.t("language"), "HeaderLabel"))
	var lang := UI.hbox(14)
	for l in [["en", "English"], ["ar", "العربية"]]:
		var b := UI.button(l[1], func(): App.set_setting("lang", l[0]), "" if Loc.lang == l[0] else "SecondaryButton")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lang.add_child(b)
	v.add_child(lang)
	if Loc.lang == "ar":
		v.add_child(UI.label(Loc.t("ar_review_note"), "SoftLabel"))
	v.add_child(UI.label(Loc.t("more"), "HeaderLabel"))
	for item in [["help", "help"], ["credits", "credits"], ["privacy", "privacy"]]:
		v.add_child(UI.button(Loc.t(item[0]), func(): App.main.goto(item[1]), "SecondaryButton"))
	if App.consent.privacy_options_required:
		v.add_child(UI.button(Loc.t("privacy_choices"), func(): App.consent.show_privacy_options(), "SecondaryButton"))
	if App.billing.is_available():
		v.add_child(UI.button(Loc.t("shop"), func(): App.main.goto("shop"), "SecondaryButton"))
	v.add_child(UI.button(Loc.t("reset_progress"), _confirm_reset, "SecondaryButton"))
	v.add_child(UI.label(Loc.t("version", [App.VERSION, Engine.get_version_info().string]), "SoftLabel"))

func _slider(text: String, value: float, cb: Callable) -> Control:
	var row := UI.vbox(6)
	row.add_child(UI.label(text, "", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(0, 64)
	sl.value_changed.connect(cb)
	row.add_child(sl)
	return row

## A clearly labelled On/Off switch (text + colour, not colour alone).
func _toggle(text: String, value: bool, cb: Callable) -> Control:
	var row := UI.hbox(12)
	var l := UI.label(text, "", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, Style.MIN_TOUCH)
	var paint := func(on: bool):
		b.text = Loc.t("on") if on else Loc.t("off")
		b.theme_type_variation = "" if on else "SecondaryButton"
	paint.call(value)
	b.toggled.connect(func(on: bool):
		paint.call(on)
		App.audio.play("tap")
		cb.call(on))
	row.add_child(b)
	return row

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
	]))
