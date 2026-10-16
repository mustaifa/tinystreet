extends Control
## Café restoration: eight visible steps bought with tokens, decor choices
## that change the café instantly (and can be changed any time), and
## collectible extras. Buying a step plays a short celebration, then opens the
## decor picker for that step with the café still in view.

var cafe: CafeView
var panel: VBoxContainer
var tokens_label: Label
var choosing := ""        # category being picked right after a purchase
var _peek := false
var _busy := false

func setup(p: Dictionary) -> void:
	choosing = str(p.get("choose", ""))
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("restore"), func(): App.main.back()))
	cafe = CafeView.new()
	cafe.custom_minimum_size = Vector2(0, 470)
	cafe.configure_state(Restoration.view_state(App.data))
	root.add_child(cafe)
	var trow := UI.hbox(10)
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	var coin := Glyph.new()
	coin.kind = "coin"
	coin.color = Style.GOLD
	coin.custom_minimum_size = Vector2(48, 48)
	trow.add_child(coin)
	tokens_label = UI.label(Loc.t("tokens_n", [App.data.tokens]), "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	trow.add_child(tokens_label)
	root.add_child(trow)
	panel = UI.vbox(14)
	root.add_child(UI.scroll(panel))
	if choosing != "":
		_choice_panel(choosing, true)
	else:
		_main_panel()

# --------------------------------------------------------------------- panels

func _main_panel() -> void:
	var i := Restoration.next_index(App.data)
	if i >= 0:
		var st: Dictionary = Restoration.STEPS[i]
		var card := UI.vbox(10)
		card.add_child(UI.label(Loc.t("step_n_of", [i + 1, Restoration.STEPS.size()]), "SoftLabel"))
		card.add_child(UI.label(Loc.t("step_" + str(st.id)), "HeaderLabel"))
		card.add_child(UI.label(Loc.t("step_desc_" + str(st.id)), "SoftLabel"))
		card.add_child(GoalBar.make(App.data))
		var row := UI.hbox(14)
		var buy := UI.button(Loc.t("restore_cost", [st.cost]), _unlock, "WarmButton")
		buy.disabled = not Restoration.can_unlock(App.data)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(buy)
		var peek := UI.button(Loc.t("peek_hide") if _peek else Loc.t("peek"), _toggle_peek, "SecondaryButton")
		peek.custom_minimum_size = Vector2(200, Style.MIN_TOUCH)
		row.add_child(peek)
		card.add_child(row)
		if not Restoration.can_unlock(App.data):
			card.add_child(UI.label(Loc.t("tokens_how", [int(st.cost) - int(App.data.tokens)]), "SoftLabel"))
		panel.add_child(UI.card(card))
	else:
		panel.add_child(UI.card(UI.label(Loc.t("cafe_complete"), "HeaderLabel")))
	# steps checklist
	var steps := UI.vbox(6)
	for k in Restoration.STEPS.size():
		var s: Dictionary = Restoration.STEPS[k]
		var r := UI.hbox(12)
		var g := Glyph.new()
		g.kind = "check" if k < Restoration.steps(App.data) else ("lock" if k > Restoration.steps(App.data) else "paint")
		g.color = Style.TEAL if k < Restoration.steps(App.data) else Style.INK_SOFT
		g.custom_minimum_size = Vector2(48, 48)
		r.add_child(g)
		var l := UI.label(Loc.t("step_" + str(s.id)), "" if k <= Restoration.steps(App.data) else "SoftLabel", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UI.label(Loc.t("cost_n", [s.cost]) if k >= Restoration.steps(App.data) else "", "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		steps.add_child(r)
	panel.add_child(UI.label(Loc.t("restore_steps"), "HeaderLabel"))
	panel.add_child(UI.card(steps, "SoftPanel"))
	# decor (any open category can be changed at any time)
	var any := false
	for cat in Restoration.CHOICES:
		if Restoration.is_category_open(App.data, cat):
			if not any:
				panel.add_child(UI.label(Loc.t("decor"), "HeaderLabel"))
				any = true
			_choice_row(cat)
	_extras()

func _choice_row(cat: String) -> void:
	panel.add_child(UI.label(Loc.t("cat_" + cat), "", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	var current := Restoration.effective_choice(App.data, cat)
	for o in Restoration.CHOICES[cat].options:
		var avail := Restoration.is_option_available(App.data, cat, o.id)
		if o.has("sku") and not avail and not App.billing.is_available():
			continue # don't show a theme that can't be bought in this build
		var label := Loc.t("opt_" + str(o.id))
		if o.id == current:
			label = "✓ " + label
		elif o.has("sku") and not avail:
			label += " (" + Loc.t("in_shop") + ")"
		elif o.has("ach") and not avail:
			label += " (" + Loc.t("ach_" + str(o.ach)) + ")"
		var b := UI.button(label, func(): _choose(cat, o.id), "" if o.id == current else "SecondaryButton")
		b.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
		b.disabled = not avail
		flow.add_child(b)
	panel.add_child(flow)

## Right after buying a step: pick its look with the café in full view.
func _choice_panel(cat: String, after_purchase: bool) -> void:
	var card := UI.vbox(12)
	card.add_child(UI.label(Loc.t("choose_title", [Loc.t("cat_" + cat)]), "HeaderLabel"))
	card.add_child(UI.label(Loc.t("choose_body"), "SoftLabel"))
	panel.add_child(UI.card(card))
	_choice_row(cat)
	var done := UI.button(Loc.t("done"), func():
		choosing = ""
		_build(), "")
	panel.add_child(done)

func _extras() -> void:
	panel.add_child(UI.label(Loc.t("extras"), "HeaderLabel"))
	for e in Restoration.EXTRAS:
		var row := UI.hbox(12)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var al := HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(UI.label(Loc.t("extra_" + str(e.id)), "", al, false))
		var owned := Restoration.owns_extra(App.data, e.id)
		var sub := ""
		if e.has("ach") and not owned:
			sub = Loc.t("extra_from_ach", [Loc.t("ach_" + str(e.ach))])
		elif not owned and Restoration.steps(App.data) < int(e.step):
			sub = Loc.t("extra_after_step", [Loc.t("step_" + str(Restoration.STEPS[int(e.step) - 1].id))])
		else:
			sub = Loc.t("extra_desc_" + str(e.id))
		v.add_child(UI.label(sub, "SoftLabel", al))
		row.add_child(v)
		if owned:
			var shown := not bool(App.data.restoration.hidden.get(e.id, false))
			var t := UI.button(Loc.t("shown") if shown else Loc.t("hidden"), func():
				Restoration.toggle_extra(App.data, e.id)
				App.save_soon()
				_build(), "" if shown else "SecondaryButton")
			t.custom_minimum_size = Vector2(170, Style.MIN_TOUCH)
			row.add_child(t)
		elif not e.has("ach"):
			var b := UI.button(Loc.t("buy_cost", [e.cost]), func(): _buy_extra(e.id), "WarmButton")
			b.disabled = not Restoration.can_buy_extra(App.data, e.id)
			b.custom_minimum_size = Vector2(170, Style.MIN_TOUCH)
			row.add_child(b)
		panel.add_child(UI.card(row, "SoftPanel"))

# --------------------------------------------------------------------- actions

func _toggle_peek() -> void:
	_peek = not _peek
	var st := Restoration.view_state(App.data)
	if _peek:
		st.steps = mini(int(st.steps) + 1, Restoration.STEPS.size())
	cafe.configure_state(st)
	cafe.preview = _peek
	for c in panel.get_children():
		c.queue_free()
	_main_panel()

func _choose(cat: String, opt: String) -> void:
	if Restoration.set_choice(App.data, cat, opt):
		App.audio.play("place")
		App.save_soon()
		cafe.configure_state(Restoration.view_state(App.data))
		var keep := choosing
		for c in panel.get_children():
			c.queue_free()
		if keep != "":
			_choice_panel(keep, true)
		else:
			_main_panel()

func _buy_extra(id: String) -> void:
	if not Restoration.buy_extra(App.data, id):
		return
	App.save_now()
	App.audio.play("restore")
	App.analytics.event("extra_bought", {"id": id})
	_build()
	_celebrate_small()

## Spends tokens once (guarded against double taps), updates the café,
## celebrates, then the step's decor picker and its story beat.
func _unlock() -> void:
	if _busy:
		return
	_busy = true
	var id := Restoration.unlock_next(App.data)
	if id == "":
		_busy = false
		return
	App.analytics.event("restoration_unlocked", {"step": id, "index": Restoration.steps(App.data)})
	App.save_now()
	App.audio.play("restore")
	App.haptic(40)
	_peek = false
	var st := Restoration.step_def(id)
	choosing = str(st.get("choice", ""))
	_build()
	_celebrate_big(id == "opening")
	var after := func():
		_busy = false
		if id == "opening":
			App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_body"), [[Loc.t("lovely"), func(): pass, ""]]))
	Story.after_step(id, after)
	var news := Achievements.take_new(App.data)
	for a in news:
		App.main.toast(Loc.t("ach_unlocked", [Loc.t("ach_" + str(a))]))

func _celebrate_big(finale: bool) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var flash := ColorRect.new()
	flash.color = Color(1, 0.98, 0.9, 0.85)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, App.dur(0.7))
	tw.tween_callback(flash.queue_free)
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var r := cafe.get_global_rect()
	Fx.burst(layer, r.get_center() + Vector2(0, -r.size.y * 0.3), "confetti")
	if finale:
		Fx.burst(layer, r.get_center() + Vector2(-200, -r.size.y * 0.2), "confetti")
		Fx.burst(layer, r.get_center() + Vector2(200, -r.size.y * 0.2), "confetti")
	Fx.float_text(layer, r.get_center(), Loc.t("restored"), Style.TERRACOTTA, 48)
	var t2 := create_tween()
	t2.tween_interval(3.0)
	t2.tween_callback(layer.queue_free)

func _celebrate_small() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	Fx.burst(layer, cafe.get_global_rect().get_center(), "pop")
	var t2 := create_tween()
	t2.tween_interval(1.5)
	t2.tween_callback(layer.queue_free)
