extends Control
## Puzzle gameplay. The view is a pure function of PuzzleSession state plus
## short-lived effects. A tap during an animation first snaps all effects to
## their end (no lost or duplicated state), then processes the new tap.

const TUTORIAL_STEPS := {
	"tut_tap": ["tut_tap_1", "tut_tap_2"],
	"tut_counter": ["tut_counter_1", "tut_counter_2", "tut_counter_3"],
	"tut_priority": ["tut_priority_1", "tut_priority_2"],
	"tut_fresh": ["tut_fresh_1", "tut_fresh_2", "tut_fresh_3"],
	"tut_bag": ["tut_bag_1", "tut_bag_2"],
	"tut_lock": ["tut_lock_1", "tut_lock_2"],
	"tut_two_stage": ["tut_two_stage_1", "tut_two_stage_2"],
}
const STREAK_WORDS := {3: "streak_3", 5: "streak_5", 8: "streak_8", 12: "streak_12"}

var kind := "campaign"          # "campaign" | "daily" | "rush"
var level_id := ""
var date_key := ""
var def: LevelDef
var ps: PuzzleSession
var attempt := 0
var started_ms := 0
var hint_crate := -1
var free_hints := 1
var streak := 0
var best_streak := 0
var _finished_handled := false
var _lost_reported := false
var _hint_thread_busy := false
var _hint_task := -1

var backdrop: Backdrop
var orders_row: HBoxContainer
var order_cards: Array = []
var progress: _ProgressBar
var counter: CounterView
var counter_label: Label
var status_label: Label
var crates_row: HBoxContainer
var crate_views: Array = []
var fx_layer: Control
var title_label: Label
var sub_label: Label
var undo_btn: Button
var hint_btn: Button
var coach: PanelContainer
var coach_label: Label
var guide: Fx.GuideLine
var _tweens: Array = []
var _fx_nodes: Array = []
var _pressed_crate := -1

func setup(params: Dictionary) -> void:
	kind = params.get("kind", "campaign")
	level_id = params.get("id", "")
	date_key = params.get("date", "")
	def = App.progression.def_for(level_id)
	if def == null or (kind == "rush" and App.rush == null):
		App.main.goto("home", {}, false)
		return
	_build()
	var cur: Dictionary = App.data.current
	if kind != "rush" and cur.get("id", "") == level_id and cur.get("kind", "") == kind and cur.has("session"):
		ps = PuzzleSession.restore(def, cur.session)
		attempt = int(cur.get("attempt", 1))
	if ps == null:
		_new_attempt(false)
	else:
		started_ms = Time.get_ticks_msec()
		free_hints = maxi(0, 1 - ps.hints_used)
	_refresh()
	_update_coach()
	if ps.is_lost():
		_show_lost.call_deferred()
	elif ps.state.moves == 0 and kind == "campaign":
		Story.level_start(level_id)

func _new_attempt(is_retry: bool) -> void:
	ps = PuzzleSession.start(def)
	attempt += 1
	started_ms = Time.get_ticks_msec()
	free_hints = 1
	hint_crate = -1
	streak = 0
	best_streak = 0
	_finished_handled = false
	_lost_reported = false
	App.data.stats.levels_played = int(App.data.stats.levels_played) + 1
	App.analytics.event("level_retry" if is_retry else "level_start", {"level": level_id, "kind": kind, "attempt": attempt})
	var tut := str(def.meta.get("tutorial", ""))
	if tut != "" and not App.data.tutorial.done.has(tut):
		App.analytics.event("tutorial_started", {"step": tut})
	persist()

# --------------------------------------------------------------------- layout

func _build() -> void:
	for c in get_children():
		c.queue_free()
	backdrop = Backdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var root := UI.vbox(6)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# top bar
	var top := UI.hbox(12)
	top.add_child(UI.icon_button("pause", "", _open_pause, "SecondaryButton", 88))
	var titles := UI.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = UI.label(_title(), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	titles.add_child(title_label)
	sub_label = UI.label(_subtitle(), "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	sub_label.add_theme_font_size_override("font_size", Style.fs(22))
	sub_label.visible = sub_label.text != ""
	titles.add_child(sub_label)
	top.add_child(titles)
	top.add_child(UI.icon_button("help", "", func(): App.main.goto("help"), "SecondaryButton", 88))
	root.add_child(top)
	# order progress + queue
	progress = _ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 92)
	progress.game = self
	root.add_child(progress)
	# orders
	orders_row = UI.hbox(12)
	orders_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var card_h := _card_height()
	for t in mini(def.trays, 3):
		var oc := OrderCard.new()
		oc.tray = t
		oc.custom_minimum_size = Vector2(0, card_h)
		oc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orders_row.add_child(oc)
		order_cards.append(oc)
	root.add_child(orders_row)
	# counter
	counter_label = UI.label("", "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	root.add_child(counter_label)
	counter = CounterView.new()
	counter.custom_minimum_size = Vector2(0, 112)
	root.add_child(counter)
	status_label = UI.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	status_label.custom_minimum_size = Vector2(0, 40)
	status_label.add_theme_font_size_override("font_size", Style.fs(26))
	root.add_child(status_label)
	# coach bubble (tutorial) sits in the layout flow, never over crates
	coach = PanelContainer.new()
	coach.add_theme_stylebox_override("panel", Style.box(Style.PAPER, 22, Style.GOLD, 3))
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_label = UI.label("")
	coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_label.add_theme_font_size_override("font_size", Style.fs(26))
	coach.add_child(coach_label)
	coach.visible = false
	root.add_child(coach)
	# crates
	crates_row = UI.hbox(8)
	crates_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crates_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in def.crates.size():
		var cv := CrateView.new()
		cv.index = i
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.custom_minimum_size = Vector2(0, 220)
		cv.pressed_down.connect(_on_crate_down)
		cv.released.connect(_on_crate_up)
		cv.dragged.connect(_on_crate_drag)
		crates_row.add_child(cv)
		crate_views.append(cv)
	root.add_child(crates_row)
	# bottom controls (thumb zone)
	var bottom := UI.hbox(18)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var u := UI.icon_button("undo", Loc.t("undo"), _on_undo, "SecondaryButton", 100)
	undo_btn = u.get_meta("button")
	bottom.add_child(u)
	var h := UI.icon_button("hint", Loc.t("hint"), _on_hint, "SecondaryButton", 100)
	hint_btn = h.get_meta("button")
	bottom.add_child(h)
	bottom.add_child(UI.icon_button("restart", Loc.t("restart"), _on_restart, "SecondaryButton", 100))
	root.add_child(bottom)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	guide = Fx.GuideLine.new()
	guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	guide.visible = false
	fx_layer.add_child(guide)

func _process(delta: float) -> void:
	if crates_row and backdrop:
		var y := (crates_row.get_global_rect().position.y - get_global_rect().position.y) + 40
		backdrop.set_split(y)
	# Rush clock: counts up only while the puzzle is in play and unobstructed.
	if kind == "rush" and App.rush and ps and not ps.is_won() and App.main.overlays.is_empty():
		App.rush.tick(delta)
		var t := RushRun.fmt_time(int(App.rush.elapsed_ms))
		if sub_label.text != t:
			sub_label.text = t
			sub_label.visible = true

func _title() -> String:
	match kind:
		"daily": return Loc.t("daily_title")
		"rush": return Loc.t("rush_title_n", [App.rush.index + 1 if App.rush else 1, RushRun.LENGTH])
	return Loc.t("level_n", [App.progression.campaign_index(level_id) + 1])

func _subtitle() -> String:
	if kind == "rush" and App.rush:
		return RushRun.fmt_time(int(App.rush.elapsed_ms))
	if kind != "campaign":
		return ""
	var ch := App.progression.chapter_of(App.progression.campaign_index(level_id))
	return Loc.t(ch) if ch != "" else ""

func _card_height() -> int:
	var rows := 1
	var two := false
	for o in def.orders:
		for st in o:
			var n := 0
			for p in Products.COUNT:
				if st[p] > 0:
					n += 1
			rows = maxi(rows, n)
		if o.size() > 1:
			two = true
	var isz := 70
	return 92 + rows * (isz + 10) + (64 if two else 0)

# --------------------------------------------------------------------- render

func _refresh() -> void:
	var s := ps.state
	for t in order_cards.size():
		var oc: OrderCard = order_cards[t]
		var o := s.tray_order[t]
		oc.set_order(o, def.orders[o] if o >= 0 else [], s.tray_stage[t], s.tray_fill[t])
		oc.customer = Customers.for_order(def, o) if o >= 0 else ""
		oc.mood = 2
		oc.in_flight = {}
		oc.highlight = false
		oc.hint_glow = false
	var coach_target := _coach_target()
	for i in crate_views.size():
		var cv: CrateView = crate_views[i]
		var c: PackedInt32Array = def.crates[i]
		var vis := PackedInt32Array()
		var fr: Array = []
		for k in range(s.crate_pos[i], c.size()):
			vis.append(Rules.visible_product(s, i, k))
			fr.append((def.flag(i, k) & LevelDef.FRESH) != 0 and Rules.visible_product(s, i, k) >= 0)
		cv.set_state(vis, fr, Rules.lock_remaining(s, i), _badge_for(i))
		cv.highlight = (i == hint_crate) or (i == coach_target)
		cv.hide_front = false
		cv.lifted = false
		cv.dim = not Rules.is_legal(s, i) and s.crate_remaining(i) > 0
	counter.hidden_slots = {}
	counter.preview_slot = -1
	counter.set_slots(s.counter, def.counter_slots)
	progress.queue_redraw()
	var free := s.counter_free()
	counter_label.text = Loc.t("counter_label", [s.counter_used(), s.counter.size()])
	counter_label.add_theme_color_override("font_color", Style.WARN if free <= 1 and s.counter.size() > 1 else Style.INK_SOFT)
	undo_btn.disabled = not ps.can_undo()
	if status_label.get_meta("sticky", false) == false:
		status_label.text = Loc.t("counter_full") if free == 0 else (Loc.t("counter_one_left") if free == 1 and s.counter.size() > 1 else "")

func _badge_for(i: int) -> Dictionary:
	var pv := Rules.preview(ps.state, i)
	match pv.dest:
		Rules.Dest.TRAY: return {"kind": "tray", "tray": pv.tray}
		Rules.Dest.COUNTER: return {"kind": "counter"}
	match pv.block:
		Rules.Block.FRESH: return {"kind": "fresh"}
		Rules.Block.FULL: return {"kind": "full"}
	return {}

# --------------------------------------------------------------------- input

func _on_crate_down(i: int) -> void:
	_finish_effects()
	_pressed_crate = i
	var pv := Rules.preview(ps.state, i)
	var cv: CrateView = crate_views[i]
	if pv.dest == Rules.Dest.NONE:
		return
	cv.lifted = true
	cv.queue_redraw()
	var to := _dest_point(pv)
	if pv.dest == Rules.Dest.TRAY:
		order_cards[pv.tray].highlight = true
		order_cards[pv.tray].queue_redraw()
	else:
		counter.preview_slot = pv.slot
		counter.queue_redraw()
	guide.set_points(_to_fx(cv.front_global_center() + Vector2(0, -20)), _to_fx(to),
		Style.TEAL if pv.dest == Rules.Dest.TRAY else Style.WOOD_DARK)
	guide.visible = true

func _on_crate_drag(i: int, gpos: Vector2) -> void:
	if i != _pressed_crate or not guide.visible:
		return
	var pv := Rules.preview(ps.state, i)
	guide.set_points(_to_fx(gpos), _to_fx(_dest_point(pv)), guide.color)

func _on_crate_up(i: int, gpos: Vector2) -> void:
	guide.visible = false
	for oc in order_cards:
		oc.highlight = false
		oc.queue_redraw()
	counter.preview_slot = -1
	counter.queue_redraw()
	var cv: CrateView = crate_views[i]
	cv.lifted = false
	cv.queue_redraw()
	if _pressed_crate != i:
		return
	_pressed_crate = -1
	# Releasing over the crate, its destination, or anywhere near the path
	# confirms. Dragging away and letting go elsewhere cancels.
	var pv := Rules.preview(ps.state, i)
	var ok := cv.get_global_rect().grow(24).has_point(gpos)
	if not ok and pv.dest == Rules.Dest.TRAY:
		ok = order_cards[pv.tray].get_global_rect().grow(30).has_point(gpos)
	elif not ok and pv.dest == Rules.Dest.COUNTER:
		ok = counter.get_global_rect().grow(30).has_point(gpos)
	if ok:
		tap(i)

func _dest_point(pv: Dictionary) -> Vector2:
	if pv.dest == Rules.Dest.TRAY:
		return order_cards[pv.tray].product_global_pos(pv.product)
	if pv.dest == Rules.Dest.COUNTER:
		return counter.slot_global_center(pv.slot)
	return Vector2.ZERO

func _to_fx(g: Vector2) -> Vector2:
	return fx_layer.get_global_transform().affine_inverse() * g

## Public for automated interaction tests.
func tap(i: int) -> void:
	_finish_effects()
	if ps.is_won():
		return
	var before := ps.state.copy()
	var ev := ps.tap(i)
	if ev.is_empty():
		_invalid(i)
		return
	status_label.set_meta("sticky", false)
	hint_crate = -1
	App.haptic(12)
	_track_streak(ev, i)
	_refresh()
	_animate(before, ev)
	_advance_coach()
	persist()
	if ps.is_won():
		_on_won()
	elif ps.is_lost():
		_show_lost()

func _invalid(i: int) -> void:
	App.audio.play("invalid")
	App.haptic(30)
	crate_views[i].shake()
	var pv := Rules.preview(ps.state, i)
	var msg := ""
	match pv.block:
		Rules.Block.LOCKED: msg = Loc.t("invalid_locked", [Rules.lock_remaining(ps.state, i)])
		Rules.Block.FRESH: msg = Loc.t("invalid_fresh")
		Rules.Block.FULL: msg = Loc.t("invalid_no_space")
	if msg != "":
		status_label.text = msg
		status_label.set_meta("sticky", true)

## Consecutive moves that go straight into orders build a streak. Purely
## celebratory: streaks never affect stars, tokens or the rules.
func _track_streak(ev: Array, crate: int) -> void:
	var direct := false
	for e in ev:
		if e.type == Rules.EV_TO_TRAY:
			direct = true
	if not direct:
		streak = 0
		return
	streak += 1
	best_streak = maxi(best_streak, streak)
	if streak >= 3:
		var word: String = Loc.t(STREAK_WORDS[streak]) if STREAK_WORDS.has(streak) else Loc.t("streak_n", [streak])
		var at: Vector2 = crate_views[crate].get_global_rect().get_center() + Vector2(0, -60)
		_fx_nodes.append(Fx.float_text(fx_layer, at, word, Style.TERRACOTTA if streak >= 5 else Style.TEAL_DARK, 36 if streak < 8 else 44))
		App.audio.play("combo", minf(1.0 + 0.05 * (streak - 3), 1.5))

# --------------------------------------------------------------------- effects

func _animate(before: PuzzleState, ev: Array) -> void:
	var t := 0.0
	var fly := App.dur(0.2)
	for e in ev:
		match e.type:
			Rules.EV_TO_TRAY:
				var oc: OrderCard = order_cards[e.tray]
				oc.in_flight[e.product] = int(oc.in_flight.get(e.product, 0)) + 1
				oc.queue_redraw()
				var from: Vector2 = crate_views[e.crate].front_global_center()
				var to: Vector2 = oc.product_global_pos(e.product)
				_fly(e.product, from, to, 0.0, fly, func():
					_land_tray(oc, e.product)
					_fx_nodes.append(Fx.burst(fx_layer, to, "sparkle")))
				App.audio.play("place", 1.0 + 0.03 * mini(streak, 8))
				t = fly
			Rules.EV_TO_COUNTER:
				counter.hidden_slots[e.slot] = true
				counter.queue_redraw()
				var from2: Vector2 = crate_views[e.crate].front_global_center()
				_fly(e.product, from2, counter.slot_global_center(e.slot), 0.0, fly, func():
					counter.hidden_slots.erase(e.slot); counter.queue_redraw())
				App.audio.play("counter")
				t = fly
			Rules.EV_COUNTER_TO_TRAY:
				var oc2: OrderCard = order_cards[e.tray]
				oc2.in_flight[e.product] = int(oc2.in_flight.get(e.product, 0)) + 1
				oc2.queue_redraw()
				var to2: Vector2 = oc2.product_global_pos(e.product)
				_fly(e.product, counter.slot_global_center(e.slot), to2, t, fly, func():
					_land_tray(oc2, e.product)
					_fx_nodes.append(Fx.burst(fx_layer, to2, "sparkle")))
				t += App.dur(0.06)
			Rules.EV_STAGE:
				var oc3: OrderCard = order_cards[e.tray]
				_delay(t + fly, func():
					App.audio.play("stage")
					_pop(oc3)
					_fx_nodes.append(Fx.burst(fx_layer, oc3.get_global_rect().get_center(), "sparkle")))
			Rules.EV_DELIVER:
				_ghost_delivery(e.tray, e.order, before, t + fly)
				var oc4: OrderCard = order_cards[e.tray]
				_delay(t + fly, func():
					App.audio.play("deliver")
					App.haptic(20)
					_fx_nodes.append(Fx.burst(fx_layer, oc4.get_global_rect().get_center(), "pop")))
			Rules.EV_ARRIVE:
				_slide_in(order_cards[e.tray], t + fly)
			Rules.EV_REVEAL:
				var cv: CrateView = crate_views[e.crate]
				_delay(fly * 0.5, func():
					App.audio.play("bag")
					_pop(cv)
					_fx_nodes.append(Fx.burst(fx_layer, cv.front_global_center(), "sparkle", [Color("c9a26b"), Style.GOLD])))
			Rules.EV_UNLOCK:
				var cv2: CrateView = crate_views[e.crate]
				_delay(t + fly + App.dur(0.15), func():
					App.audio.play("unlock")
					cv2.flash_unlock()
					_fx_nodes.append(Fx.burst(fx_layer, cv2.get_global_rect().get_center(), "pop", [Style.GOLD, Style.WOOD_LIGHT])))
	progress.queue_redraw()

func _land_tray(oc: OrderCard, p: int) -> void:
	oc.in_flight[p] = maxi(0, int(oc.in_flight.get(p, 0)) - 1)
	oc.queue_redraw()

func _fly(p: int, from: Vector2, to: Vector2, delay: float, d: float, done: Callable) -> void:
	var sp := ProductSprite.new(p, 96.0)
	var inv := fx_layer.get_global_transform().affine_inverse()
	sp.position = inv * from - sp.size / 2
	fx_layer.add_child(sp)
	_fx_nodes.append(sp)
	var target := inv * to - sp.size / 2
	var tw := create_tween()
	_tweens.append(tw)
	if delay > 0:
		sp.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func(): sp.visible = true)
	var mid := (sp.position + target) / 2 + Vector2(0, -70)
	if App.reduced_motion():
		tw.tween_property(sp, "position", target, d)
	else:
		tw.tween_method(func(k: float):
			sp.position = (1 - k) * (1 - k) * (inv * from - sp.size / 2) + 2 * (1 - k) * k * mid + k * k * target
			sp.scale = Vector2.ONE * (1.0 + 0.18 * sin(k * PI)), 0.0, 1.0, d).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		done.call()
		sp.queue_free()
		_fx_nodes.erase(sp))

func _delay(t: float, cb: Callable) -> void:
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_interval(t)
	tw.tween_callback(cb)

func _pop(n: Control) -> void:
	if App.reduced_motion():
		return
	n.pivot_offset = n.size / 2
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_property(n, "scale", Vector2(1.06, 1.06), 0.09)
	tw.tween_property(n, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A copy of the completed order lifts away with a tick and a happy customer
## while the new order (already in the real card) fades in underneath.
func _ghost_delivery(tray: int, order: int, before: PuzzleState, t: float) -> void:
	var oc: OrderCard = order_cards[tray]
	var g := OrderCard.new()
	g.tray = tray
	var st: Array = def.orders[order]
	var last: PackedInt32Array = st[st.size() - 1]
	g.set_order(order, st, st.size() - 1, last)
	g.customer = Customers.for_order(def, order)
	g.mood = 1
	g.size = oc.size
	fx_layer.add_child(g)
	_fx_nodes.append(g)
	g.position = fx_layer.get_global_transform().affine_inverse() * oc.global_position
	g.pivot_offset = g.size / 2
	var check := Glyph.new()
	check.kind = "check"
	check.color = Style.TEAL
	check.size = Vector2(120, 120)
	check.position = g.size / 2 - Vector2(60, 40)
	check.modulate.a = 0.0
	g.add_child(check)
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_interval(t)
	tw.tween_property(check, "modulate:a", 1.0, App.dur(0.12))
	if not App.reduced_motion():
		tw.tween_property(g, "scale", Vector2(1.05, 1.05), 0.1)
		tw.tween_property(g, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(App.dur(0.22))
	tw.set_parallel()
	tw.tween_property(g, "position:y", g.position.y - (0 if App.reduced_motion() else 70), App.dur(0.32))
	tw.tween_property(g, "modulate:a", 0.0, App.dur(0.32))
	tw.set_parallel(false)
	tw.tween_callback(func(): g.queue_free(); _fx_nodes.erase(g))

func _slide_in(oc: OrderCard, t: float) -> void:
	oc.modulate.a = 0.0
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_interval(t + App.dur(0.4))
	tw.tween_property(oc, "modulate:a", 1.0, App.dur(0.2))

## Snap every running effect to its final state immediately.
func _finish_effects() -> void:
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	for n in _fx_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_fx_nodes.clear()
	for oc in order_cards:
		oc.in_flight = {}
		oc.modulate.a = 1.0
		oc.scale = Vector2.ONE
		oc.queue_redraw()
	for cv in crate_views:
		cv.scale = Vector2.ONE
	if counter:
		counter.hidden_slots = {}
		counter.queue_redraw()
	if guide:
		guide.visible = false

# --------------------------------------------------------------------- actions

func _on_undo() -> void:
	_finish_effects()
	if ps.undo():
		App.audio.play("undo")
		App.analytics.event("undo", {"level": level_id})
		hint_crate = -1
		streak = 0
		status_label.set_meta("sticky", false)
		_refresh()
		persist()

func _on_restart() -> void:
	_finish_effects()
	if ps.state.moves == 0:
		return
	_new_attempt(true)
	_refresh()
	_update_coach()

func _on_hint() -> void:
	_finish_effects()
	if _hint_thread_busy or ps.is_won():
		return
	if free_hints > 0:
		_run_hint(true)
		return
	var buttons: Array = []
	if App.rewards.available():
		buttons.append([Loc.t("hint_watch_ad"), func(): App.rewards.request("hint", func(): _run_hint(false)), ""])
	buttons.append([Loc.t("close"), func(): pass, "SecondaryButton"])
	App.main.show_overlay(Dialog.make(Loc.t("hint_title"), Loc.t("hint_used_body") if App.rewards.available() else Loc.t("hint_used_noads"), buttons))

func _run_hint(free: bool) -> void:
	App.analytics.event("hint_requested", {"level": level_id, "source": "free" if free else "ad"})
	if free:
		free_hints -= 1
	ps.hints_used += 1
	_hint_thread_busy = true
	status_label.text = Loc.t("hint_thinking")
	status_label.set_meta("sticky", true)
	var snapshot := ps.state.copy()
	var hist: Array = []
	for k in range(maxi(0, ps.history.size() - 8), ps.history.size()):
		hist.append(ps.history[k].copy())
	var task := func():
		var r := Solver.new(30000).solve(snapshot)
		var back := -1
		if r.status == Solver.UNSOLVABLE:
			back = _undos_needed(hist)
		_hint_done.call_deferred(r.status, r.path[0] if r.path.size() > 0 else -1, back, snapshot.key())
	_hint_task = WorkerThreadPool.add_task(task)

## Never free the screen (or quit) while a hint solve is still running on the
## worker pool: wait for it (bounded: 30k solver nodes, well under a second).
func _exit_tree() -> void:
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1

## Runs on a worker thread over private copies of recent snapshots.
static func _undos_needed(hist: Array) -> int:
	for back in range(1, mini(8, hist.size()) + 1):
		if Solver.new(6000).solve(hist[hist.size() - back]).status == Solver.SOLVED:
			return back
	return -1

func _hint_done(status: String, crate: int, back: int, key: String) -> void:
	_hint_thread_busy = false
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1
	if not is_inside_tree() or ps.state.key() != key:
		status_label.set_meta("sticky", false)
		_refresh()
		return
	match status:
		Solver.SOLVED:
			hint_crate = crate
			var pv := Rules.preview(ps.state, crate)
			status_label.text = Loc.t("hint_tap_glow")
			if pv.dest == Rules.Dest.TRAY:
				order_cards[pv.tray].hint_glow = true
		Solver.UNSOLVABLE:
			status_label.text = Loc.t("hint_stuck_undo", [back]) if back > 0 else Loc.t("hint_stuck_restart")
		_:
			status_label.text = Loc.t("hint_timeout")
	status_label.set_meta("sticky", true)
	persist()
	for cv in crate_views:
		cv.highlight = cv.index == hint_crate
		cv.queue_redraw()

# --------------------------------------------------------------------- end states

func _on_won() -> void:
	if _finished_handled:
		return
	_finished_handled = true
	var stars := ps.stars()
	var secs := (Time.get_ticks_msec() - started_ms) / 1000
	var summary := {"kind": kind, "level": level_id, "stars": stars, "moves": ps.state.moves,
		"hints": ps.hints_used, "undos": ps.undo_count, "best_streak": best_streak, "secs": secs,
		"peak": ps.state.peak_counter}
	var res := {}
	match kind:
		"campaign":
			res = Progression.record_win(App.data, level_id, stars)
		"daily":
			res = {"first_daily": Progression.record_daily(App.data, date_key, stars, ps.state.moves)}
			if res.first_daily:
				App.analytics.event("daily_completed", {"stars": stars, "moves": ps.state.moves})
	summary.merge(res)
	res["meta"] = Meta.on_level_won(App.data, def, summary)
	App.analytics.event_once("%s-%d-%d-done" % [level_id, attempt, started_ms], "level_complete",
		{"level": level_id, "kind": kind, "stars": stars, "moves": ps.state.moves, "secs": secs,
		"undos": ps.undo_count, "hints": ps.hints_used})
	var tut := str(def.meta.get("tutorial", ""))
	if tut != "" and not App.data.tutorial.done.has(tut):
		App.data.tutorial.done[tut] = true
		App.analytics.event("tutorial_completed", {"step": tut})
	App.data.current = {}
	App.save_now()
	coach.visible = false
	_celebrate()
	if kind == "rush":
		_delay(App.dur(0.9), func(): App.on_rush_win())
		return
	var d := WinPanel.create(self, kind, stars, res, ps)
	_delay(App.dur(1.0), func(): App.main.show_overlay(d))

## Finish sequence: every ticket cheers, confetti falls, then the card.
func _celebrate() -> void:
	App.audio.play("win")
	App.haptic(40)
	_delay(App.dur(0.35), func():
		var top := get_global_rect().position + Vector2(get_global_rect().size.x / 2, 120)
		_fx_nodes.append(Fx.burst(fx_layer, top, "confetti"))
		for cv in crate_views:
			_pop(cv))

func _show_lost() -> void:
	if not ps.is_lost():
		return
	if not _lost_reported:
		_lost_reported = true
		App.analytics.event("level_failed", {"level": level_id, "moves": ps.state.moves})
	App.audio.play("lose")
	var buttons: Array = []
	buttons.append([Loc.t("undo_free"), _on_undo, ""])
	if ps.can_continue() and App.rewards.available():
		buttons.append([Loc.t("continue_ad"), func():
			App.rewards.request("continue", func():
				if ps.grant_continue():
					App.analytics.event("continue_granted", {"level": level_id})
					_refresh()
					persist()), "WarmButton"])
	buttons.append([Loc.t("restart"), _on_restart, "SecondaryButton"])
	var d := Dialog.make(Loc.t("lost_title"), _lost_reason(), buttons)
	_delay(App.dur(0.45), func(): if ps.is_lost(): App.main.show_overlay(d))

## Says why no move is left, naming the blocking mechanic if there is one.
func _lost_reason() -> String:
	var fresh := false
	var locked := false
	for i in crate_views.size():
		match Rules.preview(ps.state, i).block:
			Rules.Block.FRESH: fresh = true
			Rules.Block.LOCKED: locked = true
	if fresh:
		return Loc.t("lost_body_fresh")
	if locked:
		return Loc.t("lost_body_locked")
	return Loc.t("lost_body")

func _open_pause() -> void:
	_finish_effects()
	for cv in crate_views:
		cv.cancel_press()
	_pressed_crate = -1
	var info := UI.label(Loc.t("star_rules", [Scoring.par_counter(def)]), "SoftLabel")
	info.custom_minimum_size = Vector2(540, 0)
	var leave_text := Loc.t("quit_to_map") if kind == "campaign" else Loc.t("quit_to_home")
	var d := Dialog.make(Loc.t("paused"), "", [
		[Loc.t("resume"), func(): pass, ""],
		[Loc.t("restart"), _on_restart, "SecondaryButton"],
		[Loc.t("settings"), func(): App.main.goto("settings"), "SecondaryButton"],
		[leave_text, _leave, "SecondaryButton"],
	], info)
	App.main.show_overlay(d)

## Leaves the level; progress is kept in App.data.current for "Continue".
func _leave() -> void:
	persist()
	App.main.goto("home", {}, false)
	if kind == "campaign":
		App.main.goto("levels")
	elif kind == "rush":
		App.rush = null
		App.main.goto("daily")

func on_back() -> bool:
	_open_pause()
	return true

# --------------------------------------------------------------------- tutorial

var _coach_step := 0

func _tut_key() -> String:
	var k := str(def.meta.get("tutorial", ""))
	return k if k != "" and not App.data.tutorial.done.has(k) else ""

func _coach_target() -> int:
	if _tut_key() == "" or ps == null or ps.is_won():
		return -1
	var r := Solver.new(2000).solve(ps.state)
	return r.path[0] if r.status == Solver.SOLVED and r.path.size() > 0 else -1

func _update_coach() -> void:
	var k := _tut_key()
	if k == "" or ps.is_won():
		coach.visible = false
		status_label.visible = true
		return
	var steps: Array = TUTORIAL_STEPS.get(k, [])
	if steps.is_empty():
		coach.visible = false
		return
	_coach_step = mini(ps.state.moves, steps.size() - 1)
	coach_label.text = Loc.t(steps[_coach_step])
	coach.visible = true
	status_label.visible = false

func _advance_coach() -> void:
	if _tut_key() != "":
		_update_coach()
	var ct := _coach_target()
	for cv in crate_views:
		cv.highlight = cv.index == ct or cv.index == hint_crate
		cv.queue_redraw()

# --------------------------------------------------------------------- persistence

func persist() -> void:
	if ps == null or ps.is_won() or kind == "rush":
		return
	App.data.current = {"kind": kind, "id": level_id, "date": date_key, "attempt": attempt, "session": ps.to_dict()}
	App.save_soon()

func next_level() -> void:
	var i := App.progression.campaign_index(level_id)
	if i + 1 < App.progression.campaign.size():
		App.main.replace("game", {"kind": "campaign", "id": App.progression.campaign[i + 1].id})
	else:
		App.main.goto("home", {"finale": true}, false)

func replay() -> void:
	App.main.replace("game", {"kind": kind, "id": level_id, "date": date_key})

## Orders delivered so far as a segmented bar, with the next customers queued.
class _ProgressBar extends Control:
	var game: Node

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if game == null or game.ps == null:
			return
		var s: PuzzleState = game.ps.state
		var d: LevelDef = game.def
		var total := d.orders.size()
		var rtl := Loc.is_rtl()
		var txt := Loc.t("orders_progress", [s.completed, total])
		var tw := Style.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(24)).x
		var x0 := 6.0
		draw_string(Style.font_bold, Vector2(size.x - x0 - tw if rtl else x0, 24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(24), Style.INK)
		# segmented bar
		var bx := x0 + tw + 16
		var bw := size.x - bx - x0
		var by := 12.0
		var seg := (bw - (total - 1) * 4) / maxf(1, total)
		for i in total:
			var sx := bx + i * (seg + 4)
			if rtl:
				sx = size.x - sx - seg
			var col := Style.TEAL if i < s.completed else Color(Style.INK_SOFT, 0.18)
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(7)
			draw_style_box(sb, Rect2(sx, by, seg, 16))
			if i < s.completed and seg > 22:
				var cc := Vector2(sx + seg / 2, by + 8)
				draw_polyline(PackedVector2Array([cc + Vector2(-5, 0), cc + Vector2(-1, 4), cc + Vector2(6, -4)]), Color.WHITE, 2.5, true)
		# upcoming customers and what they will ask for first (strategic info)
		var y := 66.0
		var label := Loc.t("next_label") if s.next_order < total else Loc.t("queue_last")
		var lw := Style.font_regular.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22)).x
		draw_string(Style.font_regular, Vector2(size.x - x0 - lw if rtl else x0, y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22), Style.INK_SOFT)
		var x := x0 + lw + 14
		for k in 3:
			var o := s.next_order + k
			if o >= total or x > size.x - 120:
				break
			var a := 1.0 - k * 0.15
			var cx := x + 20
			draw_circle(Vector2(size.x - cx if rtl else cx, y), 21, Style.PAPER)
			CharacterArt.draw(self, Customers.for_order(d, o), Vector2(size.x - cx if rtl else cx, y + 1), 40, 0, a)
			x += 44
			var st: PackedInt32Array = d.orders[o][0]
			for p in Products.COUNT:
				if st[p] > 0:
					var px := x + 16
					ProductArt.draw(self, p, Vector2(size.x - px if rtl else px, y), 32, 0.9 * a)
					x += 33
			if d.orders[o].size() > 1:
				var t := "+"
				draw_string(Style.font_bold, Vector2(size.x - x - 14 if rtl else x, y + 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Style.INK_SOFT)
				x += 18
			x += 18
