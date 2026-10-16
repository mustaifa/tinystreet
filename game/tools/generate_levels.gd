extends SceneTree
## AUTHORING AID ONLY. Deterministically generates candidate levels, validates
## each with the real solver, and writes FIXED campaign/daily JSON files that
## ship with the game. The game never generates levels at runtime.
##
##   godot --headless --path game -s res://tools/generate_levels.gd -- campaign|daily [from] [to]
##   godot --headless --path game -s res://tools/generate_levels.gd -- ids f01 b02 c025 ...
##   godot --headless --path game -s res://tools/generate_levels.gd -- order   # rewrite file order/chapters only
##
## Tutorial levels (HAND below) are hand-authored and copied verbatim.
## The campaign file lists levels in PLAY ORDER (ORDER below) with chapters.
## v2 mechanic levels: fNN fresh items, bNN paper bags, kNN delivery locks,
## xNN mixed. Candidates must PASS validation AND exercise their mechanic on
## the solution line (LevelValidator.mechanic_engagement).

const OUT := {"campaign": "res://data/levels/campaign.json", "daily": "res://data/levels/daily.json",
	"bakery": "res://data/levels/bakery.json"}
## v3 second destination: Mira's Bakery (separate file, unlocked in play).
const BAKERY_ORDER := ["m01", "m02", "m03", "m04", "m05", "m06", "m07", "m08"]
const PASTRIES := ["croissant", "cupcake", "strawberry", "chocolate"]
const CANDIDATES := 14
const BUDGET := 150000

## Campaign play order. Existing v1 ids keep their content (saves refer to
## them); v2 levels are interleaved so each mechanic is introduced gently.
const ORDER := [
	"c001", "c002", "c003", "c004", "c005", "c006", "f01", "c007",
	"p01", "p02", "p03", "p04", "p05", "p06", "p07", "p08", "p09", "p10", "p11", "p12",
	"c008", "f02", "c009", "c010", "f03", "c011", "c012", "f04", "c013", "c014", "f05", "c015",
	"c016", "b01", "c017", "c018", "b02", "c019", "c020", "b03", "c021", "c022", "b04", "c023", "c024", "c025", "b05", "c026", "c027", "c028", "c029", "c030",
	"c031", "c032", "c033", "f06", "c034", "c035", "b06", "c036", "c037", "c038", "c039", "c040", "c041", "c042", "c043", "c044", "c045",
	"k01", "c046", "k02", "c047", "c048", "k03", "c049", "c050", "k04", "c051", "k05", "c052", "k06",
	"c053", "x01", "c054", "c055", "x02", "c056", "c057", "x03", "c058", "x04", "c059", "x05", "c060", "x06",
]
## [chapter title key, first level id]
const CHAPTERS := [["ch_intro", "c001"], ["ch_bell", "p01"], ["ch_sequencing", "c008"], ["ch_pressure", "c016"],
	["ch_two_stage", "c031"], ["ch_locks", "k01"], ["ch_mastery", "c053"]]
## Extra tutorial keys attached to generated levels.
const TUTORIAL_META := {"c031": "tut_two_stage"}
## v3 special orders: the 3-part order at index 1, who places it, and the
## one-time reward for solving the level (see Specials in src/meta).
const SPECIALS := {
	"p06": {"order": 1, "customer": "theo", "title": "special_p06", "reward": "extra:chalkboard"},
	"p12": {"order": 1, "customer": "mira", "title": "special_p12", "reward": "unlock:bakery"},
	"m08": {"order": 1, "customer": "basil", "title": "special_m08", "reward": "extra:breadbasket"},
}
## v3: the bell is introduced at p01; levels before it don't offer it.
const NO_BELL := ["c001", "c002", "c003", "c004", "c005", "c006", "f01", "c007"]

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
	# Fresh items: hot coffee cannot wait on the counter. Serve the tea first.
	{"id": "f01", "counter": 3, "trays": 1,
	 "crates": [["tea", "coffee!"], ["coffee!", "tea"], ["tea", "croissant"]],
	 "orders": [[{"tea": 2}], [{"coffee": 2}], [{"tea": 1}], [{"croissant": 1}]],
	 "meta": {"tutorial": "tut_fresh", "par_counter": 1}},
	# Paper bags: contents stay hidden until they reach the front.
	{"id": "b01", "counter": 3, "trays": 1,
	 "crates": [["coffee", "?tea", "?coffee"], ["tea", "?croissant"], ["croissant", "?tea"]],
	 "orders": [[{"coffee": 1}], [{"tea": 2}], [{"croissant": 2}], [{"tea": 1, "coffee": 1}]],
	 "meta": {"tutorial": "tut_bag", "par_counter": 2}},
	# v3 bell tutorial: two coffee customers; serving ticket 2 first brings the
	# tea customer for the tea waiting on the counter. Proven impossible
	# without the bell (LevelValidator.bell_value == "required").
	{"id": "p01", "counter": 1, "trays": 2,
	 "crates": [["tea", "coffee", "coffee"], ["tea", "coffee", "coffee"]],
	 "orders": [[{"coffee": 1}], [{"coffee": 1}], [{"coffee": 2}], [{"tea": 2}]],
	 "meta": {"tutorial": "tut_bell", "par_counter": 1}},
	# Bakery tutorial: the oven (a locked crate of hot pastries) opens after
	# the first order; hot pastries must go straight to a ticket.
	{"id": "m01", "counter": 3, "trays": 2, "locks": [0, 0, 1],
	 "crates": [["cupcake", "strawberry"], ["strawberry", "cupcake"], ["croissant!", "croissant!"]],
	 "orders": [[{"cupcake": 1, "strawberry": 1}], [{"croissant": 2}], [{"strawberry": 1, "cupcake": 1}]],
	 "meta": {"tutorial": "tut_oven", "par_counter": 1}},
	# Delivery locks: the croissant crate opens after two deliveries.
	{"id": "k01", "counter": 3, "trays": 1, "locks": [0, 0, 2],
	 "crates": [["coffee", "tea"], ["tea", "coffee"], ["croissant", "croissant"]],
	 "orders": [[{"coffee": 1}], [{"tea": 2}], [{"croissant": 2}], [{"coffee": 1}]],
	 "meta": {"tutorial": "tut_lock", "par_counter": 1}},
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
		"trays": trays, "counter": counter, "products": products, "smax": smax, "two": two, "target": target,
		"fresh": 0.0, "bags": 0.0, "locks": 0}

## Mechanic levels: a base tier plus mechanic densities.
##   fresh = chance an item is fresh; bags = chance a non-front item is bagged;
##   locks = number of locked crates.
func mech_tier(id: String) -> Dictionary:
	var n := int(id.substr(1))
	var p: Dictionary
	match id[0]:
		"f":
			p = [_t(3, 3, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.6), _t(3, 4, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.5),
				_t(4, 4, 3, 4, 5, 6, 2, 3, 4, 4, 0.0, 0.45), _t(4, 4, 3, 4, 5, 6, 2, 3, 5, 4, 0.0, 0.4),
				_t(4, 5, 4, 4, 5, 6, 2, 3, 5, 3, 0.4, 0.35)][clampi(n - 2, 0, 4)]
			p.fresh = [0.18, 0.2, 0.22, 0.24, 0.2][clampi(n - 2, 0, 4)]
		"b":
			p = [_t(4, 4, 3, 4, 5, 6, 2, 3, 4, 4, 0.0, 0.5), _t(4, 5, 4, 4, 6, 7, 2, 3, 5, 4, 0.0, 0.4),
				_t(4, 5, 4, 4, 6, 7, 2, 3, 5, 4, 0.0, 0.35), _t(5, 5, 4, 4, 6, 8, 2, 3, 5, 4, 0.0, 0.3),
				_t(4, 5, 4, 5, 5, 7, 2, 3, 6, 4, 0.4, 0.3)][clampi(n - 2, 0, 4)]
			p.bags = [0.35, 0.4, 0.45, 0.5, 0.45][clampi(n - 2, 0, 4)]
		"k":
			p = [_t(4, 4, 3, 4, 5, 6, 2, 3, 5, 4, 0.2, 0.4), _t(4, 5, 4, 4, 5, 7, 2, 3, 5, 4, 0.3, 0.35),
				_t(5, 5, 4, 4, 6, 7, 3, 3, 6, 4, 0.3, 0.3), _t(5, 5, 4, 5, 6, 8, 3, 3, 6, 4, 0.35, 0.25),
				_t(5, 5, 4, 5, 6, 8, 3, 3, 6, 4, 0.35, 0.22)][clampi(n - 2, 0, 4)]
			p.locks = 1 if n <= 3 else 2
		"p":
			# v3 slice. need: what the bell must add (proven by search):
			#   required = unsolvable without it; decision = required or tidier;
			#   any = relaxed breathing level.
			var T := {
				2: [_t(3, 3, 3, 3, 4, 5, 2, 2, 3, 3, 0.0, 0.5), "decision", 0.0, false],
				3: [_t(3, 4, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.55), "any", 0.0, false],
				4: [_t(4, 4, 3, 4, 5, 6, 2, 2, 4, 3, 0.0, 0.35), "required", 0.0, false],
				5: [_t(4, 4, 3, 4, 5, 6, 2, 3, 4, 3, 0.0, 0.4), "decision", 0.2, false],
				6: [_t(4, 5, 4, 4, 6, 7, 2, 3, 4, 4, 0.0, 0.4), "any", 0.0, true],
				7: [_t(3, 4, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.6), "any", 0.0, false],
				8: [_t(4, 4, 3, 4, 6, 7, 3, 3, 5, 3, 0.0, 0.35), "decision", 0.0, false],
				9: [_t(4, 5, 4, 4, 6, 7, 2, 2, 5, 3, 0.0, 0.3), "required", 0.2, false],
				10: [_t(4, 4, 3, 3, 5, 6, 2, 3, 4, 3, 0.0, 0.55), "any", 0.15, false],
				11: [_t(4, 5, 4, 4, 6, 7, 2, 2, 5, 4, 0.0, 0.25), "required", 0.15, false],
				12: [_t(5, 5, 4, 4, 7, 8, 2, 3, 5, 4, 0.0, 0.3), "decision", 0.1, true],
			}
			var e: Array = T[clampi(n, 2, 12)]
			p = e[0]
			p.need = e[1]
			p.fresh = e[2]
			p.special = e[3]
		"m":
			# Mira's Bakery: pastries only; "oven batches" = a locked crate
			# (drawn as an oven) and plenty of hot (fresh) pastries; bell on.
			var B := {
				2: [_t(3, 3, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.6), "any", 0.3, 1],
				3: [_t(3, 4, 3, 3, 4, 5, 2, 3, 4, 3, 0.0, 0.5), "decision", 0.3, 1],
				4: [_t(4, 4, 3, 4, 5, 6, 2, 3, 4, 3, 0.0, 0.5), "any", 0.35, 1],
				5: [_t(4, 4, 3, 4, 5, 6, 2, 2, 4, 3, 0.0, 0.35), "required", 0.3, 1],
				6: [_t(4, 5, 4, 4, 5, 7, 2, 3, 4, 4, 0.0, 0.45), "any", 0.35, 1],
				7: [_t(4, 5, 4, 4, 6, 7, 2, 3, 4, 4, 0.0, 0.3), "decision", 0.3, 2],
				8: [_t(5, 5, 4, 4, 6, 8, 2, 3, 4, 4, 0.0, 0.3), "decision", 0.3, 1],
			}
			var e2: Array = B[clampi(n, 2, 8)]
			p = e2[0]
			p.need = e2[1]
			p.fresh = e2[2]
			p.locks = e2[3]
			p.palette = PASTRIES
			p.special = n == 8
		"x":
			p = _t(5, 5, 4, 5, 6, 8, 3, 3, 6, 4, 0.35, [0.3, 0.25, 0.22, 0.2, 0.18, 0.16][clampi(n - 1, 0, 5)])
			p.fresh = 0.12 if n % 2 == 1 or n >= 5 else 0.0
			p.bags = 0.3 if n % 2 == 0 or n >= 5 else 0.0
			p.locks = 1 if n >= 3 else 0
	return p

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[0] if args.size() > 0 else "campaign"
	var ids: Array = []
	if kind == "ids" or kind == "order":
		for i in range(1, args.size()):
			ids.append(args[i])
		kind = "campaign" if kind == "ids" else "order"
		if not ids.is_empty() and ids.all(func(i): return str(i).begins_with("m")):
			kind = "bakery"
	var file_kind := "campaign" if kind == "order" else kind
	var existing: Array = []
	if FileAccess.file_exists(OUT[file_kind]):
		existing = JSON.parse_string(FileAccess.get_file_as_string(OUT[file_kind])).levels
	var by_id := {}
	for l in existing:
		by_id[l.id] = l
	if kind == "order":
		_write("campaign", by_id)
		quit(0)
		return
	if ids.is_empty():
		var total := 60
		var from := int(args[1]) if args.size() > 1 else 1
		var to := int(args[2]) if args.size() > 2 else total
		for n in range(from, to + 1):
			ids.append("%s%03d" % ["c" if kind == "campaign" else "d", n])
	var sigs := {}
	for l in existing:
		if not (l.id in ids):
			sigs[LevelValidator.signature(LevelDef.from_dict(l))] = true
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var lvl: Dictionary = _hand(id)
		if not lvl.is_empty():
			var r := LevelValidator.validate(lvl, BUDGET)
			assert(r.verdict == LevelValidator.PASSED, "hand level %s: %s" % [id, r.errors])
			lvl.meta.solution = r.path
			lvl.meta.metrics = r.metrics
		else:
			lvl = _best_candidate(kind, id, sigs)
		lvl.meta.verified = LevelValidator.PASSED
		lvl.meta.playtest = "AWAITING_HUMAN"
		lvl.meta.tier = _tier_name(kind, id)
		sigs[LevelValidator.signature(LevelDef.from_dict(lvl))] = true
		by_id[lvl.id] = lvl
		var m: Dictionary = lvl.meta.metrics
		print("%s  win=%.2f  min_ctr=%d  par=%d  items=%d  nodes=%d  fresh=%d/%d bags=%d/%d locks=%d/%d  (%d ms)" % [lvl.id,
			m.random_win_rate, m.min_counter, lvl.meta.par_counter, m.items, m.solver_nodes,
			int(m.get("fresh", 0)), int(m.get("fresh_waits", 0)), int(m.get("bags", 0)), int(m.get("reveals", 0)),
			int(m.get("locked_crates", 0)), int(m.get("lock_moves", 0)), Time.get_ticks_msec() - t0])
		_write(kind, by_id)
	quit(0)

func _hand(id: String) -> Dictionary:
	for h in HAND:
		if h.id == id:
			return h.duplicate(true)
	return {}

func _tier_name(kind: String, id: String) -> String:
	if kind == "daily": return "daily"
	match id[0]:
		"p": return "bell"
		"m": return "bakery"
		"f": return "fresh"
		"b": return "bags"
		"k": return "locks"
		"x": return "mixed"
	var n := int(id.substr(1))
	if n <= 5: return "intro"
	if n <= 15: return "sequencing"
	if n <= 30: return "pressure"
	if n <= 45: return "two_stage"
	return "mastery"

## Levels regenerated in v2 to remove difficulty spikes (seeded differently).
const RESEEDED := ["c025", "c034", "c048", "c057"]

func _best_candidate(kind: String, id: String, sigs: Dictionary) -> Dictionary:
	var n := int(id.substr(1))
	var mech := id[0] in ["f", "b", "k", "x", "p", "m"]
	var p := mech_tier(id) if mech else tier_for(kind, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s-%d-v1" % [kind, n]) if not (mech or id in RESEEDED) else hash("%s-v2" % id)
	var strict := mech or id in RESEEDED
	var best: Dictionary = {}
	var best_score := INF
	var tries := 0
	var good := 0
	while good < CANDIDATES and tries < CANDIDATES * (40 if strict else 12):
		tries += 1
		var cand := _make(kind, n, p, rng)
		cand.id = id
		var def := LevelDef.from_dict(cand)
		if LevelValidator.signature(def) in sigs:
			continue
		if p.two > 0.0 and not def.has_two_stage():
			continue # tiers that feature two-stage orders must include one
		var r := LevelValidator.validate(cand, BUDGET)
		if r.verdict != LevelValidator.PASSED:
			continue
		var m: Dictionary = r.metrics
		if LevelValidator.is_trivial(m) and (n > 3 or mech):
			continue
		if m.min_counter >= p.counter and n <= 15 and not mech:
			continue # early levels keep at least one spare slot
		var need: String = p.get("need", "")
		if strict and need in ["", "any"] and m.random_win_rate < p.target * 0.55:
			continue # v2: no spikes far below the tier's intended difficulty
		if need != "":
			# Random playouts never ring the bell, so the win-rate proxy can't
			# judge bell levels; the bell's value is proven by search instead.
			var bv := LevelValidator.bell_value(def, BUDGET)
			if need == "required" and bv != "required":
				continue
			if need == "decision" and not (bv in ["required", "tidier"]):
				continue
			if need == "any" and m.random_win_rate < 0.3:
				continue # breathing levels stay relaxed
			m.bell = bv
		if p.get("special", false) and def.max_stages() < 3:
			continue
		if p.fresh > 0.0 and int(m.fresh_waits) < 1:
			continue # fresh items must actually force a wait on the solution line
		if p.bags > 0.0 and int(m.reveals) < 2:
			continue
		if p.locks > 0 and int(m.lock_moves) < 3:
			continue
		good += 1
		var score: float = absf(m.random_win_rate - p.target)
		if need in ["required", "decision"]:
			score = float(m.solver_nodes) / 1000.0 + absf(float(m.items) - float(p.omax) * 2.6) * 0.05
		score += 0.002 * absf(m.solver_nodes - 300)  * (1.0 if m.solver_nodes > 20000 else 0.0)
		if score < best_score:
			best_score = score
			cand.meta.solution = r.path
			cand.meta.metrics = m
			cand.meta.par_counter = mini(p.counter, m.min_counter + 1)
			best = cand
	assert(not best.is_empty(), "no valid candidate for %s" % id)
	return best

func _make(kind: String, n: int, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# Rotate the palette so successive levels feature different products.
	var rot := (n * 2) % Products.COUNT if p.products < Products.COUNT else 0
	var pal: Array = []
	for i in p.products:
		pal.append(Products.IDS[(i + rot) % Products.COUNT])
	if p.has("palette"):
		pal = (p.palette as Array).duplicate()
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
	# v3 special order: three consecutive single-stage orders become one
	# 3-part catering order (arrives second). Supply and demand are unchanged.
	if p.get("special", false):
		var singles: Array = []
		for i in range(1, fixed.size()):
			if fixed[i].size() == 1:
				singles.append(i)
			if singles.size() == 3:
				break
		if singles.size() == 3:
			var big: Array = [fixed[singles[0]][0], fixed[singles[1]][0], fixed[singles[2]][0]]
			for k in range(2, -1, -1):
				fixed.remove_at(singles[k])
			fixed.insert(1, big)
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
	# v2 mechanic markers
	for c in crates:
		for k in c.size():
			if p.fresh > 0.0 and rng.randf() < p.fresh:
				c[k] = c[k] + "!"
			if k >= 1 and p.bags > 0.0 and rng.randf() < p.bags:
				c[k] = "?" + c[k]
	var prefix := "c" if kind == "campaign" else "d"
	var out := {"id": "%s%03d" % [prefix, n], "counter": p.counter, "trays": p.trays,
		"crates": crates, "orders": fixed, "meta": {}}
	if p.locks > 0 and crates.size() > p.locks and fixed.size() > 2:
		var locks: Array = []
		locks.resize(crates.size())
		locks.fill(0)
		var idx_pool: Array = range(crates.size())
		for k in p.locks:
			var ci: int = idx_pool.pop_at(rng.randi_range(0, idx_pool.size() - 1))
			locks[ci] = rng.randi_range(1, mini(3, fixed.size() - 2))
		out["locks"] = locks
	return out

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
	if kind == "bakery":
		ids = BAKERY_ORDER.filter(func(i): return by_id.has(i))
	if kind == "campaign":
		ids = ORDER.filter(func(i): return by_id.has(i))
		for k in TUTORIAL_META:
			if by_id.has(k):
				by_id[k].meta.tutorial = TUTORIAL_META[k]
	if kind in ["campaign", "bakery"]:
		for k in SPECIALS:
			if by_id.has(k):
				by_id[k].meta.special = SPECIALS[k]
	var levels: Array = []
	for id in ids:
		if kind == "campaign" and id in NO_BELL:
			by_id[id]["bell"] = false
		levels.append(by_id[id])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/levels"))
	var f := FileAccess.open(OUT[kind], FileAccess.WRITE)
	var doc := {"version": 2, "kind": kind, "levels": levels}
	if kind == "campaign":
		doc["chapters"] = CHAPTERS.map(func(c): return {"title": c[0], "first": c[1]})
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
