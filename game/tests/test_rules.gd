extends "res://tests/test_base.gd"
## Tests for the real rules layer (Rules, PuzzleState, PuzzleSession, Solver).

const C := Products.COFFEE
const T := Products.TEA
const R := Products.CROISSANT

func test_routes_to_order_when_needed() -> void:
	var L := lvl({"crates": [["coffee"], ["tea"]], "orders": [[{"coffee": 1}], [{"tea": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	var ev := Rules.apply_move(s, 0)
	eq(ev[1].type, Rules.EV_TO_TRAY)
	eq(s.completed, 1)
	eq(s.tray_order[0], 1, "next order arrives in same tray")
	eq(s.counter_used(), 0)

func test_routes_to_counter_when_not_needed() -> void:
	var L := lvl({"crates": [["tea", "coffee"]], "orders": [[{"coffee": 1}], [{"tea": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	var ev := Rules.apply_move(s, 0)
	eq(ev[1].type, Rules.EV_TO_COUNTER)
	eq(s.counter[0], T)
	eq(s.peak_counter, 1)

func test_leftmost_tray_priority() -> void:
	var L := lvl({"crates": [["coffee", "coffee", "tea", "tea"]], "trays": 2,
		"orders": [[{"tea": 1, "coffee": 1}], [{"coffee": 1}], [{"tea": 1}]]})
	var s := PuzzleState.create(L)
	var pv := Rules.preview(s, 0)
	eq(pv.dest, Rules.Dest.TRAY)
	eq(pv.tray, 0, "leftmost tray needing coffee wins")
	Rules.apply_move(s, 0)
	eq(s.tray_fill[0][C], 1)
	eq(s.tray_fill[1][C], 0)
	# Tray 0 no longer needs coffee: next coffee goes to tray 1.
	eq(Rules.preview(s, 0).tray, 1)

func test_counter_capacity_blocks_buffer_moves() -> void:
	var L := lvl({"counter": 1, "crates": [["tea"], ["croissant"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], [{"croissant": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 0) # tea -> counter
	eq(s.counter_free(), 0)
	check(not Rules.is_legal(s, 1), "croissant cannot go anywhere")
	eq(Rules.apply_move(s, 1), [], "illegal move returns no events")
	eq(s.crate_pos[1], 0, "illegal move leaves state unchanged")

func test_direct_move_legal_with_full_counter_and_not_lost() -> void:
	var L := lvl({"counter": 1, "crates": [["tea"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 0) # tea -> counter (full)
	check(Rules.is_legal(s, 1), "coffee goes straight to order despite full counter")
	check(not Rules.is_lost(s), "full counter is not defeat while a direct move exists")
	Rules.apply_move(s, 1)
	check(Rules.is_won(s), "chained: tea auto-fills arriving order -> win")

func test_chained_resolution() -> void:
	# Counter holds tea + croissant; completing coffee order brings tea order,
	# tea auto-fills and completes, croissant order arrives and auto-fills.
	var L := lvl({"counter": 2, "crates": [["tea", "croissant", "coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], [{"croissant": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 0)
	Rules.apply_move(s, 0)
	eq(s.counter_used(), 2)
	var ev := Rules.apply_move(s, 0)
	check(Rules.is_won(s), "chain completes level")
	var types: Array = ev.map(func(e): return e.type)
	eq(types.count(Rules.EV_DELIVER), 3)
	eq(types.count(Rules.EV_COUNTER_TO_TRAY), 2)
	eq(s.counter_used(), 0)

func test_two_stage_order() -> void:
	var L := lvl({"counter": 2, "crates": [["tea", "coffee", "tea"]],
		"orders": [[{"coffee": 1}, {"tea": 2}]], "trays": 1})
	var s := PuzzleState.create(L)
	eq(s.tray_needs(0, T), 0, "stage 2 not active yet")
	Rules.apply_move(s, 0) # tea -> counter
	eq(s.counter[0], T)
	var ev := Rules.apply_move(s, 0) # coffee completes stage 1, tea auto-fills stage 2
	eq(s.tray_stage[0], 1)
	eq(s.tray_fill[0][T], 1)
	check(ev.any(func(e): return e.type == Rules.EV_STAGE))
	Rules.apply_move(s, 0)
	check(Rules.is_won(s))

func test_loss_detection() -> void:
	var L := lvl({"counter": 1, "crates": [["tea", "croissant"], ["coffee", "coffee"]],
		"orders": [[{"croissant": 1}], [{"coffee": 2}], [{"tea": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 1) # coffee -> counter (full)
	# fronts: tea (not needed, no space), coffee (not needed, no space)
	check(Rules.is_lost(s), "no legal move and not won => lost")
	check(not Rules.is_won(s))

func test_win_checked_before_loss() -> void:
	var L := lvl({"counter": 1, "crates": [["coffee"]], "orders": [[{"coffee": 1}]], "trays": 1})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 0)
	check(Rules.is_won(s))
	check(not Rules.is_lost(s), "won state is never lost even with no moves")

func test_full_state_undo() -> void:
	var L := lvl({"counter": 2, "crates": [["tea", "croissant", "coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], [{"croissant": 1}]], "trays": 1})
	var ps := PuzzleSession.start(L)
	ps.tap(0); ps.tap(0)
	var before := ps.state.key()
	var peak_before := ps.state.peak_counter
	var moves_before := ps.state.moves
	ps.tap(0) # big chain incl. deliveries
	check(ps.is_won())
	check(not ps.can_undo(), "no undo after win")
	# Undo in a non-terminal position instead
	var ps2 := PuzzleSession.start(L)
	ps2.tap(0)
	var k1 := ps2.state.key()
	ps2.tap(0)
	check(ps2.undo())
	eq(ps2.state.key(), k1, "state restored")
	eq(ps2.state.peak_counter, 1, "peak counter (score effect) restored")
	eq(ps2.state.moves, 1)
	eq(ps2.undo_count, 1)
	eq(ps2.moves_log.size(), 1)
	check(before != "" and peak_before == 2 and moves_before == 2)

func test_undo_restores_auto_transfers_and_orders() -> void:
	var L := lvl({"counter": 2, "crates": [["tea", "coffee", "croissant"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], [{"croissant": 1}]], "trays": 1})
	var ps := PuzzleSession.start(L)
	ps.tap(0) # tea -> counter
	var k := ps.state.key()
	ps.tap(0) # coffee delivers; tea order arrives and auto-fills from counter; croissant order arrives
	eq(ps.state.completed, 2)
	ps.undo()
	eq(ps.state.key(), k)
	eq(ps.state.completed, 0)
	eq(ps.state.counter[0], T, "auto-transferred product back on counter")
	eq(ps.state.tray_order[0], 0, "original order back in tray")
	eq(ps.state.next_order, 1)

func test_continue_adds_one_slot_once() -> void:
	var L := lvl({"counter": 1, "crates": [["tea", "croissant"], ["coffee", "coffee"]],
		"orders": [[{"croissant": 1}], [{"coffee": 2}], [{"tea": 1}]], "trays": 1})
	var ps := PuzzleSession.start(L)
	ps.tap(1)
	check(ps.is_lost())
	check(ps.can_continue())
	check(ps.grant_continue())
	check(not ps.grant_continue(), "max one continuation per attempt")
	check(not ps.is_lost(), "extra slot makes a move legal")
	ps.undo()
	eq(ps.state.counter.size(), 2, "undo keeps the bonus slot")

func test_session_roundtrip_serialisation() -> void:
	var L := lvl({"counter": 2, "crates": [["tea", "croissant", "coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], [{"croissant": 1}]], "trays": 1})
	var ps := PuzzleSession.start(L)
	ps.tap(0); ps.tap(0); ps.undo(); ps.tap(0)
	var d := ps.to_dict()
	var back := PuzzleSession.restore(L, JSON.parse_string(JSON.stringify(d)))
	eq(back.state.key(), ps.state.key())
	eq(back.undo_count, 1)
	eq(back.history.size(), ps.history.size())

func test_solver_finds_and_rejects() -> void:
	var good := lvl({"counter": 1, "crates": [["tea", "croissant"], ["coffee", "coffee"]],
		"orders": [[{"croissant": 1}], [{"coffee": 2}], [{"tea": 1}]], "trays": 1})
	var r := Solver.new(10000).solve(PuzzleState.create(good))
	eq(r.status, Solver.SOLVED)
	check(Solver.verify_path(good, r.path), "solution replays")
	var bad := lvl({"counter": 0, "crates": [["tea"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], ], "trays": 1})
	bad.counter_slots = 0
	bad.crates[0] = PackedInt32Array([T, C]); bad.crates[1] = PackedInt32Array([C])
	bad.orders = [[PackedInt32Array([2, 0, 0, 0, 0, 0])], [PackedInt32Array([0, 1, 0, 0, 0, 0])]]
	var r2 := Solver.new(10000).solve(PuzzleState.create(bad))
	eq(r2.status, Solver.UNSOLVABLE)

func test_solver_timeout_is_not_a_verdict() -> void:
	var L := lvl({"counter": 3, "crates": [["tea", "croissant", "tea"], ["coffee", "coffee", "croissant"], ["tea", "coffee", "croissant"]],
		"orders": [[{"croissant": 3}], [{"coffee": 3}], [{"tea": 3}]], "trays": 1})
	var r := Solver.new(1).solve(PuzzleState.create(L))
	eq(r.status, Solver.TIMEOUT)

func test_hint_from_current_state_after_any_route() -> void:
	var L := lvl({"counter": 2, "crates": [["tea", "croissant"], ["coffee", "coffee"]],
		"orders": [[{"croissant": 1}], [{"coffee": 2}], [{"tea": 1}]], "trays": 1})
	var ps := PuzzleSession.start(L)
	ps.tap(1) # a different route than the recorded solution might take
	var h := ps.compute_hint()
	eq(h.status, Solver.SOLVED)
	check(Rules.is_legal(ps.state, h.crate))

func test_hint_reports_unsolvable_position() -> void:
	var L := lvl({"counter": 1, "crates": [["tea", "croissant"], ["coffee", "coffee"]],
		"orders": [[{"croissant": 1}], [{"coffee": 2}], [{"tea": 1}]], "trays": 1})
	var ps := PuzzleSession.start(L)
	ps.tap(1) # dead end
	eq(ps.compute_hint().status, Solver.UNSOLVABLE)
	eq(ps.undos_to_solvable(), 1)

func test_stars() -> void:
	var L := lvl({"counter": 2, "crates": [["tea", "coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}]], "trays": 1, "meta": {"par_counter": 1}})
	var ps := PuzzleSession.start(L)
	ps.tap(0); ps.tap(0)
	eq(ps.stars(), 3)
	eq(Scoring.stars(L, ps.state, 2, false), 2, "too many undos drops third star")
	eq(Scoring.stars(L, ps.state, 0, true), 2, "continuation drops third star")
	ps.state.peak_counter = 2
	eq(Scoring.stars(L, ps.state, 0, false), 1, "messy counter drops second star")

func test_validator_quantity_mismatch() -> void:
	var d := {"id": "x", "counter": 2, "trays": 1, "crates": [["coffee"], ["tea"]], "orders": [[{"coffee": 2}], [{"tea": 1}]]}
	var r := LevelValidator.validate(d)
	eq(r.verdict, LevelValidator.FAILED)
	check(str(r.errors).contains("coffee"), str(r.errors))

func test_validator_schema() -> void:
	var d := {"id": "x", "counter": 2, "trays": 9, "crates": [["coffee", "pizza"]], "orders": []}
	var e := LevelValidator.schema_errors(d)
	check(e.size() >= 3, str(e))

func test_rules_are_deterministic() -> void:
	var L := lvl({"counter": 3, "crates": [["tea", "croissant", "tea"], ["coffee", "coffee", "croissant"], ["tea", "coffee", "croissant"]],
		"orders": [[{"croissant": 3}], [{"coffee": 3}], [{"tea": 3}]], "trays": 2})
	var a := PuzzleState.create(L)
	var b := PuzzleState.create(L)
	for c in [1, 0, 2, 1, 0]:
		Rules.apply_move(a, c)
		Rules.apply_move(b, c)
	eq(a.key(), b.key())
