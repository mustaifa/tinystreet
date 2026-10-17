extends "res://tests/test_base.gd"
## Shipped Delivery Logic levels: every one is valid, starts unsolved and
## not dead, has a solution that replays through the rules, matches its
## proved minimum (proofs.json), has its strings in both languages, and the
## documented mistakes/claims still hold. A level edit that breaks any of
## these fails here (full analysis: tools/delivery_report.gd).

var dp: DeliveryProgress

func setup_suite(_t: SceneTree) -> void:
	dp = DeliveryProgress.new()
	dp.load_levels()

func test_levels_valid_and_solvable() -> void:
	check(dp.count() >= 12, "at least the 12-puzzle slice")
	var ids := {}
	for ld in dp.levels:
		var l := DeliveryLevel.from_dict(ld)
		check(not ids.has(l.id), "unique id " + l.id)
		ids[l.id] = true
		check(l.is_valid(), "%s valid: %s" % [l.id, l.errors])
		if not l.is_valid():
			continue
		var s := DeliveryRules.start_state(l)
		check(not DeliveryRules.is_won(l, s), l.id + " starts unsolved")
		eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.NONE, l.id + " starts alive")
		var sv := DeliverySolver.solve(l, s, 400000)
		eq(sv.status, DeliverySolver.SOLVED, l.id + " solvable")
		check(DeliverySolver.validate(l, s, sv.moves()), l.id + " solution replays through the rules")
		eq(sv.push_list.size(), l.min_pushes(), l.id + " BFS minimum equals proofs.json")
		check(int(ld.get("reward", 0)) > 0, l.id + " has a completion reward")

func test_strings_exist() -> void:
	for ld in dp.levels:
		for k in [str(ld.title), str(ld.nudge)]:
			check(Loc.has_key(k, "en") and Loc.has_key(k, "ar"), "%s string %s" % [ld.id, k])
		var coach: Dictionary = ld.get("coach", {})
		for c in coach.values():
			check(Loc.has_key(str(c), "en") and Loc.has_key(str(c), "ar"), "%s coach %s" % [ld.id, c])
	for ch in dp.chapters:
		check(Loc.has_key(str(ch.title), "ar"), "chapter " + str(ch.title))

func test_documented_mistakes_and_claims_hold() -> void:
	var dependency := 0
	for ld in dp.levels:
		var l := DeliveryLevel.from_dict(ld)
		var tutorial := str(ld.design.dependency).contains("tutorial")
		var m := DeliveryAnalysis.verify_mistake(l, ld.get("mistake", []))
		check(m.legal, l.id + " mistake is playable")
		if not tutorial:
			check(int(m.code) >= 0, "%s mistake proved unsolvable (%s)" % [l.id, m.text])
		var ok := 0
		for c in ld.get("claims", []):
			var v := DeliveryAnalysis.verify_claim(l, c)
			check(v.ok, "%s claim: %s" % [l.id, v.text])
			if v.ok:
				ok += 1
		if not tutorial and ok > 0:
			dependency += 1
	check(dependency >= 6, "at least six non-tutorial puzzles with a verified dependency (%d)" % dependency)

func test_no_duplicate_layouts() -> void:
	var seen := {}
	for ld in dp.levels:
		var l := DeliveryLevel.from_dict(ld)
		var c := DeliveryAnalysis.canonical_layout(l)
		check(not seen.has(c), "%s duplicates %s (rotation/mirror/relabel)" % [l.id, seen.get(c, "")])
		seen[c] = l.id

func test_canonical_layout_catches_mirror_and_relabel() -> void:
	var a := DeliveryLevel.from_rows("a", ["######", "#@A.a#", "#.B.b#", "######"])
	var mirrored := DeliveryLevel.from_rows("b", ["######", "#a.A@#", "#b.B.#", "######"])
	var relabel := DeliveryLevel.from_rows("c", ["######", "#@C.c#", "#.A.a#", "######"])
	eq(DeliveryAnalysis.canonical_layout(a), DeliveryAnalysis.canonical_layout(mirrored))
	eq(DeliveryAnalysis.canonical_layout(a), DeliveryAnalysis.canonical_layout(relabel))

func test_non_tutorial_levels_beat_baseline_agents() -> void:
	for ld in dp.levels:
		if str(ld.design.dependency).contains("tutorial"):
			continue
		var l := DeliveryLevel.from_dict(ld)
		var gr := DeliveryAnalysis.greedy_agent(l, 10, 150, 1)
		check(gr.wins < gr.runs, "%s: greedy must not always solve it (%d/%d)" % [l.id, gr.wins, gr.runs])
		var fo := DeliveryAnalysis.fixed_order_agent(l)
		check(not fo.nearest_first, l.id + ": nearest-first delivery must fail")
