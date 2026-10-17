extends SceneTree
## Delivery Logic level validation and analysis report.
##   godot --headless --path game -s res://tools/delivery_report.gd [-- --write]
## Checks every shipped level (schema, bounds, counts, unsolved start,
## solution replayed through DeliveryRules, proved minimum pushes, crate
## participation, duplicates, documented mistakes and claims) and runs the
## seeded baseline agents. --write regenerates data/delivery/proofs.json and
## docs/DELIVERY_LEVEL_REPORT.md. Exit code 1 if any level fails a gate.
##
## Agent results flag weak levels; they are not measurements of human fun.

const RANDOM_RUNS := 200
const RANDOM_BUDGET := 150
const GREEDY_RUNS := 20
const GREEDY_BUDGET := 150
const SEED0 := 1

func _initialize() -> void:
	var write := "--write" in OS.get_cmdline_user_args()
	var src = JSON.parse_string(FileAccess.get_file_as_string(DeliveryProgress.LEVELS_PATH))
	var en = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/en.json"))
	var ar = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/ar.json"))
	var proofs := {}
	var md := PackedStringArray()
	var rows := PackedStringArray()
	var fails := 0
	var ids := {}
	var canon := {}
	var walls := {}
	var nontut_dependency := 0
	var t_all := Time.get_ticks_msec()
	for ld in src.levels:
		var l := DeliveryLevel.from_dict(ld)
		var problems: Array[String] = []
		var notes: Array[String] = []
		if ids.has(l.id):
			problems.append("duplicate id")
		ids[l.id] = true
		problems.append_array(l.errors)
		for k in ["title", "nudge"]:
			var key := str(ld.get(k, ""))
			if key == "" or not en.has(key) or not ar.has(key):
				problems.append("missing string %s '%s' (en/ar)" % [k, key])
		var coach: Dictionary = ld.get("coach", {}) if ld.get("coach") is Dictionary else {}
		for ck in coach:
			if not en.has(str(coach[ck])) or not ar.has(str(coach[ck])):
				problems.append("missing coach string " + str(coach[ck]))
		if int(ld.get("reward", 0)) <= 0:
			problems.append("no completion reward")
		if not l.is_valid():
			_fail_row(rows, l.id, problems)
			fails += 1
			continue
		var s0 := DeliveryRules.start_state(l)
		if DeliveryRules.is_won(l, s0):
			problems.append("starts solved")
		if DeliveryRules.deadlock(l, s0).code != DeliveryRules.Dead.NONE:
			problems.append("starts deadlocked")
		# duplicates (same puzzle under rotation/mirror/symbol relabelling)
		var cl := DeliveryAnalysis.canonical_layout(l)
		if canon.has(cl):
			problems.append("duplicate layout of " + str(canon[cl]))
		canon[cl] = l.id
		var cw := DeliveryAnalysis.canonical_walls(l)
		if walls.has(cw):
			notes.append("same room walls as %s (different puzzle)" % walls[cw])
		else:
			walls[cw] = l.id
		var t0 := Time.get_ticks_msec()
		var g := DeliveryAnalysis.graph(l, 400000)
		var sv := DeliverySolver.solve(l, s0, 400000)
		var mv := sv.moves()
		var replay_ok := sv.status == DeliverySolver.SOLVED and DeliverySolver.validate(l, s0, mv)
		if not replay_ok:
			problems.append("solver solution missing or does not replay (status %d)" % sv.status)
		if not g.complete:
			problems.append("state graph incomplete: minimum not proved")
		elif int(g.min_pushes) != sv.push_list.size():
			problems.append("BFS minimum %d != graph minimum %d" % [sv.push_list.size(), g.min_pushes])
		var idle := _idle_crates(l, s0, mv)
		if idle > 0 and l.crate_count() > 1:
			problems.append("%d crate(s) never move in the shortest solution" % idle)
		var pr := DeliveryAnalysis.path_report(l, g)
		var rnd := DeliveryAnalysis.random_agent(l, RANDOM_RUNS, RANDOM_BUDGET, SEED0)
		var gr := DeliveryAnalysis.greedy_agent(l, GREEDY_RUNS, GREEDY_BUDGET, SEED0)
		var fo := DeliveryAnalysis.fixed_order_agent(l)
		var ms := DeliveryAnalysis.verify_mistake(l, ld.get("mistake", []))
		var tutorial := str(ld.get("design", {}).get("dependency", "")).contains("tutorial")
		if not ms.legal:
			problems.append("documented mistake is not playable")
		elif int(ms.code) < 0 and not tutorial:
			problems.append("documented mistake is not proved unsolvable: " + str(ms.text))
		var claim_lines := PackedStringArray()
		var claims_ok := 0
		for c in ld.get("claims", []):
			var vr := DeliveryAnalysis.verify_claim(l, c)
			claim_lines.append("- %s: **%s**" % [vr.text, "verified" if vr.ok else ("NOT verified (status %d)" % vr.status)])
			if vr.ok:
				claims_ok += 1
			else:
				problems.append("claim not verified: " + vr.text)
		if not tutorial:
			if gr.wins == gr.runs:
				problems.append("greedy agent always solves it")
			if fo.nearest_first:
				problems.append("nearest-first delivery solves it")
			if pr.trap_states < 2:
				problems.append("fewer than 2 trap positions on the solution path")
			if claims_ok > 0 or fo.orders_ok < fo.orders:
				nontut_dependency += 1
		var ms_time := Time.get_ticks_msec() - t0
		proofs[l.id] = {"min_pushes": int(g.min_pushes), "positions": int(g.nodes), "method": "exhaustive BFS over push positions"}
		if not problems.is_empty():
			fails += 1
		rows.append("| %s | %s | %dx%d | %d | %d | %d | %d/%d | %d | %d | %d | %.0f%% | %.0f%% | %s | %d/%d | %s |" % [
			l.id, Loc.t(str(ld.title)) if en.has(str(ld.title)) else str(ld.title), l.w, l.h, l.crate_count(), g.min_pushes, g.nodes,
			pr.trap_states, pr.pushes, pr.silent_states, pr.tempting, pr.displacement,
			100.0 * rnd.rate, 100.0 * gr.rate, "yes" if fo.nearest_first else "no", fo.orders_ok, fo.orders,
			"PASS" if problems.is_empty() else "FAIL"])
		md.append(_level_md(l, ld, g, pr, sv, rnd, gr, fo, ms, claim_lines, problems, notes, ms_time))
		print("%s %s min=%d nodes=%d trap_states=%d silent=%d greedy=%d/%d nf=%s orders=%d/%d mistake=%s claims=%d/%d %s" % [
			"PASS" if problems.is_empty() else "FAIL", l.id, g.min_pushes, g.nodes, pr.trap_states, pr.silent_states,
			gr.wins, gr.runs, fo.nearest_first, fo.orders_ok, fo.orders, ms.text, claims_ok, ld.get("claims", []).size(), problems])
	print("levels=%d failed=%d non-tutorial levels with a verified dependency=%d (%d ms)" % [src.levels.size(), fails, nontut_dependency, Time.get_ticks_msec() - t_all])
	if write:
		var f := FileAccess.open("res://data/delivery/proofs.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"generated_by": "tools/delivery_report.gd", "levels": proofs}, "\t", true))
		f.close()
		var out := PackedStringArray()
		out.append(_header(src.levels.size(), fails, nontut_dependency))
		out.append("| Level | Title | Size | Crates | Min pushes (proved) | Positions | Trap positions / path | Silent | Tempting traps | Displacement pushes | Random | Greedy | Nearest-first solves | Orders that work | Gate |")
		out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		out.append_array(rows)
		out.append("")
		out.append_array(md)
		var r := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../docs/DELIVERY_LEVEL_REPORT.md"), FileAccess.WRITE)
		r.store_string("\n".join(out))
		r.close()
		print("wrote proofs.json and docs/DELIVERY_LEVEL_REPORT.md")
	quit(1 if fails > 0 else 0)

func _fail_row(rows: PackedStringArray, id: String, problems: Array) -> void:
	rows.append("| %s | INVALID: %s |" % [id, ", ".join(problems)])
	print("FAIL ", id, " ", problems)

## Crates (by index) that never move while replaying the solution.
func _idle_crates(l: DeliveryLevel, s0: DeliveryState, mv: PackedInt32Array) -> int:
	var s := s0.copy()
	var moved := {}
	for d in mv:
		var t := l.nbr(s.player, d)
		var i := s.at[t] if l.floor_at(t) else -1
		if DeliveryRules.move(l, s, d) == DeliveryRules.PUSH:
			moved[i] = true
	return l.crate_count() - moved.size()

func _header(n: int, fails: int, dep: int) -> String:
	return """# Delivery Logic — Level Design and Solver Validation Report

*Generated by `game/tools/delivery_report.gd --write`. Do not edit by hand.*

**What this proves and what it does not.**
* "Min pushes (proved)" is the exact minimum number of pushes, found by
  exhaustive breadth-first search over every reachable push position
  (crates + courier region). It is not a designer target. Steps (walking) are
  not minimised.
* Every level's solution is replayed action by action through `DeliveryRules`
  and must end solved. Every documented mistake is replayed and must end in a
  position that is **proved** unsolvable (instant dead-cell/freeze check or
  exhaustive search). Every claim is verified by an exhaustive search that
  forbids the claimed necessity and finds no solution.
* Solvability and the agents below say nothing about whether a human finds a
  level fun or how hard it feels. That needs playtesting.

**Columns.** *Trap positions*: positions on one shortest solution where at
least one non-reversal push makes the level unsolvable. *Silent*: of those,
positions where such a push is not caught by the instant checks (only search
reveals it). *Tempting traps*: trap pushes that move a crate closer to a
matching pad. *Displacement*: shortest-solution pushes that move a crate
away from its pads. *Random*: %d runs, seeds %d–%d, %d pushes each, legal
pushes chosen uniformly, immediate reversal only when nothing else is legal.
*Greedy*: %d runs, seeds %d–%d, %d pushes each, always the push that most
reduces the summed push distance of every crate to its nearest matching pad,
never revisiting a position (ties by seeded RNG). *Nearest-first*: deliver the
crate closest to a pad completely, then the next. *Orders*: of all fixed
crate orders (one crate delivered completely at a time, others standing
still), how many succeed.

**Result:** %d levels, %d failed a gate. Non-tutorial levels with a verified
dependency (a verified claim, or some fixed delivery orders failing): %d.

""" % [RANDOM_RUNS, SEED0, SEED0 + RANDOM_RUNS - 1, RANDOM_BUDGET, GREEDY_RUNS, SEED0, SEED0 + GREEDY_RUNS - 1, GREEDY_BUDGET, n, fails, dep]

func _level_md(l: DeliveryLevel, ld: Dictionary, g: Dictionary, pr: Dictionary, sv: DeliverySolver,
		rnd: Dictionary, gr: Dictionary, fo: Dictionary, ms: Dictionary, claims: PackedStringArray,
		problems: Array, notes: Array, ms_time: int) -> String:
	var d: Dictionary = ld.get("design", {})
	var o := PackedStringArray()
	o.append("## %s — %s" % [l.id, Loc.t(str(ld.title))])
	o.append("")
	o.append("```")
	o.append_array(l.map)
	o.append("```")
	o.append("")
	o.append("* **Concept:** " + str(d.get("concept", "")))
	o.append("* **Intended insight:** " + str(d.get("insight", "")))
	o.append("* **Plausible mistake:** " + str(d.get("mistake", "")))
	o.append("* **Why it fails:** " + str(d.get("why", "")))
	o.append("* **Mistake check:** pushes `%s` → %s" % [JSON.stringify(ld.get("mistake", [])), ms.text])
	o.append("* **Builds on:** " + (", ".join(PackedStringArray(d.get("builds_on", []))) if not d.get("builds_on", []).is_empty() else "—"))
	o.append("* **Dependency:** " + str(d.get("dependency", "")))
	if not claims.is_empty():
		o.append("* **Claims:**")
		for c in claims:
			o.append("  " + c)
	var txt := PackedStringArray()
	for e in sv.push_list:
		txt.append("%s(%d,%d)%s" % ["ABCD"[l.crate_sym[0]] if false else "", e.x % l.w, e.x / l.w, ["↑", "→", "↓", "←"][e.y]])
	o.append("* **Verified solution (%d pushes, %d actions, replayed through the rules):** `%s`" % [sv.push_list.size(), sv.moves().size(), " ".join(txt)])
	o.append("* **Search:** %d positions, %.0f%% of expanded positions unsolvable, %d ms" % [g.nodes, 100.0 * g.dead_ratio, ms_time])
	o.append("* **Path:** %d choice positions, %d trap positions (%d silent), %d trap pushes (%d tempting), %d displacement pushes" % [
		pr.choice_states, pr.trap_states, pr.silent_states, pr.traps, pr.tempting, pr.displacement])
	o.append("* **Agents:** random %d/%d, greedy %d/%d, nearest-first %s, fixed orders %d/%d" % [
		rnd.wins, rnd.runs, gr.wins, gr.runs, "solves" if fo.nearest_first else "fails", fo.orders_ok, fo.orders])
	for n in notes:
		o.append("* Note: " + n)
	o.append("* **Gate:** " + ("PASS" if problems.is_empty() else "FAIL — " + "; ".join(PackedStringArray(problems))))
	o.append("")
	return "\n".join(o)
