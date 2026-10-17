extends "res://tests/test_base.gd"
## Delivery Logic rules (docs/DELIVERY_RULES.md): walking, pushing, blocking,
## matching, wrong destinations, no pull / no double push, invalid input,
## undo/redo, win detection, deadlock soundness and false-positive checks.

const U := DeliveryRules.Dir.UP
const R := DeliveryRules.Dir.RIGHT
const D := DeliveryRules.Dir.DOWN
const L := DeliveryRules.Dir.LEFT

func _lv(rows: Array) -> DeliveryLevel:
	var l := DeliveryLevel.from_rows("t", rows)
	check(l.is_valid(), "level valid: %s" % [l.errors])
	return l

func _cell(l: DeliveryLevel, x: int, y: int) -> int:
	return y * l.w + x

func test_parse_and_validation() -> void:
	var l := _lv(["#######", "#@.A.a#", "#######"])
	eq(l.w, 7)
	eq(l.start_player, _cell(l, 1, 1))
	eq(l.start_crates, PackedInt32Array([_cell(l, 3, 1)]))
	eq(l.goal[_cell(l, 5, 1)], 0)
	var bad := DeliveryLevel.from_rows("b", ["#####", "#@AB#", "#a..#", "#####"])
	check(not bad.is_valid(), "B without destination is rejected")
	var open := DeliveryLevel.from_rows("o", ["#####", "#@Aa.", "#####"])
	check(not open.is_valid(), "floor open to the outside is rejected")
	var two := DeliveryLevel.from_rows("p", ["#####", "#@Aa#", "#@..#", "#####"])
	check(not two.is_valid(), "two couriers rejected")
	var on := _lv(["######", "#@.1.#", "######"])
	check(DeliveryRules.is_won(on, DeliveryRules.start_state(on)), "digit = crate already on its destination")

func test_walk_and_counters() -> void:
	var l := _lv(["######", "#@...#", "#..A.#", "#..a.#", "######"])
	var s := DeliveryRules.start_state(l)
	eq(DeliveryRules.move(l, s, R), DeliveryRules.STEP)
	eq(s.player, _cell(l, 2, 1))
	eq(s.steps, 1)
	eq(s.pushes, 0)
	eq(DeliveryRules.move(l, s, U), DeliveryRules.INVALID, "wall")
	eq(s.steps, 1, "invalid move keeps counters")
	eq(s.player, _cell(l, 2, 1))

func test_push_and_win() -> void:
	var l := _lv(["######", "#@...#", "#..A.#", "#..a.#", "######"])
	var s := DeliveryRules.start_state(l)
	DeliveryRules.move(l, s, R)
	DeliveryRules.move(l, s, R)
	check(not DeliveryRules.is_won(l, s))
	eq(DeliveryRules.move(l, s, D), DeliveryRules.PUSH)
	eq(s.crates[0], _cell(l, 3, 3))
	eq(s.player, _cell(l, 3, 2))
	eq(s.pushes, 1)
	eq(s.steps, 2)
	check(DeliveryRules.is_won(l, s), "crate on matching destination wins")

func test_push_blocked_by_wall_and_crate() -> void:
	var l := _lv(["#######", "#@AB.b#", "#a....#", "#######"])
	var s := DeliveryRules.start_state(l)
	var before := s.snapshot()
	eq(DeliveryRules.move(l, s, R), DeliveryRules.INVALID, "no pushing two crates at once")
	eq(s.snapshot(), before, "state unchanged")
	var l2 := _lv(["#####", "#.@A#", "#.a.#", "#####"])
	var s2 := DeliveryRules.start_state(l2)
	eq(DeliveryRules.move(l2, s2, R), DeliveryRules.INVALID, "crate against a wall can't be pushed into it")

func test_no_pulling() -> void:
	var l := _lv(["#######", "#.@A.a#", "#######"])
	var s := DeliveryRules.start_state(l)
	eq(DeliveryRules.move(l, s, L), DeliveryRules.STEP)
	eq(s.crates[0], _cell(l, 3, 1), "walking away leaves the crate where it was")

func test_wrong_destination_does_not_count() -> void:
	var l := _lv(["#######", "#@A.b.#", "#.B.a.#", "#######"])
	var s := DeliveryRules.start_state(l)
	DeliveryRules.move(l, s, R)
	DeliveryRules.move(l, s, R)   # A onto b
	eq(l.goal[s.crates[0]], 1, "A stands on the croissant destination")
	check(not DeliveryRules.is_won(l, s), "wrong destination does not satisfy")
	eq(DeliveryRules.delivered_count(l, s), 0)
	eq(DeliveryRules.move(l, s, R), DeliveryRules.PUSH, "crates stay movable on a destination")

func test_walk_path_never_pushes() -> void:
	var l := _lv(["#######", "#@.A..#", "#.###.#", "#.....#", "#a....#", "#######"])
	var s := DeliveryRules.start_state(l)
	var target := _cell(l, 4, 1)
	var path := DeliveryRules.walk_path(l, s, target)
	eq(path.size(), 9, "walks around the crate")
	var k := DeliveryRules.walk(l, s, target)
	eq(k, path.size())
	eq(s.pushes, 0, "a walk never pushes")
	eq(s.crates[0], _cell(l, 3, 1))
	eq(DeliveryRules.walk(l, s, _cell(l, 3, 1)), 0, "can't walk onto a crate")
	eq(DeliveryRules.walk(l, s, _cell(l, 0, 0)), 0, "can't walk onto a wall")
	var l2 := _lv(["#######", "#@.A.a#", "#######"])
	var s2 := DeliveryRules.start_state(l2)
	eq(DeliveryRules.walk(l2, s2, _cell(l2, 5, 1)), 0, "unreachable behind a crate")
	eq(s2.steps, 0)

func test_session_undo_redo_exact() -> void:
	var l := _lv(["######", "#@...#", "#..A.#", "#..a.#", "######"])
	var ps := DeliverySession.start(l)
	var s0 := ps.state.snapshot()
	ps.act(R)
	var s1 := ps.state.snapshot()
	ps.act(R)
	var s2 := ps.state.snapshot()
	eq(ps.act(U), DeliveryRules.INVALID)
	eq(ps.history.size(), 2, "invalid input adds no history")
	check(ps.undo())
	eq(ps.state.snapshot(), s1)
	check(ps.undo())
	eq(ps.state.snapshot(), s0, "undo back to start: counters zero again")
	check(not ps.undo(), "nothing more to undo")
	check(ps.redo())
	check(ps.redo())
	eq(ps.state.snapshot(), s2, "redo restores exactly")
	ps.undo()
	ps.act(D)
	check(not ps.can_redo(), "a new action clears redo")
	ps.restart()
	eq(ps.state.snapshot(), s0)
	check(not ps.can_undo())

func test_session_walk_is_one_undo() -> void:
	var l := _lv(["#######", "#@....#", "#..A..#", "#..a..#", "#######"])
	var ps := DeliverySession.start(l)
	eq(ps.walk_to(_cell(l, 5, 3)), 6)
	eq(ps.history.size(), 1)
	ps.undo()
	eq(ps.state.player, l.start_player)
	eq(ps.state.steps, 0)

func test_session_ignores_input_after_win() -> void:
	var l := _lv(["######", "#@A.a#", "######"])
	var ps := DeliverySession.start(l)
	ps.act(R)
	ps.act(R)
	check(ps.is_won())
	var snap := ps.state.snapshot()
	eq(ps.act(L), DeliveryRules.INVALID)
	check(not ps.undo(), "no undo once solved")
	eq(ps.state.snapshot(), snap)

func test_session_save_roundtrip_and_guards() -> void:
	var l := _lv(["#######", "#@....#", "#..A..#", "#..a..#", "#######"])
	var ps := DeliverySession.start(l)
	ps.act(R)
	ps.act(D)
	ps.hints_used = 2
	var d := JSON.parse_string(JSON.stringify(ps.to_dict()))
	var back := DeliverySession.restore(l, d)
	check(back != null)
	eq(back.state.snapshot(), ps.state.snapshot())
	eq(back.history.size(), 2)
	eq(back.hints_used, 2)
	back.undo()
	back.undo()
	eq(back.state.snapshot(), DeliveryRules.start_state(l).snapshot(), "history survives a reload")
	# changed layout -> not resumed
	var l2 := _lv(["#######", "#@....#", "#.A...#", "#..a..#", "#######"])
	check(DeliverySession.restore(l2, d) == null, "different level hash is refused")
	# damaged data -> not resumed
	var bad: Dictionary = d.duplicate(true)
	bad.state = [0, 0, 0, 1]
	check(DeliverySession.restore(l, bad) == null, "crate on a wall refused")
	bad.state = [8, 0, 0, 8]
	check(DeliverySession.restore(l, bad) == null, "overlap refused")
	bad.state = "x"
	check(DeliverySession.restore(l, bad) == null, "garbage refused")

# ------------------------------------------------------------------ deadlocks

func test_dead_cell_corner() -> void:
	var l := _lv(["#######", "#....a#", "#.A...#", "#@....#", "#######"])
	var s := DeliveryRules.start_state(l)
	eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.NONE)
	DeliveryRules.move(l, s, U)
	DeliveryRules.move(l, s, R)   # push A to (3,2)? no: courier (1,2) -> push A right
	s = DeliveryRules.start_state(l)
	s.player = _cell(l, 2, 3)
	DeliveryRules.move(l, s, U)   # A from (2,2) to (2,1): top wall row, goal a is on it -> still live
	eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.NONE, "top row holds the a destination")
	s.player = _cell(l, 3, 1)
	DeliveryRules.move(l, s, L)   # A into corner (1,1)
	var dl := DeliveryRules.deadlock(l, s)
	eq(dl.code, DeliveryRules.Dead.DEAD_CELL, "corner without matching destination")
	eq(dl.crates, [0])
	eq(DeliverySolver.solve(l, s).status, DeliverySolver.UNSOLVABLE)

func test_corner_with_matching_destination_is_fine() -> void:
	var l := _lv(["######", "#a...#", "#.A..#", "#..@.#", "######"])
	var s := DeliveryRules.start_state(l)
	s.player = _cell(l, 3, 2)
	DeliveryRules.move(l, s, L)
	s.player = _cell(l, 1, 3)
	DeliveryRules.move(l, s, U)
	check(DeliveryRules.is_won(l, s), "corner destination reached")
	eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.NONE)

func test_corner_with_other_symbol_destination_is_dead() -> void:
	var l := _lv(["#######", "#b...a#", "#.A.B.#", "#..@..#", "#######"])
	var s := DeliveryRules.start_state(l)
	s.player = _cell(l, 3, 2)
	DeliveryRules.move(l, s, L)
	s.player = _cell(l, 1, 3)
	DeliveryRules.move(l, s, U)   # coffee crate into the croissant corner
	eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.DEAD_CELL, "destinations count only for their own symbol")

func test_frozen_square() -> void:
	# Any 2x2 block of crates is frozen, even in open floor: every push of
	# every crate in it is blocked by another crate of the block.
	var l := _lv(["#########", "#.......#", "#..AB...#", "#..BA...#", "#.....ab#", "#..@..ba#", "#########"])
	var s := DeliveryRules.start_state(l)
	eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.FROZEN)
	eq(DeliverySolver.solve(l, s).status, DeliverySolver.UNSOLVABLE)
	# Two crates side by side in open floor are NOT frozen.
	var l2 := _lv(["#########", "#.......#", "#..AB...#", "#.......#", "#.....ab#", "#..@....#", "#########"])
	var s2 := DeliveryRules.start_state(l2)
	eq(DeliveryRules.deadlock(l2, s2).code, DeliveryRules.Dead.NONE, "a pair in the open can still move")
	eq(DeliverySolver.solve(l2, s2).status, DeliverySolver.SOLVED)
	# A pair side by side against a wall is frozen: neither can be pushed
	# sideways (the other crate or nowhere to stand) nor off the wall.
	var l3 := _lv(["########", "#.AB.ab#", "#..@...#", "########"])
	var s3 := DeliveryRules.start_state(l3)
	eq(DeliveryRules.deadlock(l3, s3).code, DeliveryRules.Dead.FROZEN, "pair along a wall")
	eq(DeliverySolver.solve(l3, s3).status, DeliverySolver.UNSOLVABLE)
	# ...but not when both already stand on their own destinations.
	var l5 := _lv(["########", "#.12...#", "#..@...#", "########"])
	eq(DeliveryRules.deadlock(l5, DeliveryRules.start_state(l5)).code, DeliveryRules.Dead.NONE)
	var l4 := _lv(["#######", "#AB..b#", "#BA..a#", "#.@.ab#", "#######"])
	var dl := DeliveryRules.deadlock(l4, DeliveryRules.start_state(l4))
	check(dl.code != DeliveryRules.Dead.NONE, "2x2 block in a corner")
	eq(DeliverySolver.solve(l4, DeliveryRules.start_state(l4)).status, DeliverySolver.UNSOLVABLE)

func test_frozen_on_wrong_goal_against_wall() -> void:
	# A and B side by side along the bottom wall, both live there, neither can
	# move horizontally (each other + wall) nor vertically (wall below,
	# and the cell above is fine) -> not frozen. Then close the top.
	var l := _lv(["#######", "#.....#", "#.ab..#", "#..@..#", "#.BA..#", "#######"])
	var s := DeliveryRules.start_state(l)
	eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.DEAD_CELL, "bottom row has no destination")

func test_no_false_positive_on_start_positions() -> void:
	var rows := [["#######", "#.....#", "#.A.B.#", "#.b.a.#", "#..@..#", "#######"],
		["########", "#@.....#", "#.#A#..#", "#..a.B.#", "#.##b..#", "########"]]
	for r in rows:
		var l := _lv(r)
		var s := DeliveryRules.start_state(l)
		eq(DeliveryRules.deadlock(l, s).code, DeliveryRules.Dead.NONE)
		eq(DeliverySolver.solve(l, s).status, DeliverySolver.SOLVED)

## Soundness: on many random positions of small rooms, every instant
## deadlock claim is confirmed by the exhaustive solver, and the solver's
## SOLVED answers replay through the rules.
func test_deadlock_checks_are_sound() -> void:
	var rooms := [
		["#######", "#.....#", "#.#.#.#", "#.....#", "#.#.#.#", "#.....#", "#######"],
		["########", "#......#", "#......#", "#..##..#", "#......#", "########"],
		["#######", "#.....#", "#..#..#", "#.....#", "##...##", " #...# ", " ##### "],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var claims := 0
	var solved := 0
	for rr in rooms:
		for trial in 120:
			var rows := _random_fill(rr, rng, 2 + trial % 2)
			var l := DeliveryLevel.from_rows("r", rows)
			if not l.is_valid():
				continue
			var s := DeliveryRules.start_state(l)
			var dl := DeliveryRules.deadlock(l, s)
			var sv := DeliverySolver.solve(l, s, 50000)
			if dl.code != DeliveryRules.Dead.NONE:
				claims += 1
				eq(sv.status, DeliverySolver.UNSOLVABLE, "instant claim confirmed: %s" % [rows])
			if sv.status == DeliverySolver.SOLVED:
				solved += 1
				check(DeliverySolver.validate(l, s, sv.moves()), "solution replays: %s" % [rows])
	check(claims > 20, "enough deadlock claims exercised (%d)" % claims)
	check(solved > 20, "enough solutions exercised (%d)" % solved)

## The solver's push count is the minimum: compare with the complete graph.
func test_solver_is_push_optimal() -> void:
	var rows := ["#######", "#.....#", "#.#A#.#", "#..aB.#", "#.#.#b#", "#..@..#", "#######"]
	var l := _lv(rows)
	var sv := DeliverySolver.solve(l, DeliveryRules.start_state(l))
	eq(sv.status, DeliverySolver.SOLVED)
	var g := DeliveryAnalysis.graph(l)
	check(g.complete)
	eq(sv.push_list.size(), int(g.min_pushes))

func test_solver_timeout_is_not_unsolvable() -> void:
	var l := _lv(["#########", "#.......#", "#.A.B.C.#", "#.......#", "#.c.b.a.#", "#...@...#", "#########"])
	var sv := DeliverySolver.new(l, DeliveryRules.start_state(l), 5)
	sv.run()
	eq(sv.status, DeliverySolver.TIMEOUT, "a tiny budget times out")
	check(sv.status != DeliverySolver.UNSOLVABLE)

func test_solver_incremental_matches_blocking() -> void:
	var l := _lv(["#######", "#.....#", "#.#A#.#", "#..aB.#", "#.#.#b#", "#..@..#", "#######"])
	var a := DeliverySolver.new(l, DeliveryRules.start_state(l))
	var frames := 0
	while a.step(1) == DeliverySolver.RUNNING:
		frames += 1
	check(frames > 1, "spread over several steps")
	var b := DeliverySolver.solve(l, DeliveryRules.start_state(l))
	eq(a.status, b.status)
	eq(a.push_list.size(), b.push_list.size())

func _random_fill(room: Array, rng: RandomNumberGenerator, k: int) -> Array:
	var grid: Array = []
	var floors: Array = []
	for y in room.size():
		var r: Array = []
		for x in str(room[y]).length():
			r.append(room[y][x])
			if room[y][x] == ".":
				floors.append(Vector2i(x, y))
		grid.append(r)
	for i in range(floors.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = floors[i]; floors[i] = floors[j]; floors[j] = t
	var idx := 0
	for i in k:
		var s := i % 2
		var g: Vector2i = floors[idx]; idx += 1
		grid[g.y][g.x] = char("a".unicode_at(0) + s)
		var c: Vector2i = floors[idx]; idx += 1
		grid[c.y][c.x] = char("A".unicode_at(0) + s)
	var p: Vector2i = floors[idx]
	grid[p.y][p.x] = "@"
	var out: Array = []
	for r in grid:
		out.append("".join(r))
	return out
