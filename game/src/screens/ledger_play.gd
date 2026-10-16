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
	strip.custom_minimum_size = Vector2(0, 64)
	return strip

func refresh() -> void:
	if strip:
		strip.queue_redraw()

# --------------------------------------------------------------------- rule card

func show_rules() -> void:
	var d: LevelDef = g.def
	var lines: Array = [Loc.t("ledger_rule_goal")]
	if d.bell_budget >= 0:
		lines.append(Loc.t("ledger_rule_budget", [d.bell_budget]))
	if not d.sequence.is_empty():
		var names: Array = []
		for o in d.sequence:
			names.append(customer_name(d, o))
		lines.append(Loc.t("ledger_rule_sequence", [" → ".join(names)]))
	if d.count_flag(LevelDef.FRESH) > 0:
		lines.append(Loc.t("help_fresh_b"))
	if d.has_locks():
		lines.append(Loc.t("help_lock_b"))
	lines.append(Loc.t("ledger_rule_moves"))
	var tgt := int(info(d).get("precision_target", 0))
	if tgt > 0:
		lines.append(Loc.t("ledger_rule_precision", [tgt]))
	lines.append(Loc.t("ledger_rule_badges"))
	var idea := str(info(d).get("idea", ""))
	var body := "\n\n".join(lines.map(func(l): return "• " + l))
	App.main.show_overlay(Dialog.make(title(d), body, [[Loc.t("close"), func(): pass, ""]],
		UI.label(Loc.t(idea) if idea != "" else "", "SoftLabel")))

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
			App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_1"), Loc.t(str(i.get("hint1", ""))), buttons))
		2:
			var facts := _state_facts()
			buttons.append([Loc.t("ledger_hint_action"), func(): _show_stage(3), ""])
			buttons.append([Loc.t("close"), func(): pass, "SecondaryButton"])
			App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_2"), Loc.t(str(i.get("hint2", ""))) + "\n\n" + facts, buttons))
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
			App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_3"), Loc.t("ledger_hint_unknown"), b))

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
	App.main.show_overlay(Dialog.make(Loc.t("ledger_hint_3"), text + "\n\n" +
		Loc.t("ledger_hint_verified_w" if from_witness else "ledger_hint_verified_s"), [[Loc.t("close"), func(): pass, ""]]))

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
	App.main.show_overlay(Dialog.make(Loc.t("ledger_stuck_title"), text, b))

# --------------------------------------------------------------------- won

func on_won() -> void:
	var ps: PuzzleSession = g.ps
	var res := Ledger.record(App.data, g.level_id, ps.moves_log.size(), ps.hints_used)
	App.analytics.event("ledger_page_done", {"page": g.level_id, "moves": ps.moves_log.size(), "hints": ps.hints_used})
	App.save_now()
	g._celebrate()
	var extra := UI.vbox(10)
	var lines: Array = []
	lines.append(Loc.t("ledger_stamp_new") if res.stamp_new else Loc.t("ledger_stamp_kept"))
	lines.append(Loc.t("ledger_moves_used", [ps.moves_log.size()]))
	if res.nohint_met:
		lines.append(Loc.t("ledger_nohint_new") if res.nohint_new else Loc.t("ledger_nohint_kept"))
	else:
		lines.append(Loc.t("ledger_nohint_missed"))
	var tgt := int(info(g.def).get("precision_target", 0))
	if tgt > 0:
		if res.precision_met:
			lines.append(Loc.t("ledger_precision_new", [tgt]) if res.precision_new else Loc.t("ledger_precision_kept", [tgt]))
		else:
			lines.append(Loc.t("ledger_precision_missed", [tgt]))
	if res.lamp_new:
		lines.append(Loc.t("ledger_lamp_new"))
	for t in lines:
		var l := UI.label(t, "")
		l.custom_minimum_size = Vector2(540, 0)
		extra.add_child(l)
	var buttons: Array = [
		[Loc.t("ledger_why"), func(): _why(), "WarmButton"],
		[Loc.t("ledger_next"), func(): next_page(), ""],
		[Loc.t("ledger_title"), func(): App.main.goto("home", {}, false); App.main.goto("ledger"), "SecondaryButton"],
	]
	var d := Dialog.make(Loc.t("ledger_done_title"), "", buttons, extra)
	d.back_closes = false
	g._delay(App.dur(1.0), func(): App.main.show_overlay(d))

## "Why this works": the designer's explanation, and an honest note on
## whether the player's sequence matched the reference solution.
func _why() -> void:
	var i := info(g.def)
	# JSON numbers load as floats: compare both as int arrays.
	var same := Array(g.ps.moves_log) == Array(PackedInt32Array(i.get("witness", [])))
	var body := Loc.t(str(i.get("why", ""))) + "\n\n" + (Loc.t("ledger_why_same") if same else Loc.t("ledger_why_different"))
	App.main.show_overlay(Dialog.make(Loc.t("ledger_why"), body, [
		[Loc.t("ledger_next"), func(): next_page(), ""],
		[Loc.t("ledger_title"), func(): App.main.goto("home", {}, false); App.main.goto("ledger"), "SecondaryButton"],
	]))

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
## faces in order: delivered ones ticked, the next one ringed.
class _Strip extends Control:
	var game

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if game == null or game.ps == null:
			return
		var s: PuzzleState = game.ps.state
		var d: LevelDef = game.def
		draw_style_box(Style.box(Color("26365a"), 18, Color.TRANSPARENT, 0, false), Rect2(Vector2.ZERO, size))
		var x := 14.0
		var y := size.y / 2
		var left := Rules.rings_left(s)
		OrderCard.draw_bell(self, Vector2(x + 14, y), 13, left != 0)
		var t := "∞" if left < 0 else str(left)
		draw_string(Style.font_bold, Vector2(x + 34, y + 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(26), Color.WHITE)
		x += 80
		var tgt := int(d.meta.get("ledger", {}).get("precision_target", 0))
		var mv := Loc.t("ledger_moves_n", [game.ps.moves_log.size()]) + ("/%d" % tgt if tgt > 0 else "")
		draw_string(Style.font_bold, Vector2(x, y + 9), mv, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22), Color(1, 1, 1, 0.9))
		if d.sequence.is_empty():
			return
		var n := d.sequence.size()
		var nxt := Rules.sequence_next(s)
		var fx := size.x - 14 - n * 50 + 4
		for k in n:
			var o := d.sequence[k]
			var c := Vector2(fx + k * 50 + 20, y)
			draw_circle(c, 21, Style.PAPER if k != nxt else Style.GOLD)
			CharacterArt.draw(self, Customers.for_order(d, o), c + Vector2(0, 1), 36, 0, 0.45 if s.delivered(o) else 1.0)
			if s.delivered(o):
				draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 7), c + Vector2(10, -8)]), Style.TEAL, 4, true)
			if k < n - 1:
				draw_string(Style.font_bold, c + Vector2(20, 8), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
