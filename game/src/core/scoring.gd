class_name Scoring
extends RefCounted
## Transparent star rules (shown in the pause and win screens):
##   ★1  Complete the level.
##   ★2  Keep peak counter use at or below the level's "tidy counter" target
##       (meta.par_counter = solver's minimum possible peak + slack).
##   ★3  ★2, plus at most 1 undo and no extra-slot continuation.
## Hints never affect stars. Restarting begins a fresh attempt.

const MAX_UNDOS_FOR_3 := 1

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
