extends Control
## Puzzle gameplay. The view is a pure function of PuzzleSession state plus
## short-lived effects. A tap during an animation first snaps all effects to
## their end (no lost or duplicated state), then processes the new tap.

const TUTORIAL_STEPS := {
	"tut_tap": ["tut_tap_1", "tut_tap_2"],
	"tut_counter": ["tut_counter_1", "tut_counter_2", "tut_counter_3"],
	"tut_priority": ["tut_priority_1", "tut_priority_2"],
}

var kind := "campaign"          # "campaign" | "daily"
var level_id := ""
var date_key := ""
var def: LevelDef
var ps: PuzzleSession
var attempt := 0
var started_ms := 0
var hint_crate := -1
var free_hints := 1
var _finished_handled := false
var _lost_reported := false
var _hint_thread_busy := false

var orders_row: HBoxContainer
var order_cards: Array = []
var queue_label: Label
var queue_icons: Control
var counter: CounterView
var counter_label: Label
var status_label: Label
var crates_row: HBoxContainer
var crate_views: Array = []
var fx_layer: Control
var title_label: Label
var undo_btn: Button
var hint_btn: Button
var coach: PanelContainer
var coach_label: Label
var _tweens: Array = []
var _fx_nodes: Array = []
var _pressed_crate := -1

func setup(params: Dictionary) -> void:
	kind = params.get("kind", "campaign")
	level_id = params.get("id", "")
	date_key = params.get("date", "")
	def = App.progression.def_for(level_id)
	if def == null:
		App.main.goto("home", {}, false)
		return
	_build()
	var cur: Dictionary = App.data.current
	if cur.get("id", "") == level_id and cur.get("kind", "") == kind and cur.has("session"):
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

func _new_attempt(is_retry: bool) -> void:
	ps = PuzzleSession.start(def)
	attempt += 1
	started_ms = Time.get_ticks_msec()
	free_hints = 1
	hint_crate = -1
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
	var root := UI.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# top bar
	var top := UI.hbox(12)
	top.add_child(UI.icon_button("pause", "", _open_pause, "SecondaryButton", 88))
	title_label = UI.label("", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = _title()
	top.add_child(title_label)
	var help := UI.icon_button("help", "", func(): App.main.goto("help"), "SecondaryButton", 88)
	top.add_child(help)
	root.add_child(top)
	# queue
	var qrow := UI.hbox(10)
	queue_label = UI.label("", "SoftLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	qrow.add_child(queue_label)
	queue_icons = Control.new()
	queue_icons.custom_minimum_size = Vector2(0, 44)
	queue_icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_icons.draw.connect(_draw_queue)
	qrow.add_child(queue_icons)
	root.add_child(qrow)
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
	counter.custom_minimum_size = Vector2(0, 132)
	root.add_child(counter)
	status_label = UI.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	status_label.custom_minimum_size = Vector2(0, 40)
	status_label.add_theme_font_size_override("font_size", Style.fs(26))
	root.add_child(status_label)
	# coach bubble (tutorial) sits in the layout flow, never over crates
	coach = PanelContainer.new()
	coach.theme_type_variation = "SoftPanel"
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
		cv.custom_minimum_size = Vector2(0, 260)
		cv.pressed_down.connect(_on_crate_down)
		cv.released.connect(_on_crate_up)
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

func _title() -> String:
	if kind == "daily":
		return Loc.t("daily_title")
	return Loc.t("level_n", [App.progression.campaign_index(level_id) + 1])

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
	return 84 + rows * (isz + 10) + (64 if two else 0)

# --------------------------------------------------------------------- render

func _refresh() -> void:
	var s := ps.state
	for t in order_cards.size():
		var oc: OrderCard = order_cards[t]
		var o := s.tray_order[t]
		oc.set_order(o, def.orders[o] if o >= 0 else [], s.tray_stage[t], s.tray_fill[t])
		oc.in_flight = {}
		oc.highlight = false
		oc.hint_glow = false
	var coach_target := _coach_target()
	for i in crate_views.size():
		var cv: CrateView = crate_views[i]
		var c: PackedInt32Array = def.crates[i]
		cv.set_items(c.slice(s.crate_pos[i]))
		cv.highlight = (i == hint_crate) or (i == coach_target)
		cv.hide_front = false
		cv.dim = not Rules.is_legal(s, i) and s.crate_remaining(i) > 0
	counter.hidden_slots = {}
	counter.preview_slot = -1
	counter.set_slots(s.counter, def.counter_slots)
	var remaining := def.orders.size() - s.next_order
	queue_label.text = Loc.t("queue_more", [remaining]) if remaining > 0 else Loc.t("queue_last")
	queue_icons.queue_redraw()
	var free := s.counter_free()
	counter_label.text = Loc.t("counter_label", [s.counter_used(), s.counter.size()])
	counter_label.add_theme_color_override("font_color", Style.WARN if free <= 1 and s.counter.size() > 1 else Style.INK_SOFT)
	undo_btn.disabled = not ps.can_undo()
	if status_label.get_meta("sticky", false) == false:
		status_label.text = Loc.t("counter_full") if free == 0 else (Loc.t("counter_one_left") if free == 1 and s.counter.size() > 1 else "")

func _draw_queue() -> void:
	var s := ps.state if ps else null
	if s == null:
		return
	var x := 4.0
	var rtl := Loc.is_rtl()
	var w := queue_icons.size.x
	for k in 3:
		var o := s.next_order + k
		if o >= def.orders.size():
			break
		var st: PackedInt32Array = def.orders[o][0]
		for p in Products.COUNT:
			if st[p] > 0:
				var cx := x + 20
				ProductArt.draw(queue_icons, p, Vector2(w - cx if rtl else cx, 22), 38, 0.75)
				x += 42
		if def.orders[o].size() > 1:
			var cx2 := x + 8
			queue_icons.draw_string(Style.font_bold, Vector2(w - cx2 - 16 if rtl else cx2, 32), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Style.INK_SOFT)
			x += 24
		x += 18
		if x > w - 60:
			break

# --------------------------------------------------------------------- input

func _on_crate_down(i: int) -> void:
	_finish_effects()
	_pressed_crate = i
	var pv := Rules.preview(ps.state, i)
	if pv.dest == Rules.Dest.TRAY:
		order_cards[pv.tray].highlight = true
		order_cards[pv.tray].queue_redraw()
	elif pv.dest == Rules.Dest.COUNTER:
		counter.preview_slot = pv.slot
		counter.queue_redraw()

func _on_crate_up(i: int, inside: bool) -> void:
	for oc in order_cards:
		oc.highlight = false
		oc.queue_redraw()
	counter.preview_slot = -1
	counter.queue_redraw()
	if _pressed_crate != i or not inside:
		_pressed_crate = -1
		return
	_pressed_crate = -1
	tap(i)

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
	if ps.state.crate_remaining(i) > 0:
		status_label.text = Loc.t("invalid_no_space")
		status_label.set_meta("sticky", true)

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
				_fly(e.product, from, oc.product_global_pos(e.product), 0.0, fly, func():
					_land_tray(oc, e.product))
				App.audio.play("place")
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
				_fly(e.product, counter.slot_global_center(e.slot), oc2.product_global_pos(e.product), t, fly, func():
					_land_tray(oc2, e.product))
				t += App.dur(0.06)
			Rules.EV_STAGE:
				_delay(t + fly, func(): App.audio.play("stage"); _pop(order_cards[e.tray]))
			Rules.EV_DELIVER:
				_ghost_delivery(e.tray, e.order, before, t + fly)
				_delay(t + fly, func(): App.audio.play("deliver"); App.haptic(20))
			Rules.EV_ARRIVE:
				_slide_in(order_cards[e.tray], t + fly)

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
	var mid := (sp.position + target) / 2 + Vector2(0, -60)
	if App.reduced_motion():
		tw.tween_property(sp, "position", target, d)
	else:
		tw.tween_method(func(k: float):
			sp.position = (1 - k) * (1 - k) * (inv * from - sp.size / 2) + 2 * (1 - k) * k * mid + k * k * target
			sp.scale = Vector2.ONE * (1.0 + 0.15 * sin(k * PI)), 0.0, 1.0, d).set_trans(Tween.TRANS_SINE)
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
	tw.tween_property(n, "scale", Vector2(1.05, 1.05), 0.09)
	tw.tween_property(n, "scale", Vector2.ONE, 0.12)

## A copy of the completed order lifts away with a tick while the new order
## (already in the real card) fades in underneath.
func _ghost_delivery(tray: int, order: int, before: PuzzleState, t: float) -> void:
	var oc: OrderCard = order_cards[tray]
	var g := OrderCard.new()
	g.tray = tray
	var st: Array = def.orders[order]
	var last: PackedInt32Array = st[st.size() - 1]
	g.set_order(order, st, st.size() - 1, last)
	g.size = oc.size
	g.global_position = oc.global_position
	fx_layer.add_child(g)
	_fx_nodes.append(g)
	g.position = fx_layer.get_global_transform().affine_inverse() * oc.global_position
	var check := Glyph.new()
	check.kind = "check"
	check.color = Style.TEAL
	check.size = Vector2(120, 120)
	check.position = g.size / 2 - Vector2(60, 60)
	check.modulate.a = 0.0
	g.add_child(check)
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_interval(t)
	tw.tween_property(check, "modulate:a", 1.0, App.dur(0.12))
	tw.tween_interval(App.dur(0.18))
	tw.set_parallel()
	tw.tween_property(g, "position:y", g.position.y - (0 if App.reduced_motion() else 60), App.dur(0.3))
	tw.tween_property(g, "modulate:a", 0.0, App.dur(0.3))
	tw.set_parallel(false)
	tw.tween_callback(func(): g.queue_free(); _fx_nodes.erase(g))

func _slide_in(oc: OrderCard, t: float) -> void:
	oc.modulate.a = 0.0
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_interval(t + App.dur(0.3))
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
	if counter:
		counter.hidden_slots = {}
		counter.queue_redraw()

# --------------------------------------------------------------------- actions

func _on_undo() -> void:
	_finish_effects()
	if ps.undo():
		App.audio.play("undo")
		App.analytics.event("undo", {"level": level_id})
		hint_crate = -1
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
	WorkerThreadPool.add_task(task)

## Runs on a worker thread over private copies of recent snapshots.
static func _undos_needed(hist: Array) -> int:
	for back in range(1, mini(8, hist.size()) + 1):
		if Solver.new(6000).solve(hist[hist.size() - back]).status == Solver.SOLVED:
			return back
	return -1

func _hint_done(status: String, crate: int, back: int, key: String) -> void:
	_hint_thread_busy = false
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
	var res := {}
	if kind == "campaign":
		res = Progression.record_win(App.data, level_id, stars)
	else:
		res = {"first_daily": Progression.record_daily(App.data, date_key, stars, ps.state.moves)}
		if res.first_daily:
			App.analytics.event("daily_completed", {"stars": stars, "moves": ps.state.moves})
	App.analytics.event_once("%s-%d-%d-done" % [level_id, attempt, started_ms], "level_complete",
		{"level": level_id, "kind": kind, "stars": stars, "moves": ps.state.moves, "secs": secs,
		"undos": ps.undo_count, "hints": ps.hints_used})
	var tut := str(def.meta.get("tutorial", ""))
	if tut != "" and not App.data.tutorial.done.has(tut):
		App.data.tutorial.done[tut] = true
		App.analytics.event("tutorial_completed", {"step": tut})
	App.data.current = {}
	App.save_now()
	App.audio.play("win")
	App.haptic(40)
	coach.visible = false
	var d := WinPanel.create(self, kind, stars, res, ps)
	_delay(App.dur(0.55), func(): App.main.show_overlay(d))

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
	var d := Dialog.make(Loc.t("lost_title"), Loc.t("lost_body"), buttons)
	_delay(App.dur(0.45), func(): if ps.is_lost(): App.main.show_overlay(d))

func _open_pause() -> void:
	_finish_effects()
	var info := UI.label(Loc.t("star_rules", [Scoring.par_counter(def)]), "SoftLabel")
	info.custom_minimum_size = Vector2(540, 0)
	var d := Dialog.make(Loc.t("paused"), "", [
		[Loc.t("resume"), func(): pass, ""],
		[Loc.t("restart"), _on_restart, "SecondaryButton"],
		[Loc.t("settings"), func(): App.main.goto("settings"), "SecondaryButton"],
		[Loc.t("quit_to_map") if kind == "campaign" else Loc.t("quit_to_home"), func(): App.main.back(), "SecondaryButton"],
	], info)
	App.main.show_overlay(d)

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
	if ps == null or ps.is_won():
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
