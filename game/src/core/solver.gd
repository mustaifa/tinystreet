class_name Solver
extends RefCounted
## Depth-first solver with a transposition table and an explicit node budget.
## Uses the real Rules, never a simplified copy.
##
## Result statuses:
##   SOLVED     - `path` is a list of crate taps that wins from the given state.
##   UNSOLVABLE - the entire reachable space was exhausted without a win.
##   TIMEOUT    - the node budget ran out; NOTHING is known. Never treat as pass/fail.

const SOLVED := "SOLVED"
const UNSOLVABLE := "UNSOLVABLE"
const TIMEOUT := "TIMEOUT"

var max_nodes: int = 200000
var nodes: int = 0
var _dead: Dictionary = {}
var _path: PackedInt32Array = PackedInt32Array()
var _timed_out := false

func _init(budget: int = 200000) -> void:
	max_nodes = budget

## Solves from `start` (not mutated). `counter_cap` >= 0 overrides capacity.
func solve(start: PuzzleState, counter_cap: int = -1) -> Dictionary:
	nodes = 0
	_dead.clear()
	_path = PackedInt32Array()
	_timed_out = false
	var s := start.copy()
	if counter_cap >= 0:
		var used := s.counter_used()
		if used > counter_cap:
			return {"status": UNSOLVABLE, "path": PackedInt32Array(), "nodes": 0}
		var compact := PackedInt32Array()
		for v in s.counter:
			if v >= 0:
				compact.append(v)
		while compact.size() < counter_cap:
			compact.append(-1)
		s.counter = compact
	var ok := _dfs(s)
	var status := SOLVED if ok else (TIMEOUT if _timed_out else UNSOLVABLE)
	return {"status": status, "path": _path.duplicate() if ok else PackedInt32Array(), "nodes": nodes}

func _dfs(s: PuzzleState) -> bool:
	if Rules.is_won(s):
		return true
	nodes += 1
	if nodes > max_nodes:
		_timed_out = true
		return false
	var k := s.key()
	if _dead.has(k):
		return false
	for c in _ordered_moves(s):
		var n := s.copy()
		Rules.apply_move(n, c)
		_path.append(c)
		if _dfs(n):
			return true
		_path.resize(_path.size() - 1)
		if _timed_out:
			return false
	_dead[k] = true
	return false

## Direct-to-tray moves first (they never consume counter space), then counter
## moves. Duplicate fronts with identical products are de-duplicated only when
## the crates' remaining contents are identical (pure symmetry).
func _ordered_moves(s: PuzzleState) -> PackedInt32Array:
	var direct := PackedInt32Array()
	var buffered := PackedInt32Array()
	for c in s.crate_pos.size():
		var pv := Rules.preview(s, c)
		if pv.dest == Rules.Dest.TRAY:
			direct.append(c)
		elif pv.dest == Rules.Dest.COUNTER:
			buffered.append(c)
	direct.append_array(buffered)
	return direct

## Smallest counter capacity (0..level capacity) that still admits a solution.
## Returns -1 if any probe timed out before a solution was found.
static func min_counter_needed(def: LevelDef, budget: int = 100000) -> int:
	var base := PuzzleState.create(def)
	for k in range(0, def.counter_slots + 1):
		var r := Solver.new(budget).solve(base, k)
		if r.status == SOLVED:
			return k
		if r.status == TIMEOUT:
			return -1
	return def.counter_slots + 1

## Replays a recorded path; returns true if it is legal and wins.
static func verify_path(def: LevelDef, path: PackedInt32Array) -> bool:
	var s := PuzzleState.create(def)
	for c in path:
		if Rules.apply_move(s, c).is_empty():
			return false
	return Rules.is_won(s)
