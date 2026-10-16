class_name LedgerPlay
extends RefCounted
## Expert-mode (Midnight Ledger) additions to the puzzle screen: the expert
## strip (bells left, moves, order sequence), the rule card, three-stage hints,
## recovery when stuck, and the completion card with "Why this works".
## All rules stay in Rules; this only reads state and calls the session.

var g      # the game screen (Control)
var strip: _Strip
var _busy := false

func _init(game) -> void:
	g = game

static func info(def: LevelDef) -> Dictionary:
	return def.meta.get("ledger", {})

static func title(def: LevelDef) -> String:
	return Loc.t(str(info(def).get("name", "ledger_title")))

static func subtitle(def: LevelDef) -> String:
	var i := info(def)
	match str(i.get("group", "puzzle")):
		"lesson": return Loc.t("ledger_lesson_n", [int(i.get("number", 1))])
		"final": return Loc.t("ledger_final")
	return Loc.t("ledger_page_n", [int(i.get("number", 1))])

static func customer_name(def: LevelDef, o: int) -> String:
	return Loc.t("name_" + Customers.for_order(def, o))

## "Serve Theo before Ada": names the order the sequence needs next.
static func sequence_message(s: PuzzleState) -> String:
	var k := Rules.sequence_next(s)
	if k < 0:
		return Loc.t("invalid_sequence_generic")
	return Loc.t("invalid_sequence", [customer_name(s.level, s.level.sequence[k])])

func make_strip() -> Control:
	strip = _Strip.new()
	strip.game = g
	strip.custom_minimum_size = Vector2(0, 84)
	return strip

func refresh() -> void:
	if strip:
		strip.queue_redraw()

# --------------------------------------------------------------------- rule card

func show_rules() -> void:
	var d: LevelDef = g.def
	var rows := UI.vbox(14)
	var idea := str(info(d).get("tagline", ""))
	if idea != "":
		rows.add_child(UI.label(Loc.t(idea), "NightCaption"))
	rows.add_child(rule_row("cup", Loc.t("ledger_rule_goal")))
	if d.bell_budget >= 0:
		rows.add_child(rule_row("bell", Loc.t("ledger_rule_budget", [d.bell_budget])))
	if not d.sequence.is_empty():
		var names: Array = []
		for o in d.sequence:
			names.append(customer_name(d, o))
		rows.add_child(rule_row("levels", Loc.t("ledger_rule_sequence", [" → ".join(names)])))
	if d.count_flag(LevelDef.FRESH) > 0:
		rows.add_child(rule_row("timer", Loc.t("help_fresh_b")))
	if d.has_locks():
		rows.add_child(rule_row("lock", Loc.t("help_lock_b")))
	rows.add_child(rule_row("tap", Loc.t("ledger_rule_moves")))
	var tgt := int(info(d).get("precision_target", 0))
	if tgt > 0:
		rows.add_child(rule_row("target", Loc.t("ledger_rule_precision", [tgt])))
	rows.add_child(rule_row("stamp", Loc.t("ledger_rule_badges")))
	App.main.show_overlay(Dialog.make(title(d), "", [[Loc.t("close"), func(): pass, ""]], rows, "book", true))

## One rule: a lantern icon and the rule text, on the night palette.
static func rule_row(glyph: String, text: String, dim: bool = false) -> Control:
	var r := UI.hbox(14)
	var m := UI.medallion(glyph, Style.NIGHT_3, Style.MOON_SOFT if dim else Style.LANTERN, 54)
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.add_child(m)
	var l := UI.label(text, "NightLabel", UI.al())
	l.add_theme_font_size_override("font_size", Style.fs(25))
	if dim:
		l.add_theme_color_override("font_color", Style.MOON_SOFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(420, 0)
	r.add_child(l)
	return r

## Idea · Bottleneck · Move, with the current stage lit.
static func stepper(stage: int) -> Control:
	var h := UI.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in 3:
		var t := UI.tag("%d  %s" % [k + 1, Loc.t("ledger_stage_%d" % (k + 1))],
			Style.LANTERN if k + 1 == stage else (Style.NIGHT_LINE if k + 1 < stage else Style.NIGHT_3),
			Style.INK if k + 1 == stage else Style.MOON_SOFT)
		h.add_child(t)
	return h

# --------------------------------------------------------------------- hints

## Three stages. Opening any stage counts as using a hint (no-hint badge),
## but everyone can always finish. Stage 3 is one VERIFIED next action.
func open_hint() -> void:
	if _busy or g.ps.is_won():
		return
	var ps: PuzzleSession = g.ps
	var stage := mini(3, ps.hints_used + 1) if ps.hints_used < 3 else 3
	_show_stage(stage)

func _show_stage(stage: int) -> void:
	var ps: PuzzleSession = g.ps
	ps.hints_used = maxi(ps.hints_used, stage)
	g.persist()
	var d: LevelDef = g.def
	var i := info(d)
	var buttons: Array = []
	match stage:
		1:
			buttons.append([Loc.t("ledger_hint_more"), func(): _show_stage(2), ""])
			buttons.append([Loc.t("close"), func(): pass, "SecondaryButton"])
			var x1 := UI.vbox(16)
			x1.add_child(stepper(1))
			x1.add_child(UI.label(Loc.t(str(i.get("hint1", ""))), "NightLabel"))
			App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_1"), "", buttons, x1, "hint", true))
		2:
			buttons.append([Loc.t("ledger_hint_action"), func(): _show_stage(3), ""])
			buttons.append([Loc.t("close"), func(): pass, "SecondaryButton"])
			var x2 := UI.vbox(16)
			x2.add_child(stepper(2))
			x2.add_child(UI.label(Loc.t(str(i.get("hint2", ""))), "NightLabel"))
			var facts := UI.label(_state_facts(), "NightCaption")
			x2.add_child(UI.card(facts, "NightCard"))
			App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_2"), "", buttons, x2, "hint", true))
		3:
			_verified_action()

## Live facts for the current position (stage 2).
func _state_facts() -> String:
	var s: PuzzleState = g.ps.state
	var out: Array = []
	var left := Rules.rings_left(s)
	if left >= 0:
		out.append(Loc.t("ledger_fact_rings", [left]))
	var k := Rules.sequence_next(s)
	if k >= 0:
		out.append(Loc.t("ledger_fact_next", [customer_name(s.level, s.level.sequence[k])]))
	out.append(Loc.t("ledger_fact_counter", [s.counter_free()]))
	return " · ".join(out)

## One verified next action from HERE. Order of evidence:
## 1. still on the shipped witness: its next action (proven by replay);
## 2. otherwise a bounded solver search from the current state:
##    SOLVED -> its first action; UNSOLVABLE -> recovery is needed;
##    TIMEOUT -> no claim; fall back to the last witness checkpoint.
func _verified_action() -> void:
	var ps: PuzzleSession = g.ps
	var w := PackedInt32Array(info(g.def).get("witness", []))
	var mlog := ps.moves_log
	var on_path := mlog.size() < w.size()
	for k in mlog.size():
		if k >= w.size() or mlog[k] != w[k]:
			on_path = false
			break
	if on_path:
		_show_action(w[mlog.size()], true)
		return
	_busy = true
	g.status_label.text = Loc.t("hint_thinking")
	g.status_label.set_meta("sticky", true)
	var snap := ps.state.copy()
	var key := snap.key()
	var task := func():
		var r := Solver.new(150000).solve(snap)
		_search_done.call_deferred(r.status, r.path[0] if r.path.size() > 0 else 0, key)
	g._hint_task = WorkerThreadPool.add_task(task)

func _search_done(status: String, action: int, key: String) -> void:
	_busy = false
	if g._hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(g._hint_task)
		g._hint_task = -1
	if not g.is_inside_tree() or g.ps.state.key() != key:
		return
	g.status_label.set_meta("sticky", false)
	g.status_label.text = ""
	match status:
		Solver.SOLVED:
			_show_action(action, false)
		Solver.UNSOLVABLE:
			_recovery(Loc.t("ledger_stuck"))
		_:
			var back := _witness_checkpoint()
			var b: Array = []
			if back > 0:
				b.append([Loc.t("ledger_undo_n", [back]), func(): _undo_n(back), ""])
			b.append([Loc.t("restart"), func(): g._on_restart(), "SecondaryButton"])
			b.append([Loc.t("close"), func(): pass, "SecondaryButton"])
			App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_3"), Loc.t("ledger_hint_unknown"), b, stepper(3), "hint", true))

## Highlights a crate or a ticket and explains the action in words.
func _show_action(a: int, from_witness: bool) -> void:
	var text := ""
	if a >= 0:
		g.hint_crate = a
		text = Loc.t("ledger_hint_tap", [a + 1])
	else:
		g.hint_bell = Rules.action_tray(a)
		g.order_cards[g.hint_bell].hint_glow = true
		g.order_cards[g.hint_bell].queue_redraw()
		text = Loc.t("hint_ring", [g.hint_bell + 1])
	for cv in g.crate_views:
		cv.highlight = cv.index == g.hint_crate
		cv.queue_redraw()
	g.status_label.text = text
	g.status_label.set_meta("sticky", true)
	var x3 := UI.vbox(16)
	x3.add_child(stepper(3))
	var big := UI.label(text, "NightHeader")
	x3.add_child(big)
	x3.add_child(rule_row("shield", Loc.t("ledger_hint_verified_w" if from_witness else "ledger_hint_verified_s")))
	App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_3"), "", [[Loc.t("close"), func(): pass, ""]], x3, "hint", true))

## Undos needed to get back onto the shipped witness (always solvable).
func _witness_checkpoint() -> int:
	var w := PackedInt32Array(info(g.def).get("witness", []))
	var mlog: PackedInt32Array = g.ps.moves_log
	var common := 0
	while common < mlog.size() and common < w.size() and mlog[common] == w[common]:
		common += 1
	return mlog.size() - common

func _undo_n(n: int) -> void:
	for k in n:
		g.ps.undo()
	g.hint_crate = -1
	g.hint_bell = -1
	g.status_label.set_meta("sticky", false)
	g._refresh()
	g.persist()

# --------------------------------------------------------------------- stuck

func on_lost() -> void:
	App.audio.play("lose")
	_recovery(Loc.t("ledger_lost"))

## Offers the way back: undo to the last point on the shipped (proven)
## solution, plain undo, or restart. Nothing is guessed.
func _recovery(text: String) -> void:
	var back := _witness_checkpoint()
	var b: Array = []
	if back > 0:
		b.append([Loc.t("ledger_undo_n", [back]), func(): _undo_n(back), ""])
	b.append([Loc.t("undo_free"), func(): g._on_undo(), "SecondaryButton"])
	b.append([Loc.t("restart"), func(): g._on_restart(), "SecondaryButton"])
	App.main.show_overlay(Dialog.make(Loc.t("ledger_stuck_title"), text, b, null, "undo", true))

# --------------------------------------------------------------------- won

func on_won() -> void:
	var ps: PuzzleSession = g.ps
	var res := Ledger.record(App.data, g.level_id, ps.moves_log.size(), ps.hints_used)
	App.analytics.event("ledger_page_done", {"page": g.level_id, "moves": ps.moves_log.size(), "hints": ps.hints_used})
	App.save_now()
	g._celebrate()
	var extra := UI.vbox(14)
	var stamp := _StampArt.new()
	stamp.custom_minimum_size = Vector2(0, 150)
	extra.add_child(stamp)
	extra.add_child(UI.label(Loc.t("ledger_moves_used", [ps.moves_log.size()]), "NightSoft"))
	extra.add_child(rule_row("stamp", Loc.t("ledger_stamp_new") if res.stamp_new else Loc.t("ledger_stamp_kept")))
	if res.nohint_met:
		extra.add_child(rule_row("eye", Loc.t("ledger_nohint_new") if res.nohint_new else Loc.t("ledger_nohint_kept")))
	else:
		extra.add_child(rule_row("eye", Loc.t("ledger_nohint_missed"), true))
	var tgt := int(info(g.def).get("precision_target", 0))
	if tgt > 0:
		if res.precision_met:
			extra.add_child(rule_row("target", Loc.t("ledger_precision_new", [tgt]) if res.precision_new else Loc.t("ledger_precision_kept", [tgt])))
		else:
			extra.add_child(rule_row("target", Loc.t("ledger_precision_missed", [tgt]), true))
	if res.lamp_new:
		extra.add_child(rule_row("lantern", Loc.t("ledger_lamp_new")))
	var buttons: Array = [
		[Loc.t("ledger_next"), func(): next_page(), ""],
		[Loc.t("ledger_why"), func(): _why(), "SecondaryButton"],
		[Loc.t("ledger_title"), func(): App.main.goto("home", {}, false); App.main.goto("ledger"), "SecondaryButton"],
	]
	var d := Dialog.make(Loc.t("ledger_done_title"), "", buttons, extra, "", true)
	d.back_closes = false
	g._delay(App.dur(1.0), func(): App.main.show_overlay(d))

## "Why this works": the designer's explanation, and an honest note on
## whether the player's sequence matched the reference solution.
func _why() -> void:
	var i := info(g.def)
	# JSON numbers load as floats: compare both as int arrays.
	var same := Array(g.ps.moves_log) == Array(PackedInt32Array(i.get("witness", [])))
	var x := UI.vbox(16)
	x.add_child(UI.label(Loc.t(str(i.get("why", ""))), "NightLabel", UI.al()))
	x.add_child(rule_row("check" if same else "info", Loc.t("ledger_why_same") if same else Loc.t("ledger_why_different")))
	App.main.show_overlay(Dialog.make(Loc.t("ledger_why"), "", [
		[Loc.t("ledger_next"), func(): next_page(), ""],
		[Loc.t("ledger_title"), func(): App.main.goto("home", {}, false); App.main.goto("ledger"), "SecondaryButton"],
	], x, "info", true))

func next_page() -> void:
	var i := Ledger.index(g.level_id)
	for k in range(i + 1, Ledger.pages().size()):
		var id: String = Ledger.pages()[k].id
		if Ledger.is_unlocked(App.data, id) and not Ledger.is_done(App.data, id):
			App.main.replace("game", {"kind": "ledger", "id": id})
			return
	App.main.goto("home", {}, false)
	App.main.goto("ledger")

## Bells left, move count (and verified target), and the order sequence as
## faces in order: delivered ones ticked, the next one ringed in lantern gold.
## Each section has a caption, so nothing relies on colour alone.
class _Strip extends Control:
	var game

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _x(x: float, w: float = 0.0) -> float:
		return size.x - x - w if Loc.is_rtl() else x

	func _cap(text: String, x: float, w: float) -> void:
		draw_string(Style.font_bold, Vector2(_x(x, w), 22), text, HORIZONTAL_ALIGNMENT_CENTER, w, Style.fs(17), Style.MOON_SOFT)

	func _draw() -> void:
		if game == null or game.ps == null:
			return
		var s: PuzzleState = game.ps.state
		var d: LevelDef = game.def
		var sb := Style.box(Style.NIGHT_2, 20, Color(Style.LANTERN, 0.35), 2, false)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var cy := size.y * 0.62
		# --- bells
		var left := Rules.rings_left(s)
		var bw := 150.0
		_cap(Loc.t("ledger_strip_bells"), 10, bw)
		if left < 0:
			Glyph.paint(self, "bell", Rect2(Vector2(_x(30, 44), cy - 22), Vector2(44, 44)), Style.LANTERN)
			draw_string(Style.font_bold, Vector2(_x(78, 40), cy + 12), "∞", HORIZONTAL_ALIGNMENT_CENTER, 40, Style.fs(32), Style.MOON)
		else:
			var n := maxi(d.bell_budget, 1)
			var step := minf(40.0, (bw - 10) / n)
			var x0 := 10 + (bw - step * n) / 2
			for k in d.bell_budget:
				var r := Rect2(Vector2(_x(x0 + k * step, step), cy - step / 2), Vector2(step, step))
				var spent := k >= left
				Glyph.paint(self, "bell_line" if spent else "bell", r, Color(Style.MOON_SOFT, 0.55) if spent else Style.LANTERN)
				if spent:
					draw_line(r.position + Vector2(6, r.size.y - 6), r.position + Vector2(r.size.x - 6, 6), Style.MOON_SOFT, 3, true)
			if d.bell_budget == 0:
				draw_string(Style.font_bold, Vector2(_x(10, bw), cy + 10), "0", HORIZONTAL_ALIGNMENT_CENTER, bw, Style.fs(28), Style.MOON_SOFT)
		draw_line(Vector2(_x(10 + bw), 12), Vector2(_x(10 + bw), size.y - 12), Style.NIGHT_LINE, 2)
		# --- moves
		var mx := 10 + bw
		var mw := 140.0
		_cap(Loc.t("ledger_strip_moves"), mx, mw)
		var tgt := int(d.meta.get("ledger", {}).get("precision_target", 0))
		var mv := str(game.ps.moves_log.size())
		var tt := (" / %d" % tgt) if tgt > 0 else ""
		var f := Style.font_bold
		var w1 := f.get_string_size(mv, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(32)).x
		var w2 := f.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22)).x
		# digits read left-to-right in both languages: "3 / 9"
		var bx := _x(mx, mw) + (mw - w1 - w2) / 2
		draw_string(f, Vector2(bx, cy + 12), mv, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(32), Style.MOON)
		draw_string(f, Vector2(bx + w1, cy + 12), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22), Style.LANTERN)
		draw_line(Vector2(_x(mx + mw), 12), Vector2(_x(mx + mw), size.y - 12), Style.NIGHT_LINE, 2)
		# --- sequence
		var qx := mx + mw
		var qw := size.x - qx - 10
		if d.sequence.is_empty():
			_cap(Loc.t("ledger_strip_order"), qx, qw)
			draw_string(Style.font_regular, Vector2(_x(qx, qw), cy + 10), Loc.t("ledger_strip_any"), HORIZONTAL_ALIGNMENT_CENTER, qw, Style.fs(22), Style.MOON_SOFT)
			return
		_cap(Loc.t("ledger_strip_order"), qx, qw)
		var n2 := d.sequence.size()
		var nxt := Rules.sequence_next(s)
		var gap := 26.0
		var face := 44.0
		var total := n2 * face + (n2 - 1) * gap
		var fx := qx + (qw - total) / 2
		for k in n2:
			var o := d.sequence[k]
			var c := Vector2(_x(fx + k * (face + gap) + face / 2), cy)
			var done := s.delivered(o)
			if k == nxt:
				draw_circle(c, face / 2 + 5, Style.LANTERN)
			draw_circle(c, face / 2, Style.PARCHMENT if not done else Color(Style.MOON_SOFT, 0.5))
			CharacterArt.draw(self, Customers.for_order(d, o), c + Vector2(0, 1), face * 0.86, 0, 0.45 if done else 1.0)
			if done:
				draw_circle(c + Vector2(14, 12), 11, Style.TEAL)
				draw_polyline(PackedVector2Array([c + Vector2(9, 12), c + Vector2(13, 16), c + Vector2(20, 8)]), Color.WHITE, 3, true)
			if k < n2 - 1:
				var ax := fx + k * (face + gap) + face + gap / 2
				Glyph.paint(self, "chevron", Rect2(Vector2(_x(ax - 12, 24), cy - 12), Vector2(24, 24)), Style.MOON_SOFT)

## A lantern-gold ledger stamp that lands with a small thump.
class _StampArt extends Control:
	var _k := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if App.reduced_motion():
			_k = 1.0
		else:
			var tw := create_tween()
			tw.tween_interval(0.25)
			tw.tween_method(func(v): _k = v; queue_redraw(), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): App.audio.play("stage"))

	func _draw() -> void:
		var c := size / 2
		var sc := lerpf(1.6, 1.0, _k)
		var a := clampf(_k * 1.4, 0, 1)
		draw_set_transform(c, -0.18, Vector2(sc, sc))
		draw_circle(Vector2.ZERO, 66, Color(Style.LANTERN, 0.12 * a))
		Glyph.paint(self, "stamp", Rect2(Vector2(-70, -70), Vector2(140, 140)), Color(Style.LANTERN, a))
		draw_set_transform(Vector2.ZERO)
