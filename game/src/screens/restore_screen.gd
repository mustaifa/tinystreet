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

const SWATCH := {
	"walls": {"cream": "f1dfc0", "sage": "c3d4b8", "blush": "efcbbf", "evening": "34495e"},
	"floor": {"oak": "c8935f", "checker": "3f3a37", "terracotta": "c66a45"},
	"counter": {"oakwood": "a8714a", "marble": "e8e4dc", "teal": "1f7a72"},
}
const CAT_ICON := {"lights": "lantern", "seating": "cup", "plants": "heart", "sign": "text"}
const EXTRA_ICON := {"clock": "timer", "cakestand": "cake", "gramophone": "music", "cat": "heart",
	"photos": "spark", "chalkboard": "text", "breadbasket": "p_croissant", "lamp": "lantern"}

var preview_holder: VBoxContainer

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var pill := UI.pill("coin", str(App.data.tokens))
	tokens_label = pill.get_meta("label")
	root.add_child(UI.header(Loc.t("restore"), func(): _leave(), pill))
	cafe = CafeView.new()
	var front := Storefront.new(cafe)
	front.custom_minimum_size = Vector2(0, 400)
	root.add_child(front)
	preview_holder = UI.vbox(0)
	root.add_child(preview_holder)
	panel = UI.vbox(16)
	root.add_child(UI.scroll(panel))
	_refresh_cafe()
	_fill_panel()

func _fill_panel() -> void:
	for c in panel.get_children():
		c.queue_free()
	for c in preview_holder.get_children():
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

## Shown (outside the scroll, always visible) while something is previewed:
## Keep saves it, Revert puts the café back exactly as it was.
func _preview_bar() -> void:
	var row := UI.hbox(12)
	row.add_child(UI.medallion("eye", Style.PAPER, Style.TERRACOTTA, 56))
	var txt := UI.vbox(0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(UI.label(Loc.t("previewing"), "StrongLabel", UI.al(), false))
	txt.add_child(UI.label(Loc.t("preview_not_saved"), "CaptionLabel", UI.al(), false))
	row.add_child(txt)
	if _preview_extra == "":
		var keep := UI.button(Loc.t("keep"), _keep, "")
		keep.custom_minimum_size = Vector2(130, Style.MIN_TOUCH)
		row.add_child(keep)
	var back := UI.button(Loc.t("revert"), _revert, "SecondaryButton")
	back.custom_minimum_size = Vector2(130, Style.MIN_TOUCH)
	row.add_child(back)
	preview_holder.add_child(UI.card(row, "WarmPanel"))

func _main_panel() -> void:
	var i := Restoration.next_index(App.data)
	if i >= 0:
		var st: Dictionary = Restoration.STEPS[i]
		var card := UI.vbox(12)
		var top := UI.hbox(10)
		var cap := UI.label(Loc.t("step_n_of", [i + 1, Restoration.STEPS.size()]), "CaptionLabel", UI.al(), false)
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(cap)
		top.add_child(_stepper(Restoration.steps(App.data), Restoration.STEPS.size()))
		card.add_child(top)
		card.add_child(UI.label(Loc.t("step_" + str(st.id)), "HeaderLabel", UI.al()))
		card.add_child(UI.label(Loc.t("step_desc_" + str(st.id)), "SoftLabel", UI.al()))
		var have := int(App.data.tokens)
		card.add_child(UI.progress_row(mini(have, int(st.cost)), int(st.cost), Style.TERRACOTTA if have >= int(st.cost) else Style.GOLD))
		var row := UI.hbox(12)
		var buy := UI.icon_text_button("coin", Loc.t("restore_cost", [st.cost]), _unlock, "WarmButton")
		buy.disabled = not Restoration.can_unlock(App.data)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(buy)
		var peek := UI.icon_text_button("eye", Loc.t("peek_hide") if _peek else Loc.t("peek"), _toggle_peek, "SecondaryButton")
		peek.custom_minimum_size = Vector2(210, Style.MIN_TOUCH)
		row.add_child(peek)
		card.add_child(row)
		if not Restoration.can_unlock(App.data):
			card.add_child(UI.label(Loc.t("tokens_how", [int(st.cost) - have]), "SoftLabel", UI.al()))
		panel.add_child(UI.card(card))
	else:
		var done := UI.row(UI.medallion("spark", Style.GOLD_SOFT, Style.GOLD_EDGE, 64), Loc.t("cafe_complete"), "", null, "HeaderLabel")
		panel.add_child(UI.card(done))
	var steps := UI.vbox(4)
	var owned_steps := Restoration.steps(App.data)
	for k in Restoration.STEPS.size():
		var s: Dictionary = Restoration.STEPS[k]
		var done_k := k < owned_steps
		var leader := UI.medallion("check" if done_k else ("brush" if k == owned_steps else "lock"),
			Style.TEAL_SOFT if done_k else (Style.TERRA_SOFT if k == owned_steps else Style.CREAM_DEEP),
			Style.TEAL_DARK if done_k else (Style.TERRACOTTA if k == owned_steps else Style.INK_SOFT), 44)
		var cost_l := UI.label("" if done_k else Loc.t("cost_n", [s.cost]), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
		steps.add_child(UI.row(leader, Loc.t("step_" + str(s.id)), "", cost_l, "StrongLabel" if k <= owned_steps else "SoftLabel"))
	panel.add_child(UI.section(Loc.t("restore_steps"), "brush"))
	panel.add_child(UI.card(steps, "SoftPanel"))
	_themes()
	var any := false
	for cat in Restoration.CHOICES:
		if Restoration.is_category_open(App.data, cat):
			if not any:
				panel.add_child(UI.section(Loc.t("decor"), "paint"))
				any = true
			_choice_row(cat)
	_extras()

func _al() -> int:
	return UI.al()

## Eight small dots: restored steps teal, the next one ringed in coral.
func _stepper(done: int, total: int) -> Control:
	var h := UI.hbox(5)
	for k in total:
		var d := UI.ProgressPill.new()
		d.custom_minimum_size = Vector2(16, 16)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.goal = 1
		d.value = 1 if k < done else 0
		d.fill = Style.TEAL
		d.track = Style.TERRA_SOFT if k == done else Color(Style.INK_SOFT, 0.16)
		h.add_child(d)
	return h

## Themes: one tap previews a coherent look over everything restored so far.
func _themes() -> void:
	var open := 0
	for cat in Restoration.CHOICES:
		if Restoration.is_category_open(App.data, cat):
			open += 1
	if open < 2:
		return
	panel.add_child(UI.section(Loc.t("themes"), "spark"))
	var cur := Restoration.current_theme(App.data)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for th in Restoration.THEMES:
		var is_cur: bool = th == cur and _preview.is_empty()
		var b := UI.icon_text_button("check" if is_cur else "", Loc.t("theme_" + th), func():
			_preview = Restoration.theme_choices(App.data, th)
			for cat in _preview.keys():
				if _preview[cat] == Restoration.effective_choice(App.data, cat):
					_preview.erase(cat)
			_refresh_cafe()
			_fill_panel(), "Button" if is_cur else "SecondaryButton")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	panel.add_child(grid)

func _choice_row(cat: String) -> void:
	panel.add_child(UI.label(Loc.t("cat_" + cat), "StrongLabel", _al()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var current := str(_preview.get(cat, Restoration.effective_choice(App.data, cat)))
	for o in Restoration.CHOICES[cat].options:
		var avail := Restoration.is_option_available(App.data, cat, o.id)
		if o.has("sku") and not avail and not App.billing.is_available():
			continue # don't show a theme that can't be bought in this build
		flow.add_child(_option(cat, o, avail, o.id == current))
	panel.add_child(flow)

## One décor option: a swatch (or category icon), its name, and a tick when
## it is the one shown. Locked options say what unlocks them.
func _option(cat: String, o: Dictionary, avail: bool, selected: bool) -> Control:
	var label := Loc.t("opt_" + str(o.id))
	var sub := ""
	if o.has("sku") and not avail:
		sub = Loc.t("in_shop")
	elif o.has("ach") and not avail:
		sub = Loc.t("ach_" + str(o.ach))
	var b := Button.new()
	b.theme_type_variation = "Button" if selected else "SecondaryButton"
	var tw := Style.font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(25)).x
	if sub != "":
		tw = maxf(tw, Style.font_bold.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(Style.T_CAPTION)).x)
	b.custom_minimum_size = Vector2(minf(660.0, maxf(200.0, tw + 96)), 84 if sub == "" else 100)
	b.disabled = not avail
	UI._wire(b, func(): _try(cat, o.id))
	var r := UI.hbox(10)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 12
	r.offset_right = -14
	r.offset_bottom = -Style.EDGE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw := _Swatch.new()
	sw.custom_minimum_size = Vector2(44, 44)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cols: Dictionary = SWATCH.get(cat, {})
	sw.col = Color(str(cols.get(o.id, "fffaf3")))
	sw.checker = cat == "floor" and o.id == "checker"
	sw.icon = "lock" if not avail else ("check" if selected else str(CAT_ICON.get(cat, "")))
	sw.has_col = cols.has(o.id)
	r.add_child(sw)
	var col := UI.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(label, "StrongLabel", UI.al(), false)
	t.add_theme_font_size_override("font_size", Style.fs(25))
	t.add_theme_color_override("font_color", Color.WHITE if selected else (Style.TEAL_DARK if avail else Style.INK_SOFT))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	if sub != "":
		var sl := UI.label(sub, "CaptionLabel", UI.al(), false)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sl)
	r.add_child(col)
	b.add_child(r)
	return b

## Right after buying a step: pick its look with the café in full view.
func _choice_panel(cat: String) -> void:
	var card := UI.vbox(12)
	card.add_child(UI.row(UI.medallion("paint", Style.TERRA_SOFT, Style.TERRACOTTA, 60), Loc.t("choose_title", [Loc.t("cat_" + cat)]),
		Loc.t("choose_body"), null, "HeaderLabel"))
	panel.add_child(UI.card(card))
	_choice_row(cat)
	panel.add_child(UI.button(Loc.t("done"), func():
		_keep()
		choosing = ""
		_fill_panel(), ""))

func _extras() -> void:
	panel.add_child(UI.section(Loc.t("extras"), "heart"))
	for e in Restoration.EXTRAS:
		var owned := Restoration.owns_extra(App.data, e.id)
		var sub := ""
		if e.has("ach") and not owned:
			sub = Loc.t("extra_from_ach", [Loc.t("ach_" + str(e.ach))])
		elif e.has("special") and not owned and str(e.special) == "ledger":
			sub = Loc.t("extra_from_ledger")
		elif e.has("special") and not owned:
			sub = Loc.t("extra_from_special", [App.progression.campaign_index(str(e.special)) + 1])
		elif not owned and Restoration.steps(App.data) < int(e.step):
			sub = Loc.t("extra_after_step", [Loc.t("step_" + str(Restoration.STEPS[int(e.step) - 1].id))])
		else:
			sub = Loc.t("extra_desc_" + str(e.id))
		var lead := UI.medallion(str(EXTRA_ICON.get(e.id, "spark")), Style.TEAL_SOFT if owned else Style.GOLD_SOFT,
			Style.TEAL_DARK if owned else Style.GOLD_EDGE, 64)
		var trail: Control
		if owned:
			var shown := not bool(App.data.restoration.hidden.get(e.id, false))
			var t := UI.button(Loc.t("shown") if shown else Loc.t("hidden"), func():
				Restoration.toggle_extra(App.data, e.id)
				App.save_soon()
				_refresh_cafe()
				_fill_panel(), "" if shown else "SecondaryButton")
			t.custom_minimum_size = Vector2(150, Style.MIN_TOUCH)
			trail = t
		else:
			var buttons := UI.vbox(8)
			var pv := UI.button(Loc.t("peek"), func():
				_preview_extra = e.id
				_refresh_cafe()
				_fill_panel(), "SecondaryButton", 72)
			pv.custom_minimum_size = Vector2(150, 72)
			buttons.add_child(pv)
			if not e.has("ach") and not e.has("special"):
				var b := UI.button(Loc.t("buy_cost", [e.cost]), func(): _buy_extra(e.id), "WarmButton")
				b.disabled = not Restoration.can_buy_extra(App.data, e.id)
				b.custom_minimum_size = Vector2(150, Style.MIN_TOUCH)
				buttons.add_child(b)
			trail = buttons
		var title := Loc.t("extra_" + str(e.id))
		var row := UI.row(lead, title, sub, trail)
		if owned:
			row.get_child(1).add_child(UI.tag(Loc.t("owned"), Style.TEAL_SOFT, Style.TEAL_DARK))
		panel.add_child(UI.card(row, "CardPanel" if owned else "SoftPanel"))

## A décor swatch: the option's colour (or the category icon), with a tick
## or padlock drawn on top so the state never depends on colour.
class _Swatch extends Control:
	var col := Color.WHITE
	var has_col := false
	var checker := false
	var icon := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		draw_circle(c, r, Style.PAPER)
		if has_col:
			draw_circle(c, r - 3, col)
			if checker:
				for k in 4:
					var a := k * PI / 2
					var pts := PackedVector2Array([c])
					for j in 7:
						var t := a + (PI / 2) * j / 6.0
						pts.append(c + Vector2(cos(t), sin(t)) * (r - 3))
					if k % 2 == 0:
						draw_colored_polygon(pts, Color("f4efe6"))
		else:
			draw_circle(c, r - 3, Style.TEAL_SOFT)
		if icon != "":
			var ink := Color.WHITE if (has_col and col.get_luminance() < 0.5) else Style.TEAL_DARK
			if has_col and icon in ["check", "lock"]:
				draw_circle(c, r * 0.55, Color(0, 0, 0, 0.35))
				ink = Color.WHITE
			Glyph.paint(self, icon, Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), ink)
		draw_arc(c, r - 1, 0, TAU, 32, Color(Style.INK, 0.15), 2, true)

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
			App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_body"), [[Loc.t("lovely"), func(): pass, ""]], null, "spark"))
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
