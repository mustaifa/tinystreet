class_name PuzzleSession
extends RefCounted
## One attempt at a level: current state, full-state undo history and the
## attempt-level counters used for scoring. Persistable as a move list.

var level: LevelDef
var state: PuzzleState
var history: Array = []          # Array[PuzzleState] snapshots before each move
var moves_log: PackedInt32Array = PackedInt32Array()
var undo_count: int = 0          # attempt-level; NOT restored by undo (by design)
var hints_used: int = 0
var continue_used: bool = false
var _continue_at: int = -1     # move index at which the continuation was granted

static func start(def: LevelDef) -> PuzzleSession:
	var ps := PuzzleSession.new()
	ps.level = def
	ps.state = PuzzleState.create(def)
	return ps

## Returns presentation events, or [] if illegal.
func tap(crate: int) -> Array:
	if is_finished():
		return []
	var snap := state.copy()
	var ev := Rules.apply_move(state, crate)
	if ev.is_empty():
		return []
	history.append(snap)
	moves_log.append(crate)
	return ev

func can_undo() -> bool:
	return not history.is_empty() and not Rules.is_won(state)

## Restores the ENTIRE prior state: crates, counter, trays, stage progress,
## queue position, deliveries, move count and peak counter (score effects).
func undo() -> bool:
	if not can_undo():
		return false
	state = history.pop_back()
	moves_log.resize(moves_log.size() - 1)
	undo_count += 1
	return true

func is_won() -> bool:
	return Rules.is_won(state)

func is_lost() -> bool:
	return Rules.is_lost(state)

func is_finished() -> bool:
	return is_won()

## Rewarded continuation: one temporary extra counter slot, max once per attempt.
## Applied to all snapshots so undo cannot remove it mid-attempt.
func can_continue() -> bool:
	return not continue_used and is_lost()

func grant_continue() -> bool:
	if continue_used:
		return false
	continue_used = true
	_continue_at = moves_log.size()
	Rules.add_bonus_slot(state)
	for h in history:
		Rules.add_bonus_slot(h)
	return true

## Hint computed from the CURRENT state (works after any route the player took).
## Returns {status, crate}. status: SOLVED (crate = suggested tap),
## UNSOLVABLE (suggest undo/restart), TIMEOUT (no claim made).
func compute_hint(budget: int = 20000) -> Dictionary:
	var r := Solver.new(budget).solve(state)
	var crate := -1
	if r.status == Solver.SOLVED and r.path.size() > 0:
		crate = r.path[0]
	return {"status": r.status, "crate": crate}

## How many undos are needed to reach a solvable state (searching back up to
## `max_back` snapshots). -1 if none found within budget.
func undos_to_solvable(max_back: int = 6, budget: int = 8000) -> int:
	for back in range(1, mini(max_back, history.size()) + 1):
		var snap: PuzzleState = history[history.size() - back]
		if Solver.new(budget).solve(snap).status == Solver.SOLVED:
			return back
	return -1

func stars() -> int:
	return Scoring.stars(level, state, undo_count, continue_used)

## Serialisable form. Replaying moves through the rules rebuilds the state and
## the undo history exactly; deterministic rules make this safe.
func to_dict() -> Dictionary:
	return {"level": level.id, "moves": Array(moves_log), "undos": undo_count,
		"hints": hints_used, "cont": continue_used,
		"cont_at": _continue_at}


static func restore(def: LevelDef, d: Dictionary) -> PuzzleSession:
	var ps := PuzzleSession.start(def)
	var cont_at := int(d.get("cont_at", -1))
	var mv: Array = d.get("moves", [])
	for i in mv.size():
		if i == cont_at and bool(d.get("cont", false)):
			ps.grant_continue()
		if ps.tap(int(mv[i])).is_empty():
			return null # incompatible with current level data
	if bool(d.get("cont", false)) and not ps.continue_used:
		ps.grant_continue()
	ps.undo_count = int(d.get("undos", 0))
	ps.hints_used = int(d.get("hints", 0))
	return ps
