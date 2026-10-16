extends "res://tests/test_base.gd"
## v2 mechanics: fresh items, paper bags and delivery locks. All through the
## real Rules / Solver / LevelValidator.

const C := Products.COFFEE
const T := Products.TEA
const R := Products.CROISSANT

func test_item_markers_parse_and_roundtrip() -> void:
	eq(LevelDef.parse_item("coffee"), [C, 0])
	eq(LevelDef.parse_item("coffee!"), [C, LevelDef.FRESH])
	eq(LevelDef.parse_item("?tea"), [T, LevelDef.BAG])
	eq(LevelDef.parse_item("?tea!"), [T, LevelDef.BAG | LevelDef.FRESH])
	eq(LevelDef.parse_item("?nope")[0], -1)
	var L := lvl({"crates": [["coffee!", "?tea"], ["tea"]], "locks": [0, 1],
		"orders": [[{"coffee": 1}], [{"tea": 2}]]})
	var d := L.to_dict()
	eq(d.crates, [["coffee!", "?tea"], ["tea"]])
	eq(d.locks, [0, 1])
	eq(L.mechanics(), ["fresh", "bag", "lock"])

func test_fresh_never_goes_to_counter() -> void:
	var L := lvl({"counter": 3, "crates": [["tea!"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}]]})
	var s := PuzzleState.create(L)
	var pv := Rules.preview(s, 0)
	eq(pv.dest, Rules.Dest.NONE, "no order needs tea yet, counter refused")
	eq(pv.block, Rules.Block.FRESH)
	check(pv.fresh)
	eq(Rules.apply_move(s, 0), [], "illegal: state unchanged")
	eq(s.counter_used(), 0)
	Rules.apply_move(s, 1) # coffee delivered, tea order arrives
	eq(Rules.preview(s, 0).dest, Rules.Dest.TRAY, "fresh goes once an order needs it")
	Rules.apply_move(s, 0)
	check(Rules.is_won(s))

func test_fresh_block_counts_toward_loss() -> void:
	# Only move left is a fresh item nobody needs: that is a loss.
	var L := lvl({"counter": 2, "crates": [["tea!", "coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}]]})
	var s := PuzzleState.create(L)
	check(Rules.is_lost(s), "fresh tea blocks the only crate")
	eq(Solver.new().solve(s).status, Solver.UNSOLVABLE)

func test_bag_hides_until_front_and_emits_reveal() -> void:
	var L := lvl({"counter": 2, "crates": [["coffee", "?tea", "?croissant"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}], [{"croissant": 1}]]})
	var s := PuzzleState.create(L)
	eq(Rules.visible_product(s, 0, 0), C, "front always visible")
	eq(Rules.visible_product(s, 0, 1), -1, "bagged item hidden behind front")
	eq(Rules.visible_product(s, 0, 2), -1)
	var ev := Rules.apply_move(s, 0)
	var rev: Array = ev.filter(func(e): return e.type == Rules.EV_REVEAL)
	eq(rev.size(), 1)
	eq(rev[0].product, T)
	eq(Rules.visible_product(s, 0, 1), T, "revealed at the front")
	eq(Rules.visible_product(s, 0, 2), -1)
	# Bags never change routing: the rules always know the contents.
	eq(Rules.preview(s, 0).dest, Rules.Dest.TRAY)

func test_lock_opens_on_required_delivery() -> void:
	var L := lvl({"counter": 1, "crates": [["coffee", "coffee"], ["tea"]], "locks": [0, 2],
		"orders": [[{"coffee": 1}], [{"coffee": 1}], [{"tea": 1}]]})
	var s := PuzzleState.create(L)
	check(Rules.is_locked(s, 1))
	eq(Rules.lock_remaining(s, 1), 2)
	eq(Rules.preview(s, 1).block, Rules.Block.LOCKED)
	eq(Rules.apply_move(s, 1), [], "locked crate cannot be tapped")
	Rules.apply_move(s, 0)
	eq(Rules.lock_remaining(s, 1), 1)
	var ev := Rules.apply_move(s, 0)
	var un: Array = ev.filter(func(e): return e.type == Rules.EV_UNLOCK)
	eq(un.size(), 1, "unlock event on the second delivery")
	eq(un[0].crate, 1)
	check(not Rules.is_locked(s, 1))
	Rules.apply_move(s, 1)
	check(Rules.is_won(s))

func test_locks_and_undo_restore_exactly() -> void:
	var L := lvl({"counter": 2, "crates": [["coffee"], ["tea"]], "locks": [0, 1],
		"orders": [[{"coffee": 1}], [{"tea": 1}]]})
	var ps := PuzzleSession.start(L)
	ps.tap(0)
	check(not Rules.is_locked(ps.state, 1))
	ps.undo()
	check(Rules.is_locked(ps.state, 1), "undo re-locks the crate")

func test_solver_respects_mechanics() -> void:
	# Fresh coffee must wait for the coffee order (2nd): the solver has to
	# buffer the tea first.
	var L := lvl({"counter": 1, "crates": [["coffee!"], ["tea"]],
		"orders": [[{"tea": 1}], [{"coffee": 1}]]})
	var r := Solver.new().solve(PuzzleState.create(L))
	eq(r.status, Solver.SOLVED)
	eq(Array(r.path), [1, 0])
	check(Solver.verify_path(L, r.path))

func test_validator_schema_for_mechanics() -> void:
	var good := {"id": "m", "counter": 2, "trays": 1, "locks": [0, 1],
		"crates": [["coffee!", "?tea"], ["tea"]], "orders": [[{"coffee": 1}], [{"tea": 2}]]}
	eq(LevelValidator.schema_errors(good), [])
	var bad_len := good.duplicate(true)
	bad_len.locks = [0]
	check(not LevelValidator.schema_errors(bad_len).is_empty(), "locks length must match crates")
	var all_locked := good.duplicate(true)
	all_locked.locks = [1, 1]
	check(not LevelValidator.schema_errors(all_locked).is_empty(), "some crate must start open")
	var too_high := good.duplicate(true)
	too_high.locks = [0, 2]
	check(not LevelValidator.schema_errors(too_high).is_empty(), "lock beyond order count")
	var r := LevelValidator.validate(good)
	eq(r.verdict, LevelValidator.PASSED, str(r.errors))

func test_unsolvable_mechanic_level_fails_validation() -> void:
	# Fresh tea is in front of the coffee that the first order needs: no solution.
	var d := {"id": "x", "counter": 3, "trays": 1,
		"crates": [["tea!", "coffee"]], "orders": [[{"coffee": 1}], [{"tea": 1}]]}
	var r := LevelValidator.validate(d)
	eq(r.verdict, LevelValidator.FAILED)

func test_engagement_metrics_detect_mechanic_use() -> void:
	var L := lvl({"counter": 1, "crates": [["coffee!"], ["tea", "?croissant"]], "locks": [0, 0],
		"orders": [[{"tea": 1}], [{"coffee": 1}], [{"croissant": 1}]]})
	var r := Solver.new().solve(PuzzleState.create(L))
	var m := LevelValidator.mechanic_engagement(L, r.path)
	check(int(m.fresh_waits) >= 1, "fresh coffee had to wait")
	eq(int(m.reveals), 1)
	eq(int(m.lock_moves), 0)

func test_session_restore_with_mechanics() -> void:
	var L := lvl({"counter": 2, "crates": [["coffee", "?tea"], ["croissant!"]], "locks": [0, 1],
		"orders": [[{"coffee": 1}], [{"croissant": 1}], [{"tea": 1}]]})
	var ps := PuzzleSession.start(L)
	ps.tap(0)
	ps.tap(1)
	var back := PuzzleSession.restore(L, ps.to_dict())
	eq(back.state.key(), ps.state.key())
	eq(back.state.completed, ps.state.completed)
