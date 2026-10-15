class_name LevelValidator
extends RefCounted
## Schema + consistency + solvability checks for level definitions.
## Verdicts: PASSED, FAILED (with errors), UNVERIFIED (solver budget exhausted).

const PASSED := "PASSED"
const FAILED := "FAILED"
const UNVERIFIED := "UNVERIFIED"

const LIMITS := {
	"crates_min": 2, "crates_max": 7, "crate_depth_max": 7,
	"counter_min": 1, "counter_max": 6, "trays_min": 1, "trays_max": 3,
	"stage_items_max": 6, "stages_max": 2,
}

## Structural checks on the raw dictionary (before parsing).
static func schema_errors(d: Dictionary) -> Array:
	var e: Array = []
	if typeof(d.get("id")) != TYPE_STRING or str(d.id).is_empty():
		e.append("missing id")
	for k in ["crates", "orders"]:
		if typeof(d.get(k)) != TYPE_ARRAY:
			e.append("%s must be an array" % k)
	for k in ["counter", "trays"]:
		if not (typeof(d.get(k)) in [TYPE_INT, TYPE_FLOAT]):
			e.append("%s must be a number" % k)
	if not e.is_empty():
		return e
	var nc: int = d.crates.size()
	if nc < LIMITS.crates_min or nc > LIMITS.crates_max:
		e.append("crate count %d out of range" % nc)
	if int(d.counter) < LIMITS.counter_min or int(d.counter) > LIMITS.counter_max:
		e.append("counter %d out of range" % int(d.counter))
	if int(d.trays) < LIMITS.trays_min or int(d.trays) > LIMITS.trays_max:
		e.append("trays %d out of range" % int(d.trays))
	for c in d.crates:
		if typeof(c) != TYPE_ARRAY or c.is_empty() or c.size() > LIMITS.crate_depth_max:
			e.append("bad crate %s" % [c])
			continue
		for p in c:
			if Products.id_to_index(str(p)) < 0:
				e.append("unknown product '%s'" % p)
	if d.orders.is_empty():
		e.append("no orders")
	for o in d.orders:
		if typeof(o) != TYPE_ARRAY or o.is_empty() or o.size() > LIMITS.stages_max:
			e.append("bad order %s" % [o])
			continue
		for st in o:
			if typeof(st) != TYPE_DICTIONARY or st.is_empty():
				e.append("empty stage in order %s" % [o])
				continue
			var n := 0
			for k in st:
				if Products.id_to_index(str(k)) < 0:
					e.append("unknown product '%s' in order" % k)
				if int(st[k]) <= 0:
					e.append("non-positive quantity in order")
				n += int(st[k])
			if n > LIMITS.stage_items_max:
				e.append("stage too large (%d)" % n)
	return e

## Supply in crates must equal demand across all orders, per product.
static func quantity_errors(def: LevelDef) -> Array:
	var supply := PackedInt32Array(); supply.resize(Products.COUNT)
	var demand := PackedInt32Array(); demand.resize(Products.COUNT)
	for c in def.crates:
		for p in c:
			supply[p] += 1
	for o in def.orders:
		for st in o:
			for i in Products.COUNT:
				demand[i] += st[i]
	var e: Array = []
	for i in Products.COUNT:
		if supply[i] != demand[i]:
			e.append("%s: crates hold %d, orders need %d" % [Products.IDS[i], supply[i], demand[i]])
	return e

## Full validation. Returns {verdict, errors, path, metrics}.
static func validate(d: Dictionary, budget: int = 300000) -> Dictionary:
	var out := {"verdict": FAILED, "errors": [], "path": [], "metrics": {}}
	out.errors = schema_errors(d)
	if not out.errors.is_empty():
		return out
	var def := LevelDef.from_dict(d)
	out.errors = quantity_errors(def)
	if not out.errors.is_empty():
		return out
	# Recorded solution must replay; otherwise search.
	var rec: Array = def.meta.get("solution", [])
	if not rec.is_empty():
		if not Solver.verify_path(def, PackedInt32Array(rec)):
			out.errors.append("recorded solution does not replay to a win")
			return out
		out.path = rec
	else:
		var r := Solver.new(budget).solve(PuzzleState.create(def))
		if r.status == Solver.TIMEOUT:
			out.verdict = UNVERIFIED
			out.errors.append("solver budget exhausted (%d nodes)" % r.nodes)
			return out
		if r.status == Solver.UNSOLVABLE:
			out.errors.append("no solution exists")
			return out
		out.path = Array(r.path)
	out.metrics = metrics(def, budget)
	if int(out.metrics.min_counter) < 0:
		out.verdict = UNVERIFIED
		out.errors.append("min-counter analysis timed out")
		return out
	var par := int(def.meta.get("par_counter", -1))
	if par >= 0 and par < int(out.metrics.min_counter):
		out.errors.append("par_counter %d below achievable minimum %d" % [par, out.metrics.min_counter])
		return out
	out.verdict = PASSED
	return out

## Measurable difficulty proxies. None of these establish fun.
static func metrics(def: LevelDef, budget: int = 300000, playouts: int = 200) -> Dictionary:
	var m := {}
	m.items = def.total_items()
	m.crates = def.crates.size()
	m.orders = def.orders.size()
	m.two_stage = 0
	for o in def.orders:
		if o.size() > 1:
			m.two_stage += 1
	m.max_depth = 0
	for c in def.crates:
		m.max_depth = maxi(m.max_depth, c.size())
	m.min_counter = Solver.min_counter_needed(def, budget)
	m.slack = def.counter_slots - m.min_counter
	var r := Solver.new(budget).solve(PuzzleState.create(def))
	m.solver_nodes = r.nodes
	m.random_win_rate = random_win_rate(def, playouts, 12345)
	return m

## Fraction of uniformly random legal playouts that win (seeded, deterministic).
static func random_win_rate(def: LevelDef, n: int, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wins := 0
	for i in n:
		var s := PuzzleState.create(def)
		while true:
			var lm := Rules.legal_moves(s)
			if lm.is_empty():
				break
			Rules.apply_move(s, lm[rng.randi_range(0, lm.size() - 1)])
		if Rules.is_won(s):
			wins += 1
	return float(wins) / float(n)

## Canonical signature for duplicate detection (crate order is irrelevant).
static func signature(def: LevelDef) -> String:
	var cs: Array = []
	for c in def.crates:
		cs.append(str(c))
	cs.sort()
	return "%s#%s#%d#%d" % [",".join(cs), str(def.orders), def.counter_slots, def.trays]

## A layout is trivial if every random playout wins AND no counter is needed.
static func is_trivial(m: Dictionary) -> bool:
	return float(m.get("random_win_rate", 0.0)) >= 0.999 and int(m.get("min_counter", 1)) == 0
