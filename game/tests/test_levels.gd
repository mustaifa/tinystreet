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
	eq(p.campaign.size(), 60, "campaign size")
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

func test_two_stage_introduced_at_31() -> void:
	var p := Progression.new()
	p.load_levels()
	for i in p.campaign.size():
		var has := LevelDef.from_dict(p.campaign[i]).has_two_stage()
		if i < 30:
			check(not has, "level %d should not use two-stage orders yet" % (i + 1))
	check(LevelDef.from_dict(p.campaign[30]).has_two_stage(), "level 31 introduces two-stage")

func test_solver_handles_two_stage_shipped_level() -> void:
	var p := Progression.new()
	p.load_levels()
	var def := LevelDef.from_dict(p.campaign[40])
	var r := Solver.new(300000).solve(PuzzleState.create(def))
	check(r.status != Solver.UNSOLVABLE, "level 41 solvable or unverified, never unsolvable")
