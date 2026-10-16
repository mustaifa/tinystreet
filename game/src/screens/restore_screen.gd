extends Control
## Café restoration: eight visible steps bought with tokens, décor that can be
## PREVIEWED in the café before it is kept, coherent themes, and collectible
## extras (also previewable before buying). Owned choices switch for free.
## Buying a step plays a short celebration (the cast cheers), then opens the
## décor picker for that step with the café still in view.

var cafe: CafeView
var panel: VBoxContainer
var tokens_label: Label
var choosing := ""        # category being picked right after a purchase
var _peek := false
var _busy := false
var _preview := {}        # category -> option shown but not yet kept
var _preview_extra := ""  # an extra shown before buying

func setup(p: Dictionary) -> void:
	choosing = str(p.get("choose", ""))
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("restore"), func(): _leave()))
	cafe = CafeView.new()
	cafe.custom_minimum_size = Vector2(0, 470)
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
	_refresh_cafe()
	_fill_panel()

func _fill_panel() -> void:
	for c in panel.get_children():
		c.queue_free()
	if not _preview.is_empty() or _preview_extra != "":
		_preview_bar()
	if choosing != "":
		_choice_panel(choosing)
	else:
		_main_panel()

## What the café shows: saved state plus anything being previewed.
func _refresh_cafe() -> void:
	var st := Restoration.view_state(App.data)
	if _peek:
		st.steps = mini(int(st.steps) + 1, Restoration.STEPS.size())
	for cat in _preview:
		st.choices[cat] = _preview[cat]
	if _preview_extra != "":
		st.extras[_preview_extra] = true
	cafe.configure_state(st)
	cafe.preview = _peek or not _preview.is_empty() or _preview_extra != ""

func _leave() -> void:
	_preview.clear()
	_preview_extra = ""
	App.main.back()

## Android back while previewing reverts the preview first.
func on_back() -> bool:
	if not _preview.is_empty() or _preview_extra != "":
		_revert()
		return true
	return false

# --------------------------------------------------------------------- panels

## Shown while something is being previewed: keep it or go back.
func _preview_bar() -> void:
	var row := UI.hbox(12)
	var txt := UI.label(Loc.t("previewing"), "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	if _preview_extra == "":
		var keep := UI.button(Loc.t("keep"), _keep, "")
		keep.custom_minimum_size = Vector2(150, Style.MIN_TOUCH)
		row.add_child(keep)
	var back := UI.button(Loc.t("revert"), _revert, "SecondaryButton")
	back.custom_minimum_size = Vector2(150, Style.MIN_TOUCH)
	row.add_child(back)
	panel.add_child(UI.card(row, "SoftPanel"))

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
	var steps := UI.vbox(6)
	for k in Restoration.STEPS.size():
		var s: Dictionary = Restoration.STEPS[k]
		var r := UI.hbox(12)
		var g := Glyph.new()
		g.kind = "check" if k < Restoration.steps(App.data) else ("lock" if k > Restoration.steps(App.data) else "paint")
		g.color = Style.TEAL if k < Restoration.steps(App.data) else Style.INK_SOFT
		g.custom_minimum_size = Vector2(48, 48)
		r.add_child(g)
		var l := UI.label(Loc.t("step_" + str(s.id)), "" if k <= Restoration.steps(App.data) else "SoftLabel", _al(), false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UI.label(Loc.t("cost_n", [s.cost]) if k >= Restoration.steps(App.data) else "", "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		steps.add_child(r)
	panel.add_child(UI.label(Loc.t("restore_steps"), "HeaderLabel"))
	panel.add_child(UI.card(steps, "SoftPanel"))
	_themes()
	var any := false
	for cat in Restoration.CHOICES:
		if Restoration.is_category_open(App.data, cat):
			if not any:
				panel.add_child(UI.label(Loc.t("decor"), "HeaderLabel"))
				any = true
			_choice_row(cat)
	_extras()

func _al() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT

## Themes: one tap previews a coherent look over everything restored so far.
func _themes() -> void:
	var open := 0
	for cat in Restoration.CHOICES:
		if Restoration.is_category_open(App.data, cat):
			open += 1
	if open < 2:
		return
	panel.add_child(UI.label(Loc.t("themes"), "HeaderLabel"))
	var cur := Restoration.current_theme(App.data)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	for th in Restoration.THEMES:
		var label := Loc.t("theme_" + th)
		var is_cur: bool = th == cur and _preview.is_empty()
		if is_cur:
			label = "✓ " + label
		var b := UI.button(label, func():
			_preview = Restoration.theme_choices(App.data, th)
			for cat in _preview.keys():
				if _preview[cat] == Restoration.effective_choice(App.data, cat):
					_preview.erase(cat)
			_refresh_cafe()
			_fill_panel(), "" if is_cur else "SecondaryButton")
		b.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
		flow.add_child(b)
	panel.add_child(flow)

func _choice_row(cat: String) -> void:
	panel.add_child(UI.label(Loc.t("cat_" + cat), "", _al()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	var current := str(_preview.get(cat, Restoration.effective_choice(App.data, cat)))
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
		var b := UI.button(label, func(): _try(cat, o.id), "" if o.id == current else "SecondaryButton")
		b.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
		b.disabled = not avail
		flow.add_child(b)
	panel.add_child(flow)

## Right after buying a step: pick its look with the café in full view.
func _choice_panel(cat: String) -> void:
	var card := UI.vbox(12)
	card.add_child(UI.label(Loc.t("choose_title", [Loc.t("cat_" + cat)]), "HeaderLabel"))
	card.add_child(UI.label(Loc.t("choose_body"), "SoftLabel"))
	panel.add_child(UI.card(card))
	_choice_row(cat)
	panel.add_child(UI.button(Loc.t("done"), func():
		_keep()
		choosing = ""
		_fill_panel(), ""))

func _extras() -> void:
	panel.add_child(UI.label(Loc.t("extras"), "HeaderLabel"))
	for e in Restoration.EXTRAS:
		var row := UI.hbox(12)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(Loc.t("extra_" + str(e.id)), "", _al(), false))
		var owned := Restoration.owns_extra(App.data, e.id)
		var sub := ""
		if e.has("ach") and not owned:
			sub = Loc.t("extra_from_ach", [Loc.t("ach_" + str(e.ach))])
		elif e.has("special") and not owned:
			sub = Loc.t("extra_from_special", [App.progression.campaign_index(str(e.special)) + 1])
		elif not owned and Restoration.steps(App.data) < int(e.step):
			sub = Loc.t("extra_after_step", [Loc.t("step_" + str(Restoration.STEPS[int(e.step) - 1].id))])
		else:
			sub = Loc.t("extra_desc_" + str(e.id))
		v.add_child(UI.label(sub, "SoftLabel", _al()))
		row.add_child(v)
		if owned:
			var shown := not bool(App.data.restoration.hidden.get(e.id, false))
			var t := UI.button(Loc.t("shown") if shown else Loc.t("hidden"), func():
				Restoration.toggle_extra(App.data, e.id)
				App.save_soon()
				_refresh_cafe()
				_fill_panel(), "" if shown else "SecondaryButton")
			t.custom_minimum_size = Vector2(170, Style.MIN_TOUCH)
			row.add_child(t)
		else:
			var buttons := UI.vbox(8)
			var pv := UI.button(Loc.t("peek"), func():
				_preview_extra = e.id
				_refresh_cafe()
				_fill_panel(), "SecondaryButton", 72)
			pv.custom_minimum_size = Vector2(170, 72)
			buttons.add_child(pv)
			if not e.has("ach") and not e.has("special"):
				var b := UI.button(Loc.t("buy_cost", [e.cost]), func(): _buy_extra(e.id), "WarmButton")
				b.disabled = not Restoration.can_buy_extra(App.data, e.id)
				b.custom_minimum_size = Vector2(170, Style.MIN_TOUCH)
				buttons.add_child(b)
			row.add_child(buttons)
		panel.add_child(UI.card(row, "SoftPanel"))

# --------------------------------------------------------------------- actions

func _toggle_peek() -> void:
	_peek = not _peek
	_refresh_cafe()
	_fill_panel()

## Preview an option (nothing is saved until Keep).
func _try(cat: String, opt: String) -> void:
	if not Restoration.is_option_available(App.data, cat, opt):
		return
	App.audio.play("place")
	if opt == Restoration.effective_choice(App.data, cat):
		_preview.erase(cat)
	else:
		_preview[cat] = opt
	_refresh_cafe()
	_fill_panel()

## Saves every previewed choice. Switching between owned options is free.
func _keep() -> void:
	var changed := false
	for cat in _preview:
		if Restoration.set_choice(App.data, cat, _preview[cat]):
			changed = true
	_preview.clear()
	_preview_extra = ""
	if changed:
		App.save_now()
		App.audio.play("restore")
		cafe.cheer()
	_refresh_cafe()
	_fill_panel()

func _revert() -> void:
	_preview.clear()
	_preview_extra = ""
	_refresh_cafe()
	_fill_panel()

func _buy_extra(id: String) -> void:
	if not Restoration.buy_extra(App.data, id):
		return
	App.save_now()
	App.audio.play("restore")
	App.analytics.event("extra_bought", {"id": id})
	_preview_extra = ""
	_build()
	cafe.cheer()
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
	_preview.clear()
	_preview_extra = ""
	var st := Restoration.step_def(id)
	choosing = str(st.get("choice", ""))
	_build()
	cafe.cheer()
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
