extends "res://tests/test_base.gd"
## Shipped level data: schema, quantities, recorded solutions, metadata.
## (The budgeted independent solver pass lives in tools/validate_levels.gd.)

func _all() -> Array:
	var p := Progression.new()
	p.load_levels()
	return p.campaign + p.daily_pool

func test_counts() -> void:
	var p := Progression.new()
	p.load_levels()
	eq(p.campaign.size(), 84, "campaign size")
	eq(p.chapters.size(), 6, "chapters")
	check(p.daily_pool.size() >= 30, "daily pool size %d" % p.daily_pool.size())

func test_every_level_valid_and_solution_replays() -> void:
	for l in _all():
		var e := LevelValidator.schema_errors(l)
		check(e.is_empty(), "%s schema %s" % [l.id, e])
		var def := LevelDef.from_dict(l)
		var q := LevelValidator.quantity_errors(def)
		check(q.is_empty(), "%s quantities %s" % [l.id, q])
		check(Solver.verify_path(def, PackedInt32Array(l.meta.get("solution", []))), "%s solution replays" % l.id)
		eq(l.meta.get("verified", ""), "PASSED", l.id)
		check(int(l.meta.par_counter) >= int(l.meta.metrics.min_counter), "%s par achievable" % l.id)
		check(int(l.meta.par_counter) <= int(l.counter), "%s par within capacity" % l.id)

func test_unique_ids_and_layouts() -> void:
	var ids := {}
	var sigs := {}
	for l in _all():
		check(not ids.has(l.id), "duplicate id " + l.id)
		ids[l.id] = true
		var s := LevelValidator.signature(LevelDef.from_dict(l))
		check(not sigs.has(s), "duplicate layout %s = %s" % [l.id, sigs.get(s, "")])
		sigs[s] = l.id

## Each mechanic first appears in its tutorial level, which comes before any
## other level that uses it, and that tutorial is forgiving (random play wins).
func test_mechanics_introduced_in_order() -> void:
	var p := Progression.new()
	p.load_levels()
	var intro := {"fresh": "f01", "bag": "b01", "lock": "k01", "two_stage": "c031"}
	var tut := {"fresh": "tut_fresh", "bag": "tut_bag", "lock": "tut_lock", "two_stage": "tut_two_stage"}
	for m in intro:
		var first := -1
		for i in p.campaign.size():
			if m in LevelDef.from_dict(p.campaign[i]).mechanics():
				first = i
				break
		eq(p.campaign[first].id, intro[m], "%s first used by its intro level" % m)
		eq(str(p.campaign[first].meta.get("tutorial", "")), tut[m], "%s intro has a coach" % m)
		check(float(p.campaign[first].meta.metrics.random_win_rate) >= 0.4, "%s intro is forgiving" % m)
	# one new concept at a time: tutorials are far apart
	var order: Array = []
	for m in intro:
		order.append(p.campaign_index(intro[m]))
	order.sort()
	for i in range(1, order.size()):
		check(order[i] - order[i - 1] >= 8, "at least 8 levels between new mechanics")

## Mechanic levels must exercise their mechanic on the recorded solution.
func test_mechanic_levels_engage_their_mechanic() -> void:
	for l in _all():
		var def := LevelDef.from_dict(l)
		var e := LevelValidator.mechanic_engagement(def, PackedInt32Array(l.meta.solution))
		if def.count_flag(LevelDef.FRESH) > 0 and str(l.id).begins_with("f"):
			check(int(e.fresh_waits) >= 1, "%s fresh items never force a wait" % l.id)
		if def.count_flag(LevelDef.BAG) > 0:
			check(int(e.reveals) >= 1, "%s bags never revealed" % l.id)
		if def.has_locks():
			check(int(e.lock_moves) >= 1, "%s lock never matters" % l.id)

## The flagged v1 spikes were regenerated inside their tier's band.
func test_v1_spikes_fixed() -> void:
	var p := Progression.new()
	p.load_levels()
	for id in ["c025", "c034", "c048", "c057"]:
		var l: Dictionary = p.campaign[p.campaign_index(id)]
		check(float(l.meta.metrics.random_win_rate) >= 0.08, "%s random-play win rate %.2f" % [id, float(l.meta.metrics.random_win_rate)])

## The cast appears often enough for their tasks/achievements.
func test_cast_appears_across_campaign() -> void:
	var p := Progression.new()
	p.load_levels()
	var tot := {"mira": 0, "theo": 0, "basil": 0}
	for l in p.campaign:
		var c := Customers.cast_counts(LevelDef.from_dict(l))
		for k in c:
			tot[k] += int(c[k])
	for k in tot:
		check(int(tot[k]) >= 25, "%s serves only %d orders across the campaign" % [k, tot[k]])

func test_solver_handles_two_stage_shipped_level() -> void:
	var p := Progression.new()
	p.load_levels()
	var def := LevelDef.from_dict(p.campaign[40])
	var r := Solver.new(300000).solve(PuzzleState.create(def))
	check(r.status != Solver.UNSOLVABLE, "level 41 solvable or unverified, never unsolvable")
