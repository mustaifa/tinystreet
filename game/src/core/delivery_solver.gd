class_name DeliverySolver
extends RefCounted
## Breadth-first search over push positions (DeliveryRules.key: crates plus
## courier region), so the first solution found uses the fewest pushes.
## Positions that DeliveryRules proves dead are not expanded; that never
## removes a solution, so an exhausted search is a proof of UNSOLVABLE.
##
## Incremental: step(budget) expands at most `budget` positions, so the game
## can spread a search over frames without threads (works on the web build).
## Hitting max_nodes gives TIMEOUT, which is never reported as "no solution".

enum { RUNNING, SOLVED, UNSOLVABLE, TIMEOUT }

var level: DeliveryLevel
var max_nodes := 200000
var status := RUNNING
var push_list: Array[Vector2i] = []   # (crate cell, direction) from the start position
var expanded := 0

var _start: DeliveryState
var _keys: Array[PackedByteArray] = []
var _parent := PackedInt32Array()
var _via := PackedInt32Array()          # crate cell * 4 + direction
var _seen := {}
var _head := 0

func _init(l: DeliveryLevel, from: DeliveryState, budget_nodes: int = 200000) -> void:
	level = l
	max_nodes = budget_nodes
	_start = from.copy()
	if DeliveryRules.is_won(level, _start):
		status = SOLVED
		return
	if DeliveryRules.deadlock(level, _start).code != DeliveryRules.Dead.NONE:
		status = UNSOLVABLE
		return
	var k := DeliveryRules.key(level, _start, DeliveryRules.reach(level, _start))
	_add(k, -1, -1)

func _add(k: PackedByteArray, parent: int, via: int) -> int:
	_seen[k] = _keys.size()
	_keys.append(k)
	_parent.append(parent)
	_via.append(via)
	return _keys.size() - 1

## Expands up to `budget` positions. Returns the status.
func step(budget: int) -> int:
	while status == RUNNING and budget > 0:
		if _head >= _keys.size():
			status = UNSOLVABLE
			break
		if _keys.size() >= max_nodes:
			status = TIMEOUT
			break
		budget -= 1
		_expand(_head)
		_head += 1
	return status

## Runs to completion (tests, tools, tiny searches).
func run() -> int:
	while status == RUNNING:
		step(4096)
	return status

func _expand(idx: int) -> void:
	expanded += 1
	var s := DeliveryRules.from_key(level, _keys[idx])
	var m := DeliveryRules.reach(level, s)
	for pv in DeliveryRules.pushes_from(level, s, m):
		var i := pv.x
		var d := pv.y
		var from_cell := s.crates[i]
		var t := s.copy()
		t.player = level.nbr(from_cell, DeliveryRules.opposite(d))
		DeliveryRules.move(level, t, d)
		if DeliveryRules.push_creates_deadlock(level, t, i):
			continue
		var k := DeliveryRules.key(level, t, DeliveryRules.reach(level, t))
		if _seen.has(k):
			continue
		var ni := _add(k, idx, from_cell * 4 + d)
		if DeliveryRules.is_won(level, t):
			status = SOLVED
			_trace(ni)
			return

func _trace(idx: int) -> void:
	push_list.clear()
	var i := idx
	while _parent[i] >= 0:
		push_list.append(Vector2i(_via[i] / 4, _via[i] % 4))
		i = _parent[i]
	push_list.reverse()

func nodes() -> int:
	return _keys.size()

## The full action list (steps and pushes as directions) that plays the
## solution from the start position, or empty if not solved / not replayable.
func moves() -> PackedInt32Array:
	return expand_pushes(level, _start, push_list)

## Turns a push list into directions by walking to each push. Returns empty
## if any push is not playable from the given position.
static func expand_pushes(l: DeliveryLevel, from: DeliveryState, pl: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	var s := from.copy()
	for pv in pl:
		var stand := l.nbr(pv.x, DeliveryRules.opposite(pv.y))
		if s.player != stand:
			var path := DeliveryRules.walk_path(l, s, stand)
			if path.is_empty():
				return PackedInt32Array()
			for d in path:
				DeliveryRules.move(l, s, d)
				out.append(d)
		if s.at[pv.x] < 0 or DeliveryRules.move(l, s, pv.y) != DeliveryRules.PUSH:
			return PackedInt32Array()
		out.append(pv.y)
	return out

## Replays `moves` through the real rules from `from`. True only if every
## action is valid and the final position is solved.
static func validate(l: DeliveryLevel, from: DeliveryState, mv: PackedInt32Array) -> bool:
	var s := from.copy()
	for d in mv:
		if DeliveryRules.move(l, s, d) == DeliveryRules.INVALID:
			return false
	return DeliveryRules.is_won(l, s)

## Convenience: blocking solve from a position.
static func solve(l: DeliveryLevel, from: DeliveryState, budget_nodes: int = 200000) -> DeliverySolver:
	var sv := DeliverySolver.new(l, from, budget_nodes)
	sv.run()
	return sv
