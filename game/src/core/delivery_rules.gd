class_name DeliveryRules
extends RefCounted
## THE rules of Delivery Logic (spec: docs/DELIVERY_RULES.md). Gameplay,
## solver, hints, deadlock checks, tests and level tools all call this file;
## nothing else re-implements a rule.

enum { INVALID, STEP, PUSH }
enum Dir { UP, RIGHT, DOWN, LEFT }
const DIR_IDS := ["up", "right", "down", "left"]
const DELTA := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Deadlock codes (§5). EXHAUSTIVE comes from the solver, not from here.
enum Dead { NONE, DEAD_CELL, FROZEN, EXHAUSTIVE }

static func opposite(d: int) -> int:
	return (d + 2) % 4

static func start_state(level: DeliveryLevel) -> DeliveryState:
	return DeliveryState.make(level, level.start_player, level.start_crates)

# --------------------------------------------------------------- actions (§3)

## One step or push in direction `d`. Mutates `s` only when the action is
## valid; returns INVALID, STEP or PUSH.
static func move(level: DeliveryLevel, s: DeliveryState, d: int) -> int:
	if d < 0 or d > 3:
		return INVALID
	var t := level.nbr(s.player, d)
	if not level.floor_at(t):
		return INVALID
	var i := s.at[t]
	if i < 0:
		s.player = t
		s.steps += 1
		return STEP
	var u := level.nbr(t, d)
	if not level.floor_at(u) or s.at[u] >= 0:
		return INVALID
	s.at[t] = -1
	s.at[u] = i
	s.crates[i] = u
	s.player = t
	s.pushes += 1
	return PUSH

## Whether the action would be valid, without changing anything.
static func can_move(level: DeliveryLevel, s: DeliveryState, d: int) -> int:
	if d < 0 or d > 3:
		return INVALID
	var t := level.nbr(s.player, d)
	if not level.floor_at(t):
		return INVALID
	if s.at[t] < 0:
		return STEP
	var u := level.nbr(t, d)
	return PUSH if level.floor_at(u) and s.at[u] < 0 else INVALID

## Shortest crate-free walk to `target` as directions (§3.2); empty when the
## target is the courier's cell, not floor, holds a crate or can't be reached.
static func walk_path(level: DeliveryLevel, s: DeliveryState, target: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if target == s.player or not level.floor_at(target) or s.at[target] >= 0:
		return out
	var prev := PackedInt32Array()
	prev.resize(level.n)
	prev.fill(-1)
	var via := PackedInt32Array()
	via.resize(level.n)
	prev[s.player] = s.player
	var q := PackedInt32Array([s.player])
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if c == target:
			break
		for d in 4:
			var t := level.nbr(c, d)
			if t >= 0 and prev[t] < 0 and level.kind[t] == DeliveryLevel.FLOOR and s.at[t] < 0:
				prev[t] = c
				via[t] = d
				q.append(t)
	if prev[target] < 0:
		return out
	var c2 := target
	while c2 != s.player:
		out.append(via[c2])
		c2 = prev[c2]
	out.reverse()
	return out

## Applies a tap-walk. Returns the number of steps taken (0 = invalid).
static func walk(level: DeliveryLevel, s: DeliveryState, target: int) -> int:
	var path := walk_path(level, s, target)
	for d in path:
		move(level, s, d)
	return path.size()

# --------------------------------------------------------------- winning (§4)

static func on_match(level: DeliveryLevel, s: DeliveryState, i: int) -> bool:
	return level.goal[s.crates[i]] == level.crate_sym[i]

static func is_won(level: DeliveryLevel, s: DeliveryState) -> bool:
	for i in s.crates.size():
		if not on_match(level, s, i):
			return false
	return true

static func delivered_count(level: DeliveryLevel, s: DeliveryState) -> int:
	var k := 0
	for i in s.crates.size():
		if on_match(level, s, i):
			k += 1
	return k

# --------------------------------------------------------------- reachability

## Cells the courier can reach without pushing (1 = reachable).
static func reach(level: DeliveryLevel, s: DeliveryState) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(level.n)
	m[s.player] = 1
	var q := PackedInt32Array([s.player])
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		for d in 4:
			var t := level.nb[c * 4 + d]
			if t >= 0 and m[t] == 0 and level.kind[t] == DeliveryLevel.FLOOR and s.at[t] < 0:
				m[t] = 1
				q.append(t)
	return m

## Smallest reachable cell: two positions with the same crates and the same
## courier region are the same puzzle position.
static func norm_player(m: PackedByteArray) -> int:
	for c in m.size():
		if m[c] == 1:
			return c
	return -1

## Pushes available from here as Vector2i(crate index, direction).
static func pushes_from(level: DeliveryLevel, s: DeliveryState, m: PackedByteArray) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in s.crates.size():
		var c := s.crates[i]
		for d in 4:
			var p := level.nbr(c, opposite(d))
			var u := level.nbr(c, d)
			if p >= 0 and m[p] == 1 and level.floor_at(u) and s.at[u] < 0:
				out.append(Vector2i(i, d))
	return out

## Canonical position key: [courier region, crate cells sorted within each
## symbol]. Crates of one symbol are interchangeable, so their order is not
## part of the position.
static func key(level: DeliveryLevel, s: DeliveryState, m: PackedByteArray) -> PackedByteArray:
	var k := PackedByteArray([norm_player(m)])
	var i := 0
	var cnt := s.crates.size()
	while i < cnt:
		var j := i
		while j < cnt and level.crate_sym[j] == level.crate_sym[i]:
			j += 1
		var grp := s.crates.slice(i, j)
		grp.sort()
		for c in grp:
			k.append(c)
		i = j
	return k

## Rebuilds a position from a key (courier at the region's smallest cell).
static func from_key(level: DeliveryLevel, k: PackedByteArray) -> DeliveryState:
	var cells := PackedInt32Array()
	for idx in range(1, k.size()):
		cells.append(k[idx])
	return DeliveryState.make(level, k[0], cells)

# --------------------------------------------------------------- deadlocks (§5)

## Cells from which a crate of `sym` can still reach one of its destinations
## on an otherwise empty board (reverse pull search over the walls only).
static func live_cells(level: DeliveryLevel, sym: int) -> PackedByteArray:
	if level._live.size() == DeliveryLevel.SYMBOLS:
		return level._live[sym]
	level._live = []
	for s2 in DeliveryLevel.SYMBOLS:
		var m := PackedByteArray()
		m.resize(level.n)
		var q := PackedInt32Array()
		for c in level.n:
			if level.goal[c] == s2:
				m[c] = 1
				q.append(c)
		var head := 0
		while head < q.size():
			var c := q[head]
			head += 1
			# A crate reaches c by a push in direction d from p = c - d, with
			# the courier standing on p - d.
			for d in 4:
				var p := level.nbr(c, opposite(d))
				if not level.floor_at(p) or m[p] == 1:
					continue
				if level.floor_at(level.nbr(p, opposite(d))):
					m[p] = 1
					q.append(p)
		level._live.append(m)
	return level._live[sym]

static func is_live(level: DeliveryLevel, sym: int, c: int) -> bool:
	return c >= 0 and live_cells(level, sym)[c] == 1

static func _solid(level: DeliveryLevel, c: int) -> bool:
	return c < 0 or level.kind[c] != DeliveryLevel.FLOOR

## A crate that can never move again: blocked on both axes by walls, by two
## dead cells, or by crates that are themselves frozen (the crate under test
## counts as a wall while its neighbours are examined).
static func is_frozen(level: DeliveryLevel, s: DeliveryState, cell: int, treated: Dictionary = {}) -> bool:
	return _axis_blocked(level, s, cell, Dir.LEFT, Dir.RIGHT, treated) \
		and _axis_blocked(level, s, cell, Dir.UP, Dir.DOWN, treated)

static func _axis_blocked(level: DeliveryLevel, s: DeliveryState, cell: int, d1: int, d2: int, treated: Dictionary) -> bool:
	var a := level.nbr(cell, d1)
	var b := level.nbr(cell, d2)
	if _solid(level, a) or _solid(level, b) or treated.has(a) or treated.has(b):
		return true
	var sym := level.crate_sym[s.at[cell]]
	if not is_live(level, sym, a) and not is_live(level, sym, b):
		return true
	var t2 := treated.duplicate()
	t2[cell] = true
	if s.at[a] >= 0 and is_frozen(level, s, a, t2):
		return true
	if s.at[b] >= 0 and is_frozen(level, s, b, t2):
		return true
	return false

## Proven deadlock in this position: {code, crates: [indices]}; code NONE if
## none of the sound checks applies (which does NOT mean solvable).
static func deadlock(level: DeliveryLevel, s: DeliveryState) -> Dictionary:
	for i in s.crates.size():
		if not on_match(level, s, i) and not is_live(level, level.crate_sym[i], s.crates[i]):
			return {"code": Dead.DEAD_CELL, "crates": [i]}
	var frozen: Array = []
	for i in s.crates.size():
		if not on_match(level, s, i) and is_frozen(level, s, s.crates[i]):
			frozen.append(i)
	if not frozen.is_empty():
		return {"code": Dead.FROZEN, "crates": frozen}
	return {"code": Dead.NONE, "crates": []}

## Fast check after crate i was pushed: only that crate and its neighbours
## can have become dead or frozen.
static func push_creates_deadlock(level: DeliveryLevel, s: DeliveryState, i: int) -> bool:
	var c := s.crates[i]
	if not on_match(level, s, i) and not is_live(level, level.crate_sym[i], c):
		return true
	if not on_match(level, s, i) and is_frozen(level, s, c):
		return true
	for d in 4:
		var t := level.nbr(c, d)
		if t >= 0 and s.at[t] >= 0:
			var j := s.at[t]
			if not on_match(level, s, j) and is_frozen(level, s, t):
				return true
	# Sound but not complete (a frozen chain two crates away is missed); the
	# solver only uses this to prune, the full check is deadlock().
	return false

## Push distance (empty board) from every cell to the nearest destination of
## `sym`; -1 where unreachable. Used by hints and baseline agents only.
static func push_distance(level: DeliveryLevel, sym: int) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(level.n)
	dist.fill(-1)
	var q := PackedInt32Array()
	for c in level.n:
		if level.goal[c] == sym:
			dist[c] = 0
			q.append(c)
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		for d in 4:
			var p := level.nbr(c, opposite(d))
			if level.floor_at(p) and dist[p] < 0 and level.floor_at(level.nbr(p, opposite(d))):
				dist[p] = dist[c] + 1
				q.append(p)
	return dist
