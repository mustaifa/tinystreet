extends "res://tests/test_base.gd"
## v4 expert-mode rules (bell budget, order sequence) and solver correctness
## under them, including a brute-force cross-check on tiny boards.

func test_bell_budget_enforced_and_undoable() -> void:
	var L := lvl({"counter": 2, "trays": 2, "bell_budget": 1, "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var ps := PuzzleSession.start(L)
	eq(Rules.rings_left(ps.state), 1)
	check(not ps.ring(1).is_empty(), "first ring allowed")
	eq(ps.state.rings_used, 1)
	eq(Rules.rings_left(ps.state), 0)
	check(not Rules.can_ring(ps.state, 0), "budget spent")
	eq(ps.ring(0), [], "second ring refused")
	eq(ps.ring(1), [], "clearing also needs a ring")
	ps.undo()
	eq(ps.state.rings_used, 0, "undo restores the budget")
	eq(ps.state.pin, -1)
	var unl := lvl({"counter": 2, "trays": 2, "crates": [["coffee"]], "orders": [[{"coffee": 1}]]})
	eq(Rules.rings_left(PuzzleState.create(unl)), -1, "unlimited when no budget")

func test_budget_in_search_key() -> void:
	var L := lvl({"counter": 2, "trays": 2, "bell_budget": 2, "crates": [["coffee"]], "orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var a := PuzzleState.create(L)
	var b := a.copy()
	Rules.ring(b, 0)
	Rules.ring(b, 0)
	eq(b.pin, -1)
	check(a.key() != b.key(), "same board, different budget left: different search states")
	# Without a budget, rings used don't affect the future: same key (keeps
	# unlimited-bell searches finite).
	var U := lvl({"counter": 2, "trays": 2, "crates": [["coffee"]], "orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var c := PuzzleState.create(U)
	var e := c.copy()
	Rules.ring(e, 0)
	Rules.ring(e, 0)
	eq(c.key(), e.key(), "unlimited bell: rings used are not part of the state")

func test_sequence_refuses_out_of_order_delivery() -> void:
	# Order 1 (tea) must come before order 0 (coffee).
	var L := lvl({"counter": 2, "trays": 2, "sequence": [1, 0], "crates": [["coffee"], ["tea"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}]]})
	var s := PuzzleState.create(L)
	var pv := Rules.preview(s, 0)
	eq(pv.dest, Rules.Dest.NONE, "coffee would deliver order 0 first")
	eq(pv.block, Rules.Block.SEQUENCE)
	eq(Rules.apply_move(s, 0), [], "refused, state unchanged")
	eq(s.crate_pos[0], 0)
	Rules.apply_move(s, 1)
	check(s.delivered(1))
	eq(Rules.sequence_next(s), 1, "next in sequence is order 0")
	check(Rules.is_legal(s, 0), "now coffee may complete order 0")
	Rules.apply_move(s, 0)
	check(Rules.is_won(s))
	eq(Rules.sequence_next(s), -1)

func test_sequence_checks_whole_cascade() -> void:
	# Coffee on the counter would auto-complete order 0 when tea arrives... the
	# tap that triggers that cascade is refused, not the counter item.
	var L := lvl({"counter": 2, "trays": 1, "sequence": [2, 1], "crates": [["tea", "coffee", "croissant"]],
		"orders": [[{"tea": 1}], [{"coffee": 1}], [{"croissant": 1}]]})
	var s := PuzzleState.create(L)
	check(Rules.is_legal(s, 0), "tea completes order 0 (not in the sequence)")
	Rules.apply_move(s, 0)
	# order 1 (coffee) is next in the queue; delivering it before order 2 breaks the sequence
	eq(Rules.preview(s, 0).block, Rules.Block.SEQUENCE)
	check(Rules.is_lost(s), "no legal action left: a lost position, recoverable by undo")

func test_ring_can_rescue_a_sequence_position() -> void:
	# Two tickets need coffee; sequence wants ticket 2's order first. Without
	# the bell, the tap goes left and is refused; ringing ticket 2 makes it legal.
	var L := lvl({"counter": 1, "trays": 2, "sequence": [1, 0], "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var s := PuzzleState.create(L)
	eq(Rules.preview(s, 0).block, Rules.Block.SEQUENCE)
	check(not Rules.is_lost(s), "a ring would make a tap legal: not lost")
	Rules.ring(s, 1)
	check(Rules.is_legal(s, 0))
	Rules.apply_move(s, 0)
	Rules.apply_move(s, 0)
	check(Rules.is_won(s))
	var L0 := lvl({"counter": 1, "trays": 2, "sequence": [1, 0], "bell_budget": 0, "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	check(Rules.is_lost(PuzzleState.create(L0)), "with no rings left it is lost")

func test_content_hash_tracks_rules_not_meta() -> void:
	var d := {"id": "h", "counter": 2, "trays": 2, "bell_budget": 1, "sequence": [1, 0],
		"crates": [["coffee"], ["tea"]], "orders": [[{"coffee": 1}], [{"tea": 1}]], "meta": {"x": 1}}
	var h := LevelDef.from_dict(d).content_hash()
	var d2 := d.duplicate(true)
	d2.meta.x = 2
	eq(LevelDef.from_dict(d2).content_hash(), h, "meta changes don't matter")
	d2.bell_budget = 2
	check(LevelDef.from_dict(d2).content_hash() != h, "budget change invalidates")
	d2.bell_budget = 1
	d2.sequence = [0, 1]
	check(LevelDef.from_dict(d2).content_hash() != h, "sequence change invalidates")

func test_witness_replay_checks_constraints() -> void:
	var L := lvl({"counter": 1, "trays": 2, "bell_budget": 1, "sequence": [1, 0], "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var good := LedgerAnalysis.replay(L, PackedInt32Array([Rules.bell_action(1), 0, 0]))
	check(good.ok and good.sequence_ok and good.budget_ok, str(good))
	eq(good.delivered, [1, 0])
	var bad := LedgerAnalysis.replay(L, PackedInt32Array([0, 0]))
	check(not bad.ok, "out-of-sequence witness rejected")

func test_min_rings_proof() -> void:
	var L := lvl({"counter": 1, "trays": 2, "bell_budget": 2, "sequence": [1, 0], "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var mr := LedgerAnalysis.min_rings(L)
	eq(mr.min, 1)
	check(mr.proved, "budget 0 proven unsolvable")

## The optimised solver (memo, ring pruning, move ordering) must agree with a
## plain exhaustive search on many tiny boards with budgets and sequences.
func test_solver_matches_reference_on_tiny_boards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var prods := ["coffee", "tea", "croissant"]
	var checked := 0
	var solvable := 0
	for it in 120:
		var orders: Array = []
		var bag: Array = []
		for o in rng.randi_range(2, 4):
			var st := {}
			for k in rng.randi_range(1, 2):
				var p: String = prods[rng.randi_range(0, 2)]
				st[p] = int(st.get(p, 0)) + 1
				bag.append(p)
			orders.append([st])
		bag.shuffle()
		var crates: Array = [[], []]
		for i in bag.size():
			crates[i % 2].append(bag[i])
		var d := {"id": "t", "counter": rng.randi_range(1, 2), "trays": 2, "crates": crates, "orders": orders,
			"bell_budget": rng.randi_range(0, 2)}
		if rng.randf() < 0.6:
			var idx: Array = range(orders.size())
			idx.shuffle()
			d["sequence"] = idx.slice(0, 2)
		var L := LevelDef.from_dict(d)
		var fast := Solver.new(200000).solve(PuzzleState.create(L))
		if fast.status == Solver.TIMEOUT:
			continue
		var ref := LedgerAnalysis.reference_solvable(PuzzleState.create(L))
		eq(fast.status == Solver.SOLVED, ref, "solver vs reference on %s" % JSON.stringify(d))
		if fast.status == Solver.SOLVED:
			check(Solver.verify_path(L, fast.path), "witness replays")
			solvable += 1
		checked += 1
	check(checked >= 100, "compared %d boards" % checked)
	check(solvable >= 20 and solvable < checked, "mix of solvable (%d) and unsolvable" % solvable)
