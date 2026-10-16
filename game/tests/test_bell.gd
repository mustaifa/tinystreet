extends "res://tests/test_base.gd"
## v3 priority bell: rules, undo, session replay, solver, hints, validator.

const C := Products.COFFEE
const T := Products.TEA

## Found by search: no solution without the bell; with it, ring ticket 2 once.
const NEEDS_BELL := {"id": "nb", "counter": 1, "trays": 2,
	"crates": [["tea", "coffee", "coffee"], ["tea", "coffee", "coffee"]],
	"orders": [[{"coffee": 1}], [{"coffee": 1}], [{"coffee": 2}], [{"tea": 2}]]}

func test_bell_redirects_crate_items() -> void:
	var L := lvl({"counter": 2, "trays": 2, "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var s := PuzzleState.create(L)
	eq(Rules.preview(s, 0).tray, 0, "leftmost by default")
	var ev := Rules.ring(s, 1)
	eq(ev.size(), 1)
	eq(s.pin, 1)
	eq(Rules.preview(s, 0).tray, 1, "rung ticket served first")
	eq(s.moves, 0, "ringing is not a move")

func test_bell_falls_back_when_rung_ticket_doesnt_need_item() -> void:
	var L := lvl({"counter": 2, "trays": 2, "crates": [["tea"], ["coffee"]],
		"orders": [[{"tea": 1}], [{"coffee": 1}]]})
	var s := PuzzleState.create(L)
	Rules.ring(s, 1)
	eq(Rules.preview(s, 0).tray, 0, "tea still goes to the only ticket needing it")

func test_bell_toggles_and_moves() -> void:
	var L := lvl({"counter": 2, "trays": 2, "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var s := PuzzleState.create(L)
	Rules.ring(s, 0)
	eq(s.pin, 0)
	Rules.ring(s, 1)
	eq(s.pin, 1, "ringing another ticket moves the bell")
	Rules.ring(s, 1)
	eq(s.pin, -1, "ringing the same ticket clears it")

func test_bell_clears_on_delivery_and_routes_counter() -> void:
	# Counter holds coffee; both new tickets need coffee; bell picks ticket 2.
	var L := lvl({"counter": 2, "trays": 2, "crates": [["coffee", "tea", "croissant"]],
		"orders": [[{"tea": 1}], [{"croissant": 1}], [{"coffee": 1}], [{"coffee": 1}]]})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 0) # coffee -> counter
	eq(s.counter_used(), 1)
	Rules.ring(s, 1)
	Rules.apply_move(s, 0) # tea -> t0 completes; o2 (coffee) arrives in t0
	# The bell is on t1 (croissant), which doesn't need coffee, so the
	# counter coffee falls back to t0.
	eq(s.counter_used(), 0)
	Rules.apply_move(s, 0) # croissant -> t1 completes: bell clears
	eq(s.pin, -1, "bell clears when its order is delivered")

func test_cannot_ring_empty_ticket_or_when_disabled() -> void:
	var L := lvl({"counter": 2, "trays": 2, "crates": [["coffee"]], "orders": [[{"coffee": 1}]]})
	var s := PuzzleState.create(L)
	check(not Rules.can_ring(s, 1), "no order in ticket 2")
	eq(Rules.ring(s, 1), [])
	var off := lvl({"counter": 2, "trays": 2, "bell": false, "crates": [["coffee"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var s2 := PuzzleState.create(off)
	check(not Rules.can_ring(s2, 0), "bell disabled by level")

func test_bell_never_makes_an_illegal_tap_legal() -> void:
	var p := Progression.new()
	p.load_levels()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for l in p.campaign.slice(0, 30):
		var s := PuzzleState.create(LevelDef.from_dict(l))
		for step in 12:
			var lm := Rules.legal_moves(s)
			if lm.is_empty():
				break
			for t in s.tray_order.size():
				var b := s.copy()
				Rules.ring(b, t)
				eq(Rules.legal_moves(b), lm, "%s: ringing changed legality" % l.id)
			Rules.apply_move(s, lm[rng.randi_range(0, lm.size() - 1)])

func test_undo_and_restore_include_bell() -> void:
	var L := LevelDef.from_dict(NEEDS_BELL)
	var ps := PuzzleSession.start(L)
	ps.tap(0)
	ps.tap(0)
	ps.ring(1)
	eq(ps.state.pin, 1)
	eq(ps.taps(), 2)
	ps.tap(0)
	var back := PuzzleSession.restore(L, ps.to_dict())
	eq(back.state.key(), ps.state.key(), "replayed with the ring")
	ps.undo()
	eq(ps.state.pin, 1, "undo of the tap keeps the ring")
	ps.undo()
	eq(ps.state.pin, -1, "undo of the ring clears it")

func test_solver_proves_bell_required_and_hints_ring() -> void:
	var L := LevelDef.from_dict(NEEDS_BELL)
	var r := Solver.new().solve(PuzzleState.create(L))
	eq(r.status, Solver.SOLVED)
	check(Array(r.path).has(Rules.bell_action(1)), "solution rings ticket 2")
	check(Solver.verify_path(L, r.path))
	eq(Solver.new().solve(PuzzleState.create(L.without_bell())).status, Solver.UNSOLVABLE, "proven impossible without the bell")
	eq(LevelValidator.bell_value(L), "required")
	# hint at the decisive moment is the ring, not a crate
	var ps := PuzzleSession.start(L)
	ps.tap(0)
	ps.tap(0)
	var h := ps.compute_hint()
	eq(h.status, Solver.SOLVED)
	eq(h.bell, 1, "hint says: ring ticket 2")

func test_solver_paths_never_ring_twice_in_a_row() -> void:
	var L := LevelDef.from_dict(NEEDS_BELL)
	var r := Solver.new().solve(PuzzleState.create(L))
	var path := Array(r.path)
	for i in range(1, path.size()):
		check(not (path[i] < 0 and path[i - 1] < 0), "consecutive rings in %s" % [path])

func test_bell_level_roundtrip_and_schema() -> void:
	var d := NEEDS_BELL.duplicate(true)
	d.bell = false
	eq(LevelDef.from_dict(d).to_dict().get("bell"), false)
	d.bell = "yes"
	check(not LevelValidator.schema_errors(d).is_empty(), "bell must be bool")
	var three := {"id": "s3", "counter": 2, "trays": 1, "crates": [["coffee", "tea"], ["croissant"]],
		"orders": [[{"coffee": 1}, {"tea": 1}, {"croissant": 1}]]}
	eq(LevelValidator.schema_errors(three), [], "3-part special orders allowed")
	eq(LevelValidator.validate(three).verdict, LevelValidator.PASSED)
