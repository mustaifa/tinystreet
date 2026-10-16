extends SceneTree
## DEVELOPMENT TOOL for the Midnight Ledger (expert mode). Never runs on the phone.
##   godot --headless --path game -s res://tools/ledger_tool.gd -- search <goal> <count> <seed>
##       Prints promising candidate boards for a design goal (see GOALS).
##       Candidates are raw material: a designer picks, names and explains them
##       in tools/ledger_pages.gd, and only proven properties are claimed.
##   godot --headless --path game -s res://tools/ledger_tool.gd -- build
##       Proves every page in tools/ledger_pages.gd and writes
##       data/levels/ledger.json + docs/EXPERT_PUZZLE_PROOFS.md +
##       docs/EXPERT_SOLUTIONS_SPOILERS.md. Exits 1 if any proof fails.

const PAGES := preload("res://tools/ledger_pages.gd")

## goal -> generation parameters and acceptance rule
const GOALS := {
	"budget1": {"budget": 1, "seq": 0, "need_min": 1, "prods": 2},
	"budget2": {"budget": 2, "seq": 0, "need_min": 2, "prods": 2},
	"precision": {"budget": 2, "seq": 0, "need_min": 1, "max_min": 1, "prods": 2},
	"seq2": {"budget": -1, "seq": 2},
	"seq3": {"budget": 0, "seq": 3},
	"both": {"budget": 1, "seq": 2, "need_min": 1},
	"fresh": {"budget": 1, "seq": 2, "fresh": 0.25},
	"lock": {"budget": 1, "seq": 2, "locks": 1},
	"final": {"budget": 1, "seq": 3, "fresh": 0.2, "need_min": 1},
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "build"
	if mode == "review":
		_review(JSON.parse_string(args[1]))
		quit(0)
		return
	if mode == "search":
		_search(args[1], int(args[2]) if args.size() > 2 else 400, int(args[3]) if args.size() > 3 else 1)
		quit(0)
		return
	quit(_build())

# ------------------------------------------------------------------ search

func _search(goal: String, count: int, seed_value: int) -> void:
	var g: Dictionary = GOALS[goal]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Array = []
	for it in count:
		var d := _candidate(g, rng)
		var def := LevelDef.from_dict(d)
		if LevelValidator.schema_errors(d).size() > 0 or LevelValidator.quantity_errors(def).size() > 0:
			continue
		var r := Solver.new(60000).solve(PuzzleState.create(def))
		if r.status != Solver.SOLVED:
			continue
		var mr := LedgerAnalysis.min_rings(def, 3, 60000)
		if g.has("need_min") and (not mr.proved or int(mr.min) < int(g.need_min)):
			continue
		if g.has("max_min") and int(mr.min) > int(g.max_min):
			continue
		if int(g.seq) > 0:
			# the sequence must matter: without it, more first actions survive
			var free := d.duplicate(true)
			free.erase("sequence")
			if _good_first(LevelDef.from_dict(free)) <= _good_first(def):
				continue
		var tr := LedgerAnalysis.trace(def, r.path, 60000)
		if not tr.ok or tr.unknown > 0 or int(tr.choice_points) < 2:
			continue
		var score: float = float(tr.choice_points) * 3.0 + tr.trap_kinds.size() * 2.0 + float(tr.traps) * 0.3 - def.total_items() * 0.25
		best.append([score, d, r.path, tr, mr])
	best.sort_custom(func(a, b): return a[0] > b[0])
	for k in mini(6, best.size()):
		var e: Array = best[k]
		print("SCORE %.1f choice=%d traps=%d kinds=%s min_rings=%s items=%d" % [e[0], e[3].choice_points, e[3].traps,
			e[3].trap_kinds, e[4], LevelDef.from_dict(e[1]).total_items()])
		print("  ", JSON.stringify(e[1]))
		print("  witness ", e[2])
	print("candidates kept: ", best.size())

func _good_first(def: LevelDef) -> int:
	var s := PuzzleState.create(def)
	var n := 0
	for a in LedgerAnalysis.actions(s):
		var c := s.copy()
		Rules.apply_action(c, a)
		if Solver.new(30000).solve(c).status == Solver.SOLVED:
			n += 1
	return n

func _candidate(g: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var prods: Array = ["coffee", "tea", "croissant", "cupcake"]
	prods.shuffle()
	var np: int = int(g.get("prods", 3))
	prods = prods.slice(0, np)
	var n_orders := rng.randi_range(4, 5)
	var orders: Array = []
	var bag: Array = []
	for o in n_orders:
		var st := {}
		for k in rng.randi_range(1, 3):
			var p: String = prods[rng.randi_range(0, np - 1)]
			st[p] = int(st.get(p, 0)) + 1
			bag.append(p)
		orders.append([st])
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = bag[i]; bag[i] = bag[j]; bag[j] = t
	var n_crates := 3 if bag.size() > 8 else rng.randi_range(2, 3)
	var crates: Array = []
	for c in n_crates:
		crates.append([])
	for i in bag.size():
		crates[i % n_crates].append(bag[i])
	var fr: float = g.get("fresh", 0.0)
	for c in crates:
		for k in c.size():
			if fr > 0.0 and rng.randf() < fr:
				c[k] = c[k] + "!"
	var d := {"id": "cand", "counter": rng.randi_range(1, 2), "trays": 2, "crates": crates, "orders": orders}
	if int(g.budget) >= 0:
		d["bell_budget"] = int(g.budget)
	if int(g.seq) > 0:
		var idx: Array = range(n_orders)
		for i in range(idx.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = idx[i]; idx[i] = idx[j]; idx[j] = t
		d["sequence"] = idx.slice(0, int(g.seq))
	if int(g.get("locks", 0)) > 0:
		var lk: Array = []
		lk.resize(n_crates)
		lk.fill(0)
		lk[rng.randi_range(0, n_crates - 1)] = rng.randi_range(1, 2)
		d["locks"] = lk
	return d

# ------------------------------------------------------------------ review

static func describe(s: PuzzleState, a: int) -> String:
	if a < 0:
		return "ring ticket %d" % (Rules.action_tray(a) + 1)
	var pv := Rules.preview(s, a)
	var dest := "counter" if pv.dest == Rules.Dest.COUNTER else "ticket %d" % (pv.tray + 1)
	var txt := "crate %d: %s -> %s" % [a + 1, Products.index_to_id(pv.product), dest]
	var n := s.copy()
	for e in Rules.apply_move(n, a):
		if e.type == Rules.EV_DELIVER:
			txt += " [serves order %d]" % e.order
	return txt

func _review(d: Dictionary) -> void:
	var def := LevelDef.from_dict(d)
	var r := Solver.new(400000).solve(PuzzleState.create(def))
	print("status ", r.status, " nodes ", r.nodes, " items ", def.total_items())
	if r.status != Solver.SOLVED:
		return
	var mr := LedgerAnalysis.min_rings(def)
	print("min rings ", mr)
	var tr := LedgerAnalysis.trace(def, r.path)
	var nonring := 0
	var s := PuzzleState.create(def)
	for st in tr.steps:
		var traps: Array = st.alternatives.filter(func(x): return x.status == Solver.UNSOLVABLE)
		var nr: Array = traps.filter(func(x): return x.kind != "ring")
		if not nr.is_empty():
			nonring += 1
		print("%2d  %s" % [st.step, describe(s, st.action)])
		for x in traps:
			print("       dead end: %s (%s)" % [describe(s, x.action), x.kind])
		Rules.apply_action(s, st.action)
	print("choice points %d (non-bell %d) traps %d kinds %s unknown %d" % [tr.choice_points, nonring, tr.traps, tr.trap_kinds, tr.unknown])
	var free := d.duplicate(true)
	free.erase("sequence")
	free.erase("bell_budget")
	print("first actions that survive: with constraints %d / without %d / total %d" % [_good_first(def),
		_good_first(LevelDef.from_dict(free)), LedgerAnalysis.actions(PuzzleState.create(def)).size()])

# ------------------------------------------------------------------ build

func _build() -> int:
	var pages: Array = []
	var failures := 0
	var proofs := "# Midnight Ledger: puzzle proofs\n\nGenerated by `tools/ledger_tool.gd -- build` with solver `%s` (Godot %s). **No solutions here**; they are in `EXPERT_SOLUTIONS_SPOILERS.md`.\n\n" % [Solver.VERSION, Engine.get_version_info().string]
	proofs += "How to read this:\n- **Proven** = established by exhaustive search or by replaying a witness through the game rules. **Designer estimate** = my judgement, provisional. **Human-tested** = nothing yet.\n- *Witness replay*: the recorded solution, replayed through `PuzzleSession`, is legal at every step, respects the bell budget and the order sequence, and ends in a win.\n- *Min rings*: the smallest bell budget with a solution; every smaller budget was searched exhaustively and found UNSOLVABLE.\n- *Choice points*: steps of the witness where at least one available action is a proven dead end (exhaustive search from the resulting position) and at least one isn't. *Non-bell* excludes dead ends that are only \"ring a bell now\" (with a budget of 1, spending the bell early is a dead end at many steps, which inflates the raw count).\n- *First actions*: how many of the opening actions keep the page solvable, with the page's constraints and with budget/sequence removed.\n- Solver nodes and time are engineering metrics, **not** human difficulty.\n- A move = one crate tap or one bell ring. The precision target is offered only when it is proven minimal: every solution taps once per item, and fewer rings than the proven minimum are impossible.\n\n"
	proofs += "| page | group | idea (verified evidence) | items | budget | sequence | min rings | precision target | witness replay | choice pts (non-bell) | dead ends by kind | first actions (constrained / free / total) | solver nodes | ms | designer difficulty | content hash |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	var spoil := "# Midnight Ledger: SOLUTIONS (spoilers)\n\n**Spoiler warning.** Reference solutions for every page, found by the solver and replayed through the game rules. Many pages have other valid solutions; these are not the only answers.\n\nCrates are numbered left to right, tickets 1 and 2. Ringing a ticket's bell is a move.\n\n"
	for src in PAGES.PAGES:
		var t0 := Time.get_ticks_msec()
		var d: Dictionary = (src.board as Dictionary).duplicate(true)
		d["id"] = src.id
		var errs := LevelValidator.schema_errors(d)
		var def := LevelDef.from_dict(d)
		if errs.is_empty():
			errs = LevelValidator.quantity_errors(def)
		if def.orders.size() > def.trays + 3:
			errs.append("not every order is visible at the start")
		if def.count_flag(LevelDef.BAG) > 0:
			errs.append("hidden items are not allowed in expert pages")
		if (src.customers as Array).size() != def.orders.size():
			errs.append("one customer per order")
		var mr := LedgerAnalysis.min_rings(def)
		if not mr.proved or int(mr.min) < 0:
			errs.append("minimum rings not proved (%s)" % mr)
		var best := Solver.new(400000).solve(PuzzleState.create(def.with_budget(int(mr.min)) if def.allow_bell else def))
		var witness := PackedInt32Array(best.path)
		var rep := LedgerAnalysis.replay(def, witness)
		if best.status != Solver.SOLVED or not rep.ok:
			errs.append("witness replay failed: %s" % rep)
		var tr := LedgerAnalysis.trace(def, witness)
		if not tr.ok or int(tr.unknown) > 0:
			errs.append("trace incomplete (unknown %s)" % tr.get("unknown", "?"))
		var idea := LedgerAnalysis.verify_idea(def, witness, tr, mr, src.idea)
		if not idea.ok:
			errs.append("idea '%s' not exhibited: %s" % [src.idea, idea.evidence])
		var target := 0
		if src.precision:
			if mr.proved and (def.bell_budget < 0 or def.bell_budget > int(mr.min)):
				target = def.total_items() + int(mr.min)
			else:
				errs.append("precision target would not be meaningful")
		var nonbell := 0
		for st in tr.get("steps", []):
			if (st.alternatives as Array).any(func(x): return x.status == Solver.UNSOLVABLE and x.kind != "ring"):
				nonbell += 1
		var free := d.duplicate(true)
		free.erase("sequence")
		free.erase("bell_budget")
		var fa := [_good_first(def), _good_first(LevelDef.from_dict(free)), LedgerAnalysis.actions(PuzzleState.create(def)).size()]
		var ms := Time.get_ticks_msec() - t0
		var key := "ledger_" + str(src.id)
		d["meta"] = {"customers": src.customers, "ledger": {
			"group": src.group, "number": src.number, "idea_tag": src.idea, "difficulty_estimate": src.difficulty,
			"name": key + "_name", "tagline": key + "_tag", "idea": key + "_idea", "hint1": key + "_hint1",
			"hint2": key + "_hint2", "why": key + "_why",
			"witness": Array(witness), "precision_target": target, "min_rings": mr.min,
			"proof": {"solver": Solver.VERSION, "content_hash": def.content_hash(), "witness_replay": rep.ok,
				"min_rings_proved": mr.proved, "choice_points": tr.get("choice_points", 0), "nonbell_choice_points": nonbell,
				"dead_ends": tr.get("traps", 0), "dead_end_kinds": tr.get("trap_kinds", {}), "idea_evidence": idea.evidence,
				"first_actions": fa, "nodes": best.nodes, "ms": ms}}}
		if not errs.is_empty():
			failures += 1
			print("FAIL ", src.id, " ", errs)
		else:
			print("OK   %s %s choice=%d nonbell=%d min_rings=%d target=%d (%d ms)" % [src.id, src.idea, tr.choice_points, nonbell, mr.min, target, ms])
		pages.append(d)
		proofs += "| %s | %s | %s (%s) | %d | %s | %s | %d%s | %s | %s | %d (%d) | %s | %d / %d / %d | %d | %d | %d/5 (estimate) | `%s` |\n" % [src.id, src.group,
			src.idea, idea.evidence, def.total_items(), "∞" if def.bell_budget < 0 else str(def.bell_budget),
			str(Array(def.sequence)) if not def.sequence.is_empty() else "—", mr.min, " (proved)" if mr.proved else " (NOT proved)",
			str(target) + " (proven minimal)" if target > 0 else "—", "PASS" if rep.ok else "FAIL",
			tr.get("choice_points", 0), nonbell, JSON.stringify(tr.get("trap_kinds", {})), fa[0], fa[1], fa[2], best.nodes, ms, src.difficulty, def.content_hash()]
		spoil += "## %s: %s (%s)\n\n%s\n\n" % [src.id, Loc.t("ledger_%s_name" % src.id), src.idea, Loc.t("ledger_%s_why" % src.id)]
		var s := PuzzleState.create(def)
		for k in witness.size():
			var line := describe(s, witness[k])
			for o in def.orders.size():
				line = line.replace("[serves order %d]" % o, "[serves %s]" % Loc.t("name_" + str(src.customers[o])))
			spoil += "%d. %s\n" % [k + 1, line]
			Rules.apply_action(s, witness[k])
		spoil += "\n"
	if failures > 0:
		print("BUILD FAILED: ", failures, " page(s)")
		return 1
	var f := FileAccess.open("res://data/levels/ledger.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "solver": Solver.VERSION, "pages": pages}, "\t"))
	f.close()
	var docs := ProjectSettings.globalize_path("res://").path_join("../docs").simplify_path()
	for pair in [["EXPERT_PUZZLE_PROOFS.md", proofs], ["EXPERT_SOLUTIONS_SPOILERS.md", spoil]]:
		var g := FileAccess.open(docs.path_join(pair[0]), FileAccess.WRITE)
		g.store_string(pair[1])
		g.close()
	print("wrote ", pages.size(), " pages")
	return 0
