class_name DeliveryAnalysis
extends RefCounted
## Level-quality analysis for Delivery Logic (authoring tools and tests only;
## never used during play). Everything goes through DeliveryRules.
##
## graph(): every push position reachable from the start, with each push's
##   result and the exact remaining fewest pushes to a win (-1 = unsolvable).
## Agents: random pushes, greedy toward matching goals, fixed crate order.
## These numbers flag weak levels; they are not measurements of human fun.

const UNSOLVABLE := -1

## Full position graph. Returns {complete, nodes, start, min_pushes,
## dead_ratio, keys, edges, dist}. edges[n] = [[child or -1 (proved dead
## at once), crate cell, dir, crate index], ...].
static func graph(l: DeliveryLevel, max_nodes: int = 400000) -> Dictionary:
	var keys: Array[PackedByteArray] = []
	var seen := {}
	var edges: Array = []
	var won := PackedByteArray()
	var s0 := DeliveryRules.start_state(l)
	var k0 := DeliveryRules.key(l, s0, DeliveryRules.reach(l, s0))
	seen[k0] = 0
	keys.append(k0)
	won.append(1 if DeliveryRules.is_won(l, s0) else 0)
	var head := 0
	var complete := true
	while head < keys.size():
		if keys.size() > max_nodes:
			complete = false
			break
		var out: Array = []
		if won[head] == 0:
			var s := DeliveryRules.from_key(l, keys[head])
			var m := DeliveryRules.reach(l, s)
			for pv in DeliveryRules.pushes_from(l, s, m):
				var from_cell := s.crates[pv.x]
				var t := s.copy()
				t.player = l.nbr(from_cell, DeliveryRules.opposite(pv.y))
				DeliveryRules.move(l, t, pv.y)
				if DeliveryRules.push_creates_deadlock(l, t, pv.x):
					out.append([-1, from_cell, pv.y, pv.x])
					continue
				var k := DeliveryRules.key(l, t, DeliveryRules.reach(l, t))
				var ci: int
				if seen.has(k):
					ci = seen[k]
				else:
					ci = keys.size()
					seen[k] = ci
					keys.append(k)
					won.append(1 if DeliveryRules.is_won(l, t) else 0)
				out.append([ci, from_cell, pv.y, pv.x])
		edges.append(out)
		head += 1
	var nn := edges.size()
	# Backward BFS from wins over expanded nodes: exact fewest pushes to win.
	var dist := PackedInt32Array()
	dist.resize(keys.size())
	dist.fill(UNSOLVABLE)
	var rev: Array = []
	rev.resize(keys.size())
	for i in keys.size():
		rev[i] = PackedInt32Array()
	for i in nn:
		for e in edges[i]:
			if int(e[0]) >= 0:
				rev[int(e[0])].append(i)
	var q := PackedInt32Array()
	for i in keys.size():
		if won[i] == 1:
			dist[i] = 0
			q.append(i)
	var qh := 0
	while qh < q.size():
		var c := q[qh]
		qh += 1
		for p in rev[c]:
			if dist[p] == UNSOLVABLE:
				dist[p] = dist[c] + 1
				q.append(p)
	var dead := 0
	for i in nn:
		if dist[i] == UNSOLVABLE:
			dead += 1
	return {"complete": complete, "nodes": keys.size(), "expanded": nn, "start": 0,
		"min_pushes": dist[0], "dead_ratio": float(dead) / maxf(1, nn),
		"keys": keys, "edges": edges, "dist": dist, "won": won}

## Walks one fewest-push solution and classifies every choice on the way.
## A push that only reverses the previous push is not counted as a choice.
##   choice_states   positions with two or more non-reversal pushes
##   trap_states     positions where some non-reversal push makes the level
##                   unsolvable (proved by the complete graph)
##   silent_states   ... where such a push is NOT caught by the instant
##                   dead-cell/frozen checks (only search reveals it)
##   traps / silent_traps / tempting   counts of such pushes; "tempting" =
##                   the trap push moves its crate closer to a matching goal
##   displacement    solution pushes that move a crate away from its goals
##                   (or off its own destination)
static func path_report(l: DeliveryLevel, g: Dictionary) -> Dictionary:
	var dist: PackedInt32Array = g.dist
	var edges: Array = g.edges
	var out := {"path": [], "traps": 0, "silent_traps": 0, "tempting": 0, "trap_states": 0,
		"silent_states": 0, "displacement": 0, "choice_states": 0, "trap_examples": [], "pushes": 0}
	if dist[0] == UNSOLVABLE or not g.complete:
		return out
	var pd: Array = []
	for s in DeliveryLevel.SYMBOLS:
		pd.append(DeliveryRules.push_distance(l, s))
	var node := 0
	var last_cell := -1   # crate cell after the previous push
	var last_dir := -1
	while dist[node] > 0:
		var best: Array = []
		var alts := 0
		var trap_here := false
		var silent_here := false
		for e in edges[node]:
			var child := int(e[0])
			var cell := int(e[1])
			var d := int(e[2])
			var reversal := last_dir >= 0 and cell == last_cell and d == DeliveryRules.opposite(last_dir)
			if child >= 0 and dist[child] == dist[node] - 1 and best.is_empty():
				best = e
			if reversal:
				continue
			alts += 1
			var cd := UNSOLVABLE if child < 0 else dist[child]
			if cd == UNSOLVABLE:
				trap_here = true
				out.traps += 1
				if child >= 0 and DeliveryRules.deadlock(l, DeliveryRules.from_key(l, g.keys[child])).code == DeliveryRules.Dead.NONE:
					out.silent_traps += 1   # not caught by the instant checks
					silent_here = true
				var sym := l.crate_sym[int(e[3])]
				var dt: PackedInt32Array = pd[sym]
				var to := l.nbr(cell, d)
				if dt[to] >= 0 and dt[cell] >= 0 and dt[to] < dt[cell]:
					out.tempting += 1
					if out.trap_examples.size() < 4:
						out.trap_examples.append({"push": dist[0] - dist[node] + 1, "crate": DeliveryLevel.SYMBOL_IDS[sym],
							"at": [cell % l.w, cell / l.w], "dir": DeliveryRules.DIR_IDS[d], "silent": silent_here})
		if alts >= 2:
			out.choice_states += 1
		if trap_here:
			out.trap_states += 1
		if silent_here:
			out.silent_states += 1
		# displacement: the solution pushes a crate away from its goals
		var bcell := int(best[1])
		var bsym := l.crate_sym[int(best[3])]
		var bd: PackedInt32Array = pd[bsym]
		var bto := l.nbr(bcell, int(best[2]))
		if bd[bto] > bd[bcell] or (l.goal[bcell] == bsym and l.goal[bto] != bsym):
			out.displacement += 1
		out.path.append([node, best])
		last_cell = bto
		last_dir = int(best[2])
		node = int(best[0])
	out.pushes = out.path.size()
	return out

# --------------------------------------------------------------- baseline agents

## Random legal pushes (an immediate reversal only when nothing else is
## possible). Returns {runs, wins, rate, budget, seeds}.
static func random_agent(l: DeliveryLevel, runs: int = 200, push_budget: int = 150, seed0: int = 1) -> Dictionary:
	var wins := 0
	for r in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed0 + r
		var s := DeliveryRules.start_state(l)
		var last := Vector2i(-1, -1)
		for k in push_budget:
			var m := DeliveryRules.reach(l, s)
			var opts := DeliveryRules.pushes_from(l, s, m)
			if opts.is_empty():
				break
			var fwd: Array = []
			for pv in opts:
				if not (s.crates[pv.x] == last.x and pv.y == DeliveryRules.opposite(last.y)):
					fwd.append(pv)
			var pick: Vector2i = fwd[rng.randi_range(0, fwd.size() - 1)] if not fwd.is_empty() else opts[rng.randi_range(0, opts.size() - 1)]
			_push(l, s, pick)
			last = Vector2i(s.crates[pick.x], pick.y)
			if DeliveryRules.is_won(l, s):
				wins += 1
				break
	return {"runs": runs, "wins": wins, "rate": float(wins) / runs, "budget": push_budget, "seeds": "%d-%d" % [seed0, seed0 + runs - 1]}

## Greedy: always the push that lowers the summed push distance of all
## crates to their nearest matching destination the most; never revisits a
## position; ties broken by a seeded RNG. Returns {runs, wins, rate, budget}.
static func greedy_agent(l: DeliveryLevel, runs: int = 20, push_budget: int = 150, seed0: int = 1) -> Dictionary:
	var pd: Array = []
	for sy in DeliveryLevel.SYMBOLS:
		pd.append(DeliveryRules.push_distance(l, sy))
	var wins := 0
	for r in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed0 + r
		var s := DeliveryRules.start_state(l)
		var visited := {}
		for k in push_budget:
			var m := DeliveryRules.reach(l, s)
			visited[DeliveryRules.key(l, s, m)] = true
			var best_h := 1 << 30
			var cands: Array = []
			for pv in DeliveryRules.pushes_from(l, s, m):
				var t := s.copy()
				_push(l, t, pv)
				var tk := DeliveryRules.key(l, t, DeliveryRules.reach(l, t))
				if visited.has(tk):
					continue
				var hv := _h(l, t, pd)
				if hv < best_h:
					best_h = hv
					cands = [pv]
				elif hv == best_h:
					cands.append(pv)
			if cands.is_empty():
				break
			_push(l, s, cands[rng.randi_range(0, cands.size() - 1)])
			if DeliveryRules.is_won(l, s):
				wins += 1
				break
	return {"runs": runs, "wins": wins, "rate": float(wins) / runs, "budget": push_budget, "seeds": "%d-%d" % [seed0, seed0 + runs - 1]}

static func _h(l: DeliveryLevel, s: DeliveryState, pd: Array) -> int:
	var v := 0
	for i in s.crates.size():
		var dd: PackedInt32Array = pd[l.crate_sym[i]]
		var x := dd[s.crates[i]]
		v += x if x >= 0 else 1000
	return v

static func _push(l: DeliveryLevel, s: DeliveryState, pv: Vector2i) -> void:
	s.player = l.nbr(s.crates[pv.x], DeliveryRules.opposite(pv.y))
	DeliveryRules.move(l, s, pv.y)

## Fixed order: deliver one crate completely (fewest pushes of that crate
## alone, others standing still) to a free matching destination, then the
## next. Tries "nearest first" and every crate order (up to 6 crates).
## Returns {nearest_first, orders, orders_ok}.
static func fixed_order_agent(l: DeliveryLevel) -> Dictionary:
	var n := l.crate_count()
	var pd: Array = []
	for sy in DeliveryLevel.SYMBOLS:
		pd.append(DeliveryRules.push_distance(l, sy))
	var s0 := DeliveryRules.start_state(l)
	var near: Array = range(n)
	near.sort_custom(func(a: int, b: int) -> bool:
		var da: int = (pd[l.crate_sym[a]] as PackedInt32Array)[s0.crates[a]]
		var db: int = (pd[l.crate_sym[b]] as PackedInt32Array)[s0.crates[b]]
		return da < db)
	var res := {"nearest_first": _run_order(l, near), "orders": 0, "orders_ok": 0}
	if n <= 6:
		for p in _perms(range(n)):
			res.orders += 1
			if _run_order(l, p):
				res.orders_ok += 1
	return res

static func _run_order(l: DeliveryLevel, order: Array) -> bool:
	var s := DeliveryRules.start_state(l)
	var done := {}
	for i in order:
		var t := _deliver_one(l, s, int(i), done)
		if t == null:
			return false
		s = t
		done[s.crates[int(i)]] = true
	return DeliveryRules.is_won(l, s)

## BFS moving only crate i to a matching destination not already used.
static func _deliver_one(l: DeliveryLevel, s: DeliveryState, i: int, used: Dictionary) -> DeliveryState:
	var sym := l.crate_sym[i]
	if l.goal[s.crates[i]] == sym and not used.has(s.crates[i]):
		return s
	var q: Array[DeliveryState] = [s]
	var seen := {DeliveryRules.key(l, s, DeliveryRules.reach(l, s)): true}
	var head := 0
	while head < q.size() and head < 20000:
		var c := q[head]
		head += 1
		var m := DeliveryRules.reach(l, c)
		for pv in DeliveryRules.pushes_from(l, c, m):
			if pv.x != i:
				continue
			var t := c.copy()
			_push(l, t, pv)
			var k := DeliveryRules.key(l, t, DeliveryRules.reach(l, t))
			if seen.has(k):
				continue
			seen[k] = true
			if l.goal[t.crates[i]] == sym and not used.has(t.crates[i]):
				return t
			q.append(t)
	return null

static func _perms(a: Array) -> Array:
	if a.size() <= 1:
		return [a]
	var out: Array = []
	for i in a.size():
		var rest := a.duplicate()
		var x = rest.pop_at(i)
		for p in _perms(rest):
			out.append([x] + p)
	return out

# --------------------------------------------------------------- duplicates

## Canonical layout under the 8 rotations/mirrors and symbol relabelling;
## equal strings mean the same puzzle.
static func canonical_layout(l: DeliveryLevel) -> String:
	var best := ""
	for t in 8:
		var s := _transform(l, t, false)
		if best == "" or s < best:
			best = s
	return best

## Walls-only canonical form (same room, objects anywhere).
static func canonical_walls(l: DeliveryLevel) -> String:
	var best := ""
	for t in 8:
		var s := _transform(l, t, true)
		if best == "" or s < best:
			best = s
	return best

static func _transform(l: DeliveryLevel, t: int, walls_only: bool) -> String:
	var rows: Array = []
	var tw := l.h if t % 2 == 1 else l.w
	var th := l.w if t % 2 == 1 else l.h
	var relabel := {}
	for y in th:
		var r := ""
		for x in tw:
			var sx := x
			var sy := y
			match t:
				0: sx = x; sy = y
				1: sx = y; sy = l.h - 1 - x
				2: sx = l.w - 1 - x; sy = l.h - 1 - y
				3: sx = l.w - 1 - y; sy = x
				4: sx = l.w - 1 - x; sy = y
				5: sx = y; sy = x
				6: sx = x; sy = l.h - 1 - y
				7: sx = l.w - 1 - y; sy = l.h - 1 - x
			var src: String = l.map[sy] if sy < l.map.size() else ""
			var ch := src[sx] if sx < src.length() else " "
			if walls_only:
				ch = "#" if ch == "#" else ("_" if ch == " " else ".")
			elif ch in ["a", "b", "c", "d", "A", "B", "C", "D", "1", "2", "3", "4"]:
				var base := ch.to_lower()
				if base in ["1", "2", "3", "4"]:
					base = char("a".unicode_at(0) + int(base) - 1)
				if not relabel.has(base):
					relabel[base] = char("a".unicode_at(0) + relabel.size())
				var nl: String = relabel[base]
				if ch in ["1", "2", "3", "4"]:
					ch = str(nl.unicode_at(0) - "a".unicode_at(0) + 1)
				elif ch == ch.to_upper():
					ch = nl.to_upper()
				else:
					ch = nl
			r += ch
		rows.append(r)
	return "/".join(rows)

# --------------------------------------------------------------- claims

## Exhaustive search that skips forbidden pushes / positions. Used to verify
## design claims: "every solution must X" holds iff the search that forbids
## "not X" finds nothing (UNSOLVABLE). Returns DeliverySolver.SOLVED,
## UNSOLVABLE or TIMEOUT.
static func constrained(l: DeliveryLevel, forbid_push: Callable, forbid_state: Callable, max_nodes: int = 300000) -> int:
	var s0 := DeliveryRules.start_state(l)
	if forbid_state.is_valid() and forbid_state.call(s0):
		return DeliverySolver.UNSOLVABLE
	var seen := {DeliveryRules.key(l, s0, DeliveryRules.reach(l, s0)): true}
	var q: Array[PackedByteArray] = [DeliveryRules.key(l, s0, DeliveryRules.reach(l, s0))]
	var head := 0
	while head < q.size():
		if q.size() > max_nodes:
			return DeliverySolver.TIMEOUT
		var s := DeliveryRules.from_key(l, q[head])
		head += 1
		var m := DeliveryRules.reach(l, s)
		for pv in DeliveryRules.pushes_from(l, s, m):
			var t := s.copy()
			_push(l, t, pv)
			if forbid_push.is_valid() and forbid_push.call(s, pv.x, pv.y, t):
				continue
			if forbid_state.is_valid() and forbid_state.call(t):
				continue
			if DeliveryRules.push_creates_deadlock(l, t, pv.x):
				continue
			if DeliveryRules.is_won(l, t):
				return DeliverySolver.SOLVED
			var k := DeliveryRules.key(l, t, DeliveryRules.reach(l, t))
			if not seen.has(k):
				seen[k] = true
				q.append(k)
	return DeliverySolver.UNSOLVABLE

static func _all_home(l: DeliveryLevel, s: DeliveryState, sym: int) -> bool:
	for i in s.crates.size():
		if l.crate_sym[i] == sym and not DeliveryRules.on_match(l, s, i):
			return false
	return true

static func _others_home(l: DeliveryLevel, s: DeliveryState, sym: int) -> bool:
	for i in s.crates.size():
		if l.crate_sym[i] != sym and not DeliveryRules.on_match(l, s, i):
			return false
	return true

## "No solution ever passes through a position with property P": every
## reachable position with P is unsolvable (complete graph, exact).
static func _no_solvable_state(l: DeliveryLevel, p: Callable) -> int:
	var g := graph(l, 400000)
	if not g.complete:
		return DeliverySolver.TIMEOUT
	for i in g.expanded:
		if g.dist[i] != UNSOLVABLE and p.call(from_key_state(l, g.keys[i])):
			return DeliverySolver.SOLVED
	return DeliverySolver.UNSOLVABLE

static func from_key_state(l: DeliveryLevel, k: PackedByteArray) -> DeliveryState:
	return DeliveryRules.from_key(l, k)

## Verifies one claim from the level data. Returns {ok, status, text}.
## Push claims ("every solution must make such a push") are checked by a
## search that forbids those pushes; position claims ("no solution passes
## such a position") against the exact distances of the complete graph.
static func verify_claim(l: DeliveryLevel, c: Dictionary) -> Dictionary:
	var sym := "ABCD".find(str(c.get("sym", "A")))
	var other := "ABCD".find(str(c.get("other", "A")))
	var name: String = DeliveryLevel.SYMBOL_IDS[sym]
	var st := DeliverySolver.TIMEOUT
	var text := ""
	match str(c.get("type", "")):
		"must_leave_pad":
			text = "every solution pushes a %s crate off its own pad at least once" % name
			st = constrained(l, func(b: DeliveryState, i: int, _d: int, a: DeliveryState) -> bool:
				return l.crate_sym[i] == sym and DeliveryRules.on_match(l, b, i) and not DeliveryRules.on_match(l, a, i), Callable())
		"must_move_away":
			var pd := DeliveryRules.push_distance(l, sym)
			text = "every solution pushes a %s crate farther from its pad at least once" % name
			st = constrained(l, func(b: DeliveryState, i: int, _d: int, a: DeliveryState) -> bool:
				return l.crate_sym[i] == sym and (pd[a.crates[i]] > pd[b.crates[i]] \
					or (DeliveryRules.on_match(l, b, i) and not DeliveryRules.on_match(l, a, i))), Callable())
		"before":
			text = "no solvable position has the %s crate(s) home while a %s crate is not" % [DeliveryLevel.SYMBOL_IDS[other], name]
			st = _no_solvable_state(l, func(s: DeliveryState) -> bool:
				return _all_home(l, s, other) and not _all_home(l, s, sym))
		"never_before":
			text = "no solvable position has the %s crate(s) home while another crate is not" % name
			st = _no_solvable_state(l, func(s: DeliveryState) -> bool:
				return _all_home(l, s, sym) and not _others_home(l, s, sym))
		_:
			text = "unknown claim " + str(c)
	return {"ok": st == DeliverySolver.UNSOLVABLE, "status": st, "text": text}

## Replays a design "mistake" (pushes from the start, walking as needed) and
## classifies the result. Returns {legal, code, text}; code is a
## DeliveryRules.Dead value, or -1 if the position is still solvable / unknown.
static func verify_mistake(l: DeliveryLevel, pushes: Array) -> Dictionary:
	var s := DeliveryRules.start_state(l)
	var pl: Array[Vector2i] = []
	for p in pushes:
		var d := DeliveryRules.DIR_IDS.find(str(p[3]))
		pl.append(Vector2i(int(p[2]) * l.w + int(p[1]), d))
	var mv := DeliverySolver.expand_pushes(l, s, pl)
	if mv.is_empty() and not pl.is_empty():
		return {"legal": false, "code": -1, "text": "not playable"}
	for d in mv:
		DeliveryRules.move(l, s, d)
	var dl := DeliveryRules.deadlock(l, s)
	if dl.code != DeliveryRules.Dead.NONE:
		var who := PackedStringArray()
		for i in dl.crates:
			who.append(DeliveryLevel.SYMBOL_IDS[l.crate_sym[int(i)]])
		return {"legal": true, "code": dl.code, "text": "instant %s (%s)" % ["DEAD_CELL" if dl.code == DeliveryRules.Dead.DEAD_CELL else "FROZEN", ", ".join(who)]}
	var sv := DeliverySolver.solve(l, s, 300000)
	if sv.status == DeliverySolver.UNSOLVABLE:
		return {"legal": true, "code": DeliveryRules.Dead.EXHAUSTIVE, "text": "exhaustive search (%d positions)" % sv.nodes()}
	if sv.status == DeliverySolver.SOLVED:
		return {"legal": true, "code": -1, "text": "still solvable (%d more pushes)" % sv.push_list.size()}
	return {"legal": true, "code": -1, "text": "unknown (timeout)"}
