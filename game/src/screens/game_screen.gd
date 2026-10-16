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
	"tut_bell": ["tut_bell_1", "tut_bell_2", "tut_bell_3"],
	"tut_oven": ["tut_oven_1", "tut_oven_2"],
}
const BLEED := 160.0
const STREAK_WORDS := {3: "streak_3", 5: "streak_5", 8: "streak_8", 12: "streak_12"}

var kind := "campaign"          # "campaign" | "daily" | "rush" | "challenge"
var screen_mode := "cafe"       # full-bleed background around the board
var challenge_id := ""          # v3 challenge card being played
var level_id := ""
var date_key := ""
var def: LevelDef
var ps: PuzzleSession
var attempt := 0
var started_ms := 0
var hint_crate := -1
var hint_bell := -1             # ticket the hint/coach says to ring
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
var redo_btn: Button
var ledger: LedgerPlay          # v4 expert-mode helper (kind == "ledger")
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
	challenge_id = str(params.get("challenge", ""))
	def = App.progression.def_for(level_id)
	if def == null or (kind == "rush" and App.rush == null):
		App.main.goto("home", {}, false)
		return
	if kind == "ledger":
		ledger = LedgerPlay.new(self)
	screen_mode = "night" if kind == "ledger" else ("bakery" if kind == "bakery" else "cafe")
	_build()
	var cur: Dictionary = App.data.current
	if kind != "rush" and cur.get("id", "") == level_id and cur.get("kind", "") == kind and cur.has("session") \
			and str(cur.get("ch", "")) == challenge_id:
		# Expert pages resume only against identical rules (content hash).
		if kind != "ledger" or str(cur.get("hash", "")) == def.content_hash():
			ps = PuzzleSession.restore(def, cur.session)
			attempt = int(cur.get("attempt", 1))
		elif kind == "ledger":
			App.main.toast(Loc.t("ledger_page_changed"))
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
	var night := kind == "ledger"
	backdrop = Backdrop.new()
	backdrop.mode = "night" if night else ("bakery" if kind == "bakery" else "cafe")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	# bleed under the safe-area margins so the setting reaches the screen edges
	for side in ["offset_left", "offset_top"]:
		backdrop.set(side, -BLEED)
	for side in ["offset_right", "offset_bottom"]:
		backdrop.set(side, BLEED)
	add_child(backdrop)
	var root := UI.vbox(6)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# top bar: pause, title, rules/help (secondary chips, out of the board)
	var top := UI.hbox(12)
	top.add_child(UI.chip("pause", _open_pause, "NightChip" if night else "ChipButton", Style.CHIP, 0, Loc.t("paused")))
	var titles := UI.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	title_label = UI.label(_title(), "NightTitle" if night else "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	UI.fit_font(title_label, 720 - 2 * Style.CHIP - 120, 38, 28)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	titles.add_child(title_label)
	sub_label = UI.label(_subtitle(), "NightCaption" if night else "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	sub_label.visible = sub_label.text != ""
	titles.add_child(sub_label)
	top.add_child(titles)
	if kind == "ledger":
		top.add_child(UI.chip("book", func(): ledger.show_rules(), "NightChip", Style.CHIP, 0, Loc.t("ledger_rules")))
	else:
		top.add_child(UI.chip("help", func(): App.main.goto("help"), "ChipButton", Style.CHIP, 0, Loc.t("help")))
	root.add_child(top)
	# order progress + queue
	progress = _ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 92)
	progress.game = self
	progress.night = night
	root.add_child(progress)
	if ledger:
		root.add_child(ledger.make_strip())
	# orders
	orders_row = UI.hbox(12)
	orders_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var card_h := _card_height()
	for t in mini(def.trays, 3):
		var oc := OrderCard.new()
		oc.tray = t
		oc.custom_minimum_size = Vector2(0, card_h)
		oc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		oc.tapped.connect(_on_ticket)
		orders_row.add_child(oc)
		order_cards.append(oc)
	root.add_child(orders_row)
	# counter, with its caption
	counter_label = UI.label("", "NightSoft" if night else "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	root.add_child(counter_label)
	counter = CounterView.new()
	counter.custom_minimum_size = Vector2(0, 108)
	root.add_child(counter)
	# status line: a reserved row, so messages never shift the board
	status_label = StatusPill.new()
	status_label.custom_minimum_size = Vector2(0, 52)
	root.add_child(status_label)
	# coach bubble (tutorial) sits in the layout flow, never over crates
	coach = PanelContainer.new()
	var csb := Style.box(Style.PAPER, 22, Style.GOLD, 3)
	csb.content_margin_left = 14
	csb.content_margin_top = 10
	csb.content_margin_bottom = 10
	coach.add_theme_stylebox_override("panel", csb)
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crow := UI.hbox(14)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(UI.medallion("hint", Style.GOLD_SOFT, Style.GOLD_EDGE, 56))
	coach_label = UI.label("", "", UI.al())
	coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_label.add_theme_font_size_override("font_size", Style.fs(26))
	crow.add_child(coach_label)
	coach.add_child(crow)
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
		cv.oven = def.id.begins_with("m")
		cv.pressed_down.connect(_on_crate_down)
		cv.released.connect(_on_crate_up)
		cv.dragged.connect(_on_crate_drag)
		crates_row.add_child(cv)
		crate_views.append(cv)
	root.add_child(crates_row)
	# bottom dock (thumb zone): secondary tools, clearly separate from the board
	var dock := PanelContainer.new()
	var dsb := Style.box(Color(Style.NIGHT_2, 0.92) if night else Color(Style.PAPER, 0.9), 30,
		Style.NIGHT_LINE if night else Style.PAPER_EDGE, 2, true)
	dsb.content_margin_top = 10
	dsb.content_margin_bottom = 8
	dock.add_theme_stylebox_override("panel", dsb)
	var bottom := UI.hbox(10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_child(bottom)
	var chip_var := "NightChip" if night else "ChipButton"
	var u := _dock_item("undo", Loc.t("undo"), _on_undo, chip_var, night)
	undo_btn = u.get_meta("button")
	bottom.add_child(u)
	var h := _dock_item("hint", Loc.t("hint"), _on_hint, chip_var, night)
	hint_btn = h.get_meta("button")
	bottom.add_child(h)
	if kind == "ledger":
		var rd := _dock_item("redo", Loc.t("redo"), _on_redo, chip_var, night)
		redo_btn = rd.get_meta("button")
		bottom.add_child(rd)
	bottom.add_child(_dock_item("restart", Loc.t("restart"), _on_restart, chip_var, night))
	root.add_child(dock)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	guide = Fx.GuideLine.new()
	guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	guide.visible = false
	fx_layer.add_child(guide)

## One dock tool: a chip with its caption underneath (never icon-only).
func _dock_item(glyph: String, caption: String, cb: Callable, variation: String, night: bool) -> Control:
	var w := UI.icon_button(glyph, caption, cb, variation, 84)
	w.custom_minimum_size = Vector2(132, 0)
	var l := w.get_child(1) as Label
	if l and night:
		l.add_theme_color_override("font_color", Style.MOON_SOFT)
	return w

## Free-hint count on the hint chip (campaign-style hints only).
func _update_hint_badge() -> void:
	if hint_btn == null:
		return
	for c in hint_btn.get_children():
		if c is UI.Bubble:
			c.queue_free()
	if not ledger and free_hints > 0 and not ps.is_won():
		UI.badge(hint_btn, free_hints)

func _process(delta: float) -> void:
	if crates_row and backdrop:
		var y := (crates_row.get_global_rect().position.y - backdrop.get_global_rect().position.y) + 40
		backdrop.set_split(y)
	# Rush clock: counts up only while the puzzle is in play and unobstructed.
	if kind == "rush" and App.rush and ps and not ps.is_won() and App.main.overlays.is_empty():
		App.rush.tick(delta)
		var t := RushRun.fmt_time(int(App.rush.elapsed_ms))
		if sub_label.text != t:
			sub_label.text = t
			sub_label.visible = true

func _title() -> String:
	if kind == "ledger":
		return LedgerPlay.title(def)
	match kind:
		"daily": return Loc.t("daily_title")
		"rush": return Loc.t("rush_title_n", [App.rush.index + 1 if App.rush else 1, RushRun.LENGTH])
		"challenge": return Loc.t("challenge_n", [int(challenge_id.substr(2))])
		"bakery": return Loc.t("bakery_level_n", [App.progression.bakery_index(level_id) + 1])
	return Loc.t("level_n", [App.progression.campaign_index(level_id) + 1])

func _subtitle() -> String:
	if kind == "ledger":
		return LedgerPlay.subtitle(def)
	if kind == "rush" and App.rush:
		return RushRun.fmt_time(int(App.rush.elapsed_ms))
	if kind == "challenge":
		return Challenges.goal_text(Challenges.def(challenge_id), def)
	if kind == "bakery":
		return Loc.t("bakery_title")
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
		oc.special = Specials.is_special_order(def, o)
		oc.set_bell(def.allow_bell and o >= 0, s.pin == t, Rules.rings_left(s) == 0)
	var coach_action := _coach_action()
	var coach_target := coach_action if coach_action >= 0 else -1
	for t in order_cards.size():
		order_cards[t].hint_glow = (t == hint_bell) or (coach_action < 0 and Rules.action_tray(coach_action) == t and coach_action != _NO_ACTION)
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
	var calm := Style.MOON_SOFT if ledger else Style.INK_SOFT
	counter_label.add_theme_color_override("font_color", (Style.LANTERN if ledger else Style.WARN) if free <= 1 and s.counter.size() > 1 else calm)
	undo_btn.disabled = not ps.can_undo()
	_update_hint_badge()
	if redo_btn:
		redo_btn.disabled = not ps.can_redo()
	if ledger:
		ledger.refresh()
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

## Ringing a ticket's bell: that customer is served first. A free action
## (not a move), undoable, and the crate badges update at once so the player
## sees the consequence before tapping anything.
func _on_ticket(t: int) -> void:
	_finish_effects()
	if ps.is_won():
		return
	var ev := ps.ring(t)
	if ev.is_empty():
		if ledger and ps.state.tray_order[t] >= 0 and Rules.rings_left(ps.state) == 0:
			App.audio.play("invalid")
			order_cards[t].wiggle()
			status_label.text = Loc.t("invalid_no_rings")
			status_label.set_meta("sticky", true)
		return
	hint_crate = -1
	hint_bell = -1
	App.audio.play("bell", 1.0 if ps.state.pin == t else 0.85)
	App.haptic(10)
	status_label.set_meta("sticky", false)
	_refresh()
	order_cards[t].wiggle()
	_advance_coach()
	persist()

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
	hint_bell = -1
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
		Rules.Block.SEQUENCE: msg = LedgerPlay.sequence_message(ps.state)
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
			Rules.EV_BELL:
				if not e.on:
					var oc5: OrderCard = order_cards[e.tray]
					_delay(t + fly, func(): oc5.wiggle())
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

## v4: re-applies the last undone action (expert mode).
func _on_redo() -> void:
	_finish_effects()
	var before := ps.state.copy()
	var ev := ps.redo()
	if ev.is_empty():
		return
	App.audio.play("undo", 1.2)
	_refresh()
	_animate(before, ev)
	persist()
	if ps.is_won():
		_on_won()
	elif ps.is_lost():
		_show_lost()

func _on_undo() -> void:
	_finish_effects()
	if ps.undo():
		App.audio.play("undo")
		App.analytics.event("undo", {"level": level_id})
		hint_crate = -1
		hint_bell = -1
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
	if ledger:
		ledger.open_hint()
		return
	if _hint_thread_busy or ps.is_won():
		return
	if free_hints > 0:
		_run_hint(true)
		return
	var buttons: Array = []
	if App.rewards.available():
		buttons.append([Loc.t("hint_watch_ad"), func(): App.rewards.request("hint", func(): _run_hint(false)), ""])
	buttons.append([Loc.t("close"), func(): pass, "SecondaryButton"])
	App.main.show_overlay(Dialog.make(Loc.t("hint_title"), Loc.t("hint_used_body") if App.rewards.available() else Loc.t("hint_used_noads"), buttons, null, "hint"))

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
		_hint_done.call_deferred(r.status, r.path[0] if r.path.size() > 0 else _NO_ACTION, back, snapshot.key())
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

## `action` is the solver's next action: a crate (>= 0) or a bell ring (< 0).
func _hint_done(status: String, action: int, back: int, key: String) -> void:
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
			if action < 0 and action != _NO_ACTION:
				hint_bell = Rules.action_tray(action)
				order_cards[hint_bell].hint_glow = true
				order_cards[hint_bell].queue_redraw()
				status_label.text = Loc.t("hint_ring", [hint_bell + 1])
			else:
				hint_crate = action
				var pv := Rules.preview(ps.state, action)
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
	if ledger:
		App.data.current = {}
		ledger.on_won()
		return
	var stars := ps.stars()
	var secs := (Time.get_ticks_msec() - started_ms) / 1000
	var summary := {"kind": kind, "level": level_id, "stars": stars, "moves": ps.state.moves,
		"hints": ps.hints_used, "undos": ps.undo_count, "best_streak": best_streak, "secs": secs,
		"peak": ps.state.peak_counter}
	var res := {}
	match kind:
		"campaign", "bakery":
			res = Progression.record_win(App.data, level_id, stars)
			res.merge(Progression.record_mastery(App.data, def, ps.state.peak_counter, ps.hints_used))
			res["special"] = Specials.on_win(App.data, def)
		"challenge":
			var c := Challenges.def(challenge_id)
			res = Challenges.record(App.data, challenge_id,
				Challenges.goal_met(c, def, stars, ps.hints_used, ps.undo_count, ps.state.peak_counter))
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
	# A short story beat (shown once) comes before the card: the very first
	# customer served, or a special order solved.
	var beat := ""
	if kind == "campaign" and bool(res.get("special", {}).get("new", false)):
		beat = "special:" + level_id
	elif kind == "campaign" and int(App.data.stats.wins) == 1:
		beat = "first_served"
	_delay(App.dur(1.0), func():
		if beat != "" and Story.has_beat(beat) and not Story.seen(App.data, beat):
			Story.play(beat, func(): App.main.show_overlay(d))
		else:
			App.main.show_overlay(d))

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
	if ledger:
		_delay(App.dur(0.45), func(): if ps.is_lost(): ledger.on_lost())
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
	var d := Dialog.make(Loc.t("lost_title"), _lost_reason(), buttons, null, "undo")
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
	var leave_text := Loc.t("quit_to_map") if kind == "campaign" else (Loc.t("bakery_title") if kind == "bakery" else Loc.t("quit_to_home"))
	var d := Dialog.make(Loc.t("paused"), "", [
		[Loc.t("resume"), func(): pass, ""],
		[Loc.t("restart"), _on_restart, "SecondaryButton"],
		[Loc.t("settings"), func(): App.main.goto("settings"), "SecondaryButton"],
		[leave_text, _leave, "SecondaryButton"],
	], info, "pause")
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
	elif kind == "challenge":
		App.main.goto("daily")
	elif kind == "bakery":
		App.main.goto("bakery")
	elif kind == "ledger":
		App.main.goto("ledger")

func on_back() -> bool:
	_open_pause()
	return true

# --------------------------------------------------------------------- tutorial

var _coach_step := 0

func _tut_key() -> String:
	var k := str(def.meta.get("tutorial", ""))
	return k if k != "" and not App.data.tutorial.done.has(k) else ""

const _NO_ACTION := -1000

## Next action of a solution from here, for the tutorial coach: a crate to
## glow (>= 0), a ticket to ring (< 0), or _NO_ACTION.
func _coach_action() -> int:
	if _tut_key() == "" or ps == null or ps.is_won():
		return _NO_ACTION
	var r := Solver.new(4000).solve(ps.state)
	return r.path[0] if r.status == Solver.SOLVED and r.path.size() > 0 else _NO_ACTION

func _coach_target() -> int:
	var a := _coach_action()
	return a if a >= 0 else -1

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
	if k == "tut_bell":
		# The bell lesson follows the solution: explain the ring exactly when
		# it is the next right action, and what it did right after.
		var a := _coach_action()
		if a < 0 and a != _NO_ACTION:
			coach_label.text = Loc.t("tut_bell_2", [Rules.action_tray(a) + 1])
		elif ps.state.pin >= 0:
			coach_label.text = Loc.t("tut_bell_3")
		else:
			coach_label.text = Loc.t("tut_bell_1")
	coach.visible = true
	status_label.visible = false

func _advance_coach() -> void:
	if _tut_key() != "":
		_update_coach()
	var ca := _coach_action()
	for cv in crate_views:
		cv.highlight = cv.index == ca or cv.index == hint_crate
		cv.queue_redraw()
	for t in order_cards.size():
		order_cards[t].hint_glow = t == hint_bell or (ca < 0 and ca != _NO_ACTION and Rules.action_tray(ca) == t)
		order_cards[t].queue_redraw()

# --------------------------------------------------------------------- persistence

func persist() -> void:
	if ps == null or ps.is_won() or kind == "rush":
		return
	App.data.current = {"kind": kind, "id": level_id, "date": date_key, "ch": challenge_id, "attempt": attempt,
		"session": ps.to_dict(), "hash": def.content_hash()}
	App.save_soon()

func next_level() -> void:
	if kind == "ledger":
		ledger.next_page()
		return
	if kind == "bakery":
		var bi := App.progression.bakery_index(level_id)
		if bi + 1 < App.progression.bakery.size():
			App.main.replace("game", {"kind": "bakery", "id": App.progression.bakery[bi + 1].id})
		else:
			App.main.goto("home", {}, false)
			App.main.goto("bakery")
		return
	var i := App.progression.campaign_index(level_id)
	if i + 1 < App.progression.campaign.size():
		App.main.replace("game", {"kind": "campaign", "id": App.progression.campaign[i + 1].id})
	else:
		App.main.goto("home", {"finale": true}, false)

func replay() -> void:
	App.main.replace("game", {"kind": kind, "id": level_id, "date": date_key, "challenge": challenge_id})

## Orders delivered so far as a segmented bar, with the next customers queued.
class _ProgressBar extends Control:
	var game: Node
	var night := false

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
		var ink := Style.MOON if night else Style.INK
		var soft := Style.MOON_SOFT if night else Style.INK_SOFT
		draw_string(Style.font_bold, Vector2(size.x - x0 - tw if rtl else x0, 24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(24), ink)
		# segmented bar
		var bx := x0 + tw + 16
		var bw := size.x - bx - x0
		var by := 12.0
		var seg := (bw - (total - 1) * 4) / maxf(1, total)
		for i in total:
			var sx := bx + i * (seg + 4)
			if rtl:
				sx = size.x - sx - seg
			var col := (Style.LANTERN if night else Style.TEAL) if i < s.completed else Color(soft, 0.22)
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
		draw_string(Style.font_regular, Vector2(size.x - x0 - lw if rtl else x0, y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22), soft)
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
				draw_string(Style.font_bold, Vector2(size.x - x - 14 if rtl else x, y + 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, soft)
				x += 18
			x += 18

## The status line: a reserved row that shows a short message in a soft pill
## (gold for refusals and hints, paper for information); empty shows nothing.
class StatusPill extends Label:
	var _last := "\u0001"
	var _sticky := false

	func _ready() -> void:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_font_override("font", Style.font_bold)
		add_theme_font_size_override("font_size", Style.fs(24))
		_restyle()

	func _process(_d: float) -> void:
		var st := bool(get_meta("sticky", false))
		if text != _last or st != _sticky:
			_restyle()

	func _restyle() -> void:
		_last = text
		_sticky = bool(get_meta("sticky", false))
		if text == "":
			add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			return
		var sb := Style.box(Style.GOLD_SOFT if _sticky else Color(Style.PAPER, 0.92), 22,
			Color(Style.GOLD, 0.6) if _sticky else Style.PAPER_EDGE, 2, false)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		add_theme_stylebox_override("normal", sb)
		add_theme_color_override("font_color", Style.INK)
