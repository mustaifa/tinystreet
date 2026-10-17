class_name Scoring
extends RefCounted
## Transparent star rules (shown in the pause and win screens):
##   ★1  Complete the level.
##   ★2  Keep peak counter use at or below the level's "tidy counter" target
##       (meta.par_counter = solver's minimum possible peak + slack).
##   ★3  ★2, plus at most 1 undo and no extra-slot continuation.
## Hints never affect stars. Restarting begins a fresh attempt.
##
## POINTS (v7): a live score, separate from stars and tokens. Derived only
## from the puzzle state, so undo, redo, restart and reloading a saved
## attempt always give the same number as the board shows:
##   +10  per item served straight from a crate to an order
##   +5   per item that reached an order from the counter
##   +25  per order delivered
##   +10  on completion, per base counter space never used (tidy bonus)
## Taps, bell rings, undos and hints earn nothing by themselves.

const MAX_UNDOS_FOR_3 := 1
const PTS_DIRECT := 10
const PTS_VIA_COUNTER := 5
const PTS_ORDER := 25
const PTS_SPARE_SPACE := 10

static func par_counter(level: LevelDef) -> int:
	return int(level.meta.get("par_counter", level.counter_slots))

static func stars(level: LevelDef, s: PuzzleState, undos: int, continued: bool) -> int:
	if not Rules.is_won(s):
		return 0
	var n := 1
	if s.peak_counter <= par_counter(level):
		n = 2
		if undos <= MAX_UNDOS_FOR_3 and not continued:
			n = 3
	return n

## Counter spaces (of the level's own, not a bonus slot) never used.
static func spare_spaces(s: PuzzleState) -> int:
	return maxi(0, s.level.counter_slots - s.peak_counter)

static func tidy_bonus(s: PuzzleState) -> int:
	return PTS_SPARE_SPACE * spare_spaces(s) if Rules.is_won(s) else 0

static func points(s: PuzzleState) -> int:
	return PTS_DIRECT * s.served_direct + PTS_VIA_COUNTER * s.served_counter \
		+ PTS_ORDER * s.completed + tidy_bonus(s)

## The parts of points(s), for the result card.
static func breakdown(s: PuzzleState) -> Dictionary:
	return {"direct": s.served_direct, "via_counter": s.served_counter, "orders": s.completed,
		"spare": spare_spaces(s) if Rules.is_won(s) else 0, "tidy": tidy_bonus(s), "total": points(s)}
