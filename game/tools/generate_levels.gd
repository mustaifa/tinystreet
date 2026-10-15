extends SceneTree
## AUTHORING AID ONLY. Deterministically generates candidate levels, validates
## each with the real solver, and writes FIXED campaign/daily JSON files that
## ship with the game. The game never generates levels at runtime.
##
##   godot --headless --path game -s res://tools/generate_levels.gd -- campaign|daily [from] [to]
##
## Levels 1-3 are hand-authored tutorials (HAND below) and are copied verbatim.

const OUT := {"campaign": "res://data/levels/campaign.json", "daily": "res://data/levels/daily.json"}
const CANDIDATES := 14
const BUDGET := 150000

const HAND := [
	{"id": "c001", "counter": 3, "trays": 1,
	 "crates": [["coffee", "coffee"], ["coffee", "tea"]],
	 "orders": [[{"coffee": 3}], [{"tea": 1}]],
	 "meta": {"tutorial": "tut_tap", "par_counter": 1}},
	{"id": "c002", "counter": 4, "trays": 1,
	 "crates": [["tea", "coffee"], ["croissant", "coffee"], ["tea", "croissant"]],
	 "orders": [[{"coffee": 2}], [{"tea": 2}], [{"croissant": 2}]],
	 "meta": {"tutorial": "tut_counter", "par_counter": 2}},
	{"id": "c003", "counter": 3, "trays": 2,
	 "crates": [["coffee", "tea", "croissant"], ["tea", "coffee", "croissant"], ["croissant", "coffee", "tea"]],
	 "orders": [[{"coffee": 2, "tea": 1}], [{"croissant": 2}], [{"tea": 2, "croissant": 1}], [{"coffee": 1}]],
	 "meta": {"tutorial": "tut_priority", "par_counter": 2}},
]

## Tier parameters: [crates_min, crates_max, depth_min, depth_max, orders_min,
## orders_max, trays, counter, products, stage_max_items, two_stage_ratio,
## target_random_win_rate]
func tier_for(kind: String, n: int) -> Dictionary:
	if kind == "daily":
		var v := n % 3
		return _t(4 + v % 2, 5, 4, 5, 6, 8, 2 + int(v == 2), 3, 5, 4, 0.25 if v == 1 else 0.0, 0.25)
	if n <= 5:   return _t(3, 3, 2, 3, 3, 4, 2, 3, 3, 3, 0.0, 0.85)
	if n <= 10:  return _t(3, 4, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.6)
	if n <= 15:  return _t(4, 4, 3, 4, 5, 6, 2, 3, 4, 4, 0.0, 0.45)
	if n <= 22:  return _t(4, 5, 4, 4, 6, 7, 2, 3, 5, 4, 0.0, 0.35)
	if n <= 30:  return _t(5, 5, 4, 5, 6, 8, 2, 3, 5, 4, 0.0, 0.25)
	if n <= 33:  return _t(4, 4, 3, 4, 4, 5, 2, 3, 5, 3, 0.5, 0.5)   # two-stage intro
	if n <= 45:  return _t(4, 5, 4, 5, 5, 7, 2, 3, 6, 4, 0.4, 0.3)
	if n <= 52:  return _t(5, 5, 4, 5, 6, 8, 3, 3, 6, 4, 0.35, 0.22)
	return _t(5, 6, 5, 5, 7, 9, 3, 3, 6, 4, 0.4, 0.15)

func _t(cmin, cmax, dmin, dmax, omin, omax, trays, counter, products, smax, two, target) -> Dictionary:
	return {"cmin": cmin, "cmax": cmax, "dmin": dmin, "dmax": dmax, "omin": omin, "omax": omax,
		"trays": trays, "counter": counter, "products": products, "smax": smax, "two": two, "target": target}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[0] if args.size() > 0 else "campaign"
	var total := 60
	var from := int(args[1]) if args.size() > 1 else 1
	var to := int(args[2]) if args.size() > 2 else total
	var existing: Array = []
	if FileAccess.file_exists(OUT[kind]):
		existing = JSON.parse_string(FileAccess.get_file_as_string(OUT[kind])).levels
	var by_id := {}
	for l in existing:
		by_id[l.id] = l
	var sigs := {}
	for l in existing:
		var n := int(str(l.id).substr(1))
		if n < from or n > to:
			sigs[LevelValidator.signature(LevelDef.from_dict(l))] = true
	for n in range(from, to + 1):
		var t0 := Time.get_ticks_msec()
		var lvl: Dictionary
		if kind == "campaign" and n <= HAND.size():
			lvl = HAND[n - 1].duplicate(true)
			var r := LevelValidator.validate(lvl, BUDGET)
			assert(r.verdict == LevelValidator.PASSED, "hand level %d: %s" % [n, r.errors])
			lvl.meta.solution = r.path
			lvl.meta.metrics = r.metrics
		else:
			lvl = _best_candidate(kind, n, sigs)
		lvl.meta.verified = LevelValidator.PASSED
		lvl.meta.playtest = "AWAITING_HUMAN"
		lvl.meta.tier = _tier_name(kind, n)
		sigs[LevelValidator.signature(LevelDef.from_dict(lvl))] = true
		by_id[lvl.id] = lvl
		print("%s  win=%.2f  min_ctr=%d  par=%d  items=%d  nodes=%d  (%d ms)" % [lvl.id,
			lvl.meta.metrics.random_win_rate, lvl.meta.metrics.min_counter, lvl.meta.par_counter,
			lvl.meta.metrics.items, lvl.meta.metrics.solver_nodes, Time.get_ticks_msec() - t0])
		_write(kind, by_id)
	quit(0)

func _tier_name(kind: String, n: int) -> String:
	if kind == "daily": return "daily"
	if n <= 5: return "intro"
	if n <= 15: return "sequencing"
	if n <= 30: return "pressure"
	if n <= 45: return "two_stage"
	return "mastery"

func _best_candidate(kind: String, n: int, sigs: Dictionary) -> Dictionary:
	var p := tier_for(kind, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s-%d-v1" % [kind, n])
	var best: Dictionary = {}
	var best_score := INF
	var tries := 0
	var good := 0
	while good < CANDIDATES and tries < CANDIDATES * 12:
		tries += 1
		var cand := _make(kind, n, p, rng)
		var def := LevelDef.from_dict(cand)
		if LevelValidator.signature(def) in sigs:
			continue
		var r := LevelValidator.validate(cand, BUDGET)
		if r.verdict != LevelValidator.PASSED:
			continue
		var m: Dictionary = r.metrics
		if LevelValidator.is_trivial(m) and n > 3:
			continue
		if m.min_counter >= p.counter and n <= 15:
			continue # early levels keep at least one spare slot
		good += 1
		var score: float = absf(m.random_win_rate - p.target)
		score += 0.002 * absf(m.solver_nodes - 300)  * (1.0 if m.solver_nodes > 20000 else 0.0)
		if score < best_score:
			best_score = score
			cand.meta.solution = r.path
			cand.meta.metrics = m
			cand.meta.par_counter = mini(p.counter, m.min_counter + 1)
			best = cand
	assert(not best.is_empty(), "no valid candidate for %s %d" % [kind, n])
	return best

func _make(kind: String, n: int, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# Rotate the palette so successive levels feature different products.
	var rot := (n * 2) % Products.COUNT if p.products < Products.COUNT else 0
	var pal: Array = []
	for i in p.products:
		pal.append(Products.IDS[(i + rot) % Products.COUNT])
	var n_crates := rng.randi_range(p.cmin, p.cmax)
	var depths: Array = []
	var total := 0
	for i in n_crates:
		var d := rng.randi_range(p.dmin, p.dmax)
		depths.append(d)
		total += d
	# Build orders until their demand matches the item total exactly.
	var orders: Array = []
	var remaining := total
	var n_orders := rng.randi_range(p.omin, p.omax)
	for oi in n_orders:
		if remaining <= 0:
			break
		var orders_left := n_orders - oi
		var two: bool = rng.randf() < p.two and remaining >= 4
		var stages: Array = []
		for si in (2 if two else 1):
			var size := clampi(int(round(float(remaining) / float(maxi(1, orders_left)) / (2.0 if two else 1.0))) + rng.randi_range(-1, 1), 1, p.smax)
			if oi == n_orders - 1 and si == (1 if two else 0):
				size = remaining # last stage absorbs the remainder
			size = mini(size, remaining)
			if size <= 0:
				break
			stages.append(_stage(size, pal, rng))
			remaining -= size
		if not stages.is_empty():
			orders.append(stages)
	# Split any oversized final stage into extra orders.
	var fixed: Array = []
	for o in orders:
		var ok := true
		for st in o:
			var s := 0
			for k in st: s += int(st[k])
			if s > LevelValidator.LIMITS.stage_items_max: ok = false
		if ok:
			fixed.append(o)
		else:
			for st in o:
				var bag: Array = []
				for k in st:
					for j in int(st[k]): bag.append(k)
				while not bag.is_empty():
					var chunk := {}
					for j in mini(p.smax, bag.size()):
						var k2: String = bag.pop_back()
						chunk[k2] = int(chunk.get(k2, 0)) + 1
					fixed.append([chunk])
	# Supply = demand, shuffled into crates.
	var bag: Array = []
	for o in fixed:
		for st in o:
			for k in st:
				for j in int(st[k]):
					bag.append(k)
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = bag[i]; bag[i] = bag[j]; bag[j] = tmp
	var crates: Array = []
	var idx := 0
	for d in depths:
		var c: Array = []
		for j in d:
			c.append(bag[idx]); idx += 1
		crates.append(c)
	var prefix := "c" if kind == "campaign" else "d"
	return {"id": "%s%03d" % [prefix, n], "counter": p.counter, "trays": p.trays,
		"crates": crates, "orders": fixed, "meta": {}}

## A stage of `size` items using one or two distinct products (each >= 1).
func _stage(size: int, pal: Array, rng: RandomNumberGenerator) -> Dictionary:
	var kinds := 1 if size <= 2 or rng.randf() < 0.45 else 2
	var pick: Array = pal.duplicate()
	var st := {}
	for k in kinds:
		var pid: String = pick.pop_at(rng.randi_range(0, pick.size() - 1))
		st[pid] = 1
	var keys := st.keys()
	for k in size - kinds:
		var pid: String = keys[rng.randi_range(0, keys.size() - 1)]
		st[pid] += 1
	return st

func _write(kind: String, by_id: Dictionary) -> void:
	var ids := by_id.keys()
	ids.sort()
	var levels: Array = []
	for id in ids:
		levels.append(by_id[id])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/levels"))
	var f := FileAccess.open(OUT[kind], FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "kind": kind, "levels": levels}, "\t"))
	f.close()
