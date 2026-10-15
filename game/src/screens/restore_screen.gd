extends Control
## Café restoration: five milestones bought with first-clear tokens, plus
## revisit-able cosmetic choices at fixed placements.

var cafe: CafeView
var list: VBoxContainer

func setup(_p: Dictionary) -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("restore"), func(): App.main.back()))
	cafe = CafeView.new()
	cafe.custom_minimum_size = Vector2(0, 360)
	cafe.configure(int(App.data.restoration.milestones), _choices())
	root.add_child(cafe)
	root.add_child(UI.label(Loc.t("tokens_n", [App.data.tokens]) + "  ·  " + Loc.t("token_rule"), "SoftLabel"))
	list = UI.vbox(14)
	root.add_child(UI.scroll(list))
	_milestones()
	_choice_sections()

func _choices() -> Dictionary:
	var c := {}
	for k in Restoration.DEFAULTS:
		c[k] = Restoration.effective_choice(App.data, k)
	return c

func _milestones() -> void:
	var done := int(App.data.restoration.milestones)
	for i in Restoration.MILESTONES.size():
		var m: Dictionary = Restoration.MILESTONES[i]
		var row := UI.hbox(14)
		var txt := UI.label("%d. %s" % [i + 1, Loc.t("ms_" + m.id)], "", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		if i < done:
			var g := Glyph.new(); g.kind = "check"; g.color = Style.TEAL; g.custom_minimum_size = Vector2(64, 64)
			row.add_child(g)
		elif i == done:
			var b := UI.button(Loc.t("unlock_cost", [m.cost]), _unlock, "WarmButton")
			b.disabled = not Restoration.can_unlock(App.data)
			b.custom_minimum_size = Vector2(230, Style.MIN_TOUCH)
			row.add_child(b)
		else:
			row.add_child(UI.label(Loc.t("cost_n", [m.cost]), "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		list.add_child(UI.card(UI.margin(row, 4, 0, 4, 0), "SoftPanel"))
		if i == done and not Restoration.can_unlock(App.data):
			list.add_child(UI.label(Loc.t("tokens_needed", [int(m.cost) - int(App.data.tokens)]), "SoftLabel"))

func _choice_sections() -> void:
	for cat in Restoration.CHOICES:
		var spec: Dictionary = Restoration.CHOICES[cat]
		var unlocked := int(App.data.restoration.milestones) >= int(spec.requires)
		list.add_child(UI.label(Loc.t("cat_" + cat), "HeaderLabel"))
		if not unlocked:
			list.add_child(UI.label(Loc.t("cat_locked", [Loc.t("ms_" + Restoration.MILESTONES[int(spec.requires) - 1].id)]), "SoftLabel"))
			continue
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		var current := Restoration.effective_choice(App.data, cat)
		for o in spec.options:
			var avail := Restoration.is_option_available(App.data, cat, o.id)
			var label := Loc.t("opt_" + o.id)
			if o.has("sku") and not avail:
				label += " (" + Loc.t("in_shop") + ")"
			var b := UI.button(label, func(): _choose(cat, o.id), "" if o.id == current else "SecondaryButton")
			b.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
			b.disabled = not avail
			flow.add_child(b)
		list.add_child(flow)

func _choose(cat: String, opt: String) -> void:
	if Restoration.set_choice(App.data, cat, opt):
		App.save_soon()
		_build()

func _unlock() -> void:
	var id := Restoration.unlock_next(App.data)
	if id == "":
		return
	App.analytics.event("restoration_unlocked", {"milestone": id, "index": App.data.restoration.milestones})
	App.save_now()
	App.audio.play("restore")
	App.haptic(40)
	_build()
	var flash := ColorRect.new()
	flash.color = Color(1, 0.98, 0.9, 0.9)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, App.dur(0.8))
	tw.tween_callback(flash.queue_free)
	var body := Loc.t("ms_done_" + id)
	if id == "sign":
		body += "\n\n" + Loc.t("finale_body")
	App.main.show_overlay(Dialog.make(Loc.t("ms_" + id), body, [[Loc.t("lovely"), func(): pass, ""]]))
