class_name LedgerAnalysis
extends RefCounted
## Evidence for expert ("Midnight Ledger") puzzles, computed with the real
## Rules and Solver. Development tooling and tests use this; the phone only
## runs the bounded hint search.
##
## Status words follow the solver: SOLVED (proven by a witness), UNSOLVABLE
## (exhaustive search found nothing), TIMEOUT (budget exhausted: UNKNOWN).

const BUDGET := 400000

## Every action available from s: legal crate taps and legal bell rings.
static func actions(s: PuzzleState) -> PackedInt32Array:
	var out := Rules.legal_moves(s)
	for t in s.tray_order.size():
		if Rules.can_ring(s, t):
			out.append(Rules.bell_action(t))
	return out

## What kind of action `a` is from s (for describing traps).
static func kind(s: PuzzleState, a: int) -> String:
	if a < 0:
		return "ring"
	var pv := Rules.preview(s, a)
	if pv.dest == Rules.Dest.COUNTER:
		return "to_counter"
	var n := s.copy()
	for e in Rules.apply_move(n, a):
		if e.type == Rules.EV_DELIVER:
			return "completes"
	return "to_tray"

static func status(s: PuzzleState, budget: int = BUDGET) -> String:
	return Solver.new(budget).solve(s).status

## Smallest bell budget that admits a solution, with proof status.
## {min: int, proved: bool}. proved = every smaller budget is UNSOLVABLE.
static func min_rings(def: LevelDef, cap: int = 4, budget: int = BUDGET) -> Dictionary:
	if not def.allow_bell:
		return {"min": 0, "proved": status(PuzzleState.create(def), budget) == Solver.SOLVED}
	var top := cap if def.bell_budget < 0 else mini(cap, def.bell_budget)
	var proved := true
	for k in range(0, top + 1):
		var r := Solver.new(budget).solve(PuzzleState.create(def.with_budget(k)))
		if r.status == Solver.SOLVED:
			return {"min": k, "proved": proved}
		if r.status == Solver.TIMEOUT:
			proved = false
	return {"min": -1, "proved": false}

## Walks the witness and classifies every alternative at every step.
## Returns {ok, steps: [{step, action, kind, alternatives: [{action, kind, status}]}],
##          choice_points, traps, trap_kinds, unknown}.
static func trace(def: LevelDef, witness: PackedInt32Array, budget: int = BUDGET) -> Dictionary:
	var s := PuzzleState.create(def)
	var steps: Array = []
	var choice_points := 0
	var traps := 0
	var unknown := 0
	var kinds := {}
	for i in witness.size():
		var a := witness[i]
		var alts: Array = []
		var good := 0
		var bad := 0
		for b in actions(s):
			if b == a:
				good += 1
				continue
			var n := s.copy()
			var serves: Array = []
			for e in Rules.apply_action(n, b):
				if e.type == Rules.EV_DELIVER:
					serves.append(e.order)
			var st := status(n, budget)
			var k := kind(s, b)
			alts.append({"action": b, "kind": k, "status": st, "serves": serves})
			if st == Solver.UNSOLVABLE:
				bad += 1
				traps += 1
				kinds[k] = int(kinds.get(k, 0)) + 1
			elif st == Solver.SOLVED:
				good += 1
			else:
				unknown += 1
		if bad > 0 and good > 0:
			choice_points += 1
		steps.append({"step": i, "action": a, "kind": kind(s, a), "alternatives": alts})
		if Rules.apply_action(s, a).is_empty():
			return {"ok": false, "error": "witness action %d illegal at step %d" % [a, i]}
	return {"ok": Rules.is_won(s), "steps": steps, "choice_points": choice_points, "traps": traps,
		"trap_kinds": kinds, "unknown": unknown}

## Replays a witness through the gameplay rules and checks every constraint:
## each action legal (budget and sequence enforced by Rules), sequence order
## of actual deliveries, ring count within budget, and a terminal win.
static func replay(def: LevelDef, witness: PackedInt32Array) -> Dictionary:
	var ps := PuzzleSession.start(def)
	var delivered: Array = []
	for a in witness:
		var ev: Array = ps.tap(a) if a >= 0 else ps.ring(Rules.action_tray(a))
		if ev.is_empty():
			return {"ok": false, "error": "illegal action %d" % a}
		for e in ev:
			if e.type == Rules.EV_DELIVER:
				delivered.append(e.order)
	var seq_ok := true
	var last := -1
	for o in def.sequence:
		var at := delivered.find(o)
		if at < 0 or at < last:
			seq_ok = false
		last = at
	var rings := 0
	for a in witness:
		if a < 0:
			rings += 1
	var budget_ok := def.bell_budget < 0 or rings <= def.bell_budget
	return {"ok": ps.is_won() and seq_ok and budget_ok, "won": ps.is_won(), "sequence_ok": seq_ok,
		"budget_ok": budget_ok, "rings": rings, "actions": witness.size(), "delivered": delivered}

## Plain exhaustive search with no pruning, ordering or memory. Only for tiny
## boards: used by tests to cross-check the optimised solver.
static func reference_solvable(s: PuzzleState, depth: int = 0) -> bool:
	if Rules.is_won(s):
		return true
	if depth > 40:
		return false
	for a in actions(s):
		# a ring straight after a ring is still explored here (no pruning),
		# but bounded by the bell budget and the depth limit
		var n := s.copy()
		Rules.apply_action(n, a)
		if reference_solvable(n, depth + 1):
			return true
	return false

## Checks that a page really exhibits its stated reasoning idea, using the
## trace (proven dead ends) and proofs. Returns {ok, evidence}.
##   bell_timing       min rings >= 1 (proved) and some ring is a proven dead end
##   backward          the sequence makes a later-arriving order go first, and
##                     a non-bell move is a proven dead end
##   precision         budget > proven minimum rings (the target is meaningful)
##   empty_space       one counter space, and parking an item there is a dead end
##   delay_completion  completing some order is a proven dead end
##   ring_late         the witness rings only after step 2, and an earlier
##                     ring is a proven dead end
##   local_good        completing an order that ISN'T in the sequence is a dead end
##   min_rings         at least 2 rings are proven necessary
##   fresh / lock      the mechanic is present and a non-bell dead end exists
##   combine           at least two different kinds of non-bell dead ends
static func verify_idea(def: LevelDef, witness: PackedInt32Array, tr: Dictionary, mr: Dictionary, tag: String) -> Dictionary:
	var dead: Array = []
	var first_ring := -1
	for st in tr.steps:
		for x in st.alternatives:
			if x.status == Solver.UNSOLVABLE:
				var y: Dictionary = x.duplicate()
				y["step"] = st.step
				dead.append(y)
		if first_ring < 0 and int(st.action) < 0:
			first_ring = st.step
	var nonbell := dead.filter(func(x): return x.kind != "ring")
	var kinds := {}
	for x in nonbell:
		kinds[x.kind] = true
	var ok := false
	var ev := ""
	match tag:
		"bell_timing":
			var rings := dead.filter(func(x): return x.kind == "ring")
			ok = mr.proved and int(mr.min) >= 1 and not rings.is_empty()
			ev = "min rings %d proved; %d ring dead ends" % [mr.min, rings.size()]
		"backward":
			var later_first := false
			for i in def.sequence.size():
				for j in range(i + 1, def.sequence.size()):
					if def.sequence[i] > def.sequence[j]:
						later_first = true
			ok = later_first and not nonbell.is_empty()
			ev = "sequence %s puts a later arrival first; %d non-bell dead ends" % [Array(def.sequence), nonbell.size()]
		"precision":
			ok = mr.proved and (def.bell_budget < 0 or def.bell_budget > int(mr.min))
			ev = "budget %d > proven minimum %d" % [def.bell_budget, mr.min]
		"empty_space":
			var c := nonbell.filter(func(x): return x.kind == "to_counter")
			ok = def.counter_slots == 1 and not c.is_empty()
			ev = "1 counter space; %d counter dead ends" % c.size()
		"delay_completion":
			var c2 := nonbell.filter(func(x): return x.kind == "completes")
			ok = not c2.is_empty()
			ev = "%d premature completions are dead ends" % c2.size()
		"ring_late":
			var early := dead.filter(func(x): return x.kind == "ring" and x.step < first_ring)
			ok = first_ring >= 2 and not early.is_empty()
			ev = "witness rings at step %d; %d earlier rings are dead ends" % [first_ring, early.size()]
		"local_good":
			var c3 := nonbell.filter(func(x): return x.kind == "completes" and x.serves.any(func(o): return not (o in def.sequence)))
			ok = not c3.is_empty()
			ev = "%d completions of orders outside the sequence are dead ends" % c3.size()
		"min_rings":
			ok = mr.proved and int(mr.min) >= 2
			ev = "minimum %d rings proved" % mr.min
		"fresh":
			ok = def.count_flag(LevelDef.FRESH) > 0 and not nonbell.is_empty()
			ev = "%d fresh items; %d non-bell dead ends" % [def.count_flag(LevelDef.FRESH), nonbell.size()]
		"lock":
			ok = def.has_locks() and not nonbell.is_empty() and int(LevelValidator.mechanic_engagement(def, witness).lock_moves) > 0
			ev = "strapped crate matters for %d moves; %d non-bell dead ends" % [LevelValidator.mechanic_engagement(def, witness).lock_moves, nonbell.size()]
		"combine":
			ok = kinds.size() >= 2
			ev = "non-bell dead-end kinds: %s" % [kinds.keys()]
	return {"ok": ok, "evidence": ev}
