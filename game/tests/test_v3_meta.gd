extends "res://tests/test_base.gd"
## v3: schema-4 migration with backup, mastery, special orders, challenge
## cards, décor themes, the bakery, and bell/restart state.

const DIR := "user://test_saves_v3"

func setup_suite(_t: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

func _store(name: String) -> SaveStore:
	var s := SaveStore.new(DIR + "/" + name + ".json")
	s.delete_all()
	return s

func _write_env(s: SaveStore, schema: int, payload_d: Dictionary) -> void:
	var payload := JSON.stringify(payload_d)
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": schema, "sha256": payload.sha256_text(), "payload": payload}))
	f.close()

## A realistic v2 (schema 3) player: levels, stars, tokens, ledger, café with
## choices and extras, tasks, claimed award, settings, story.
func _v2_player() -> Dictionary:
	var d := GameData.fresh()
	for k in ["mastery"]:
		d.campaign.erase(k)
	for k in ["bakery", "challenges", "daily_days"]:
		d.erase(k)
	for i in 30:
		var id := "c%03d" % (i + 1)
		Progression.record_win(d, id, 2 + (i % 2))
	d.restoration.steps = 5
	d.restoration.choices = {"walls": "sage", "floor": "checker", "counter": "marble", "lights": "string"}
	d.restoration.extras = {"clock": true}
	d.restoration.hidden = {"clock": true}
	d.tokens = 17
	d.stats.wins = 30
	Achievements.claim(d, "first_steps")
	d.tasks = {"date": "2026-10-16", "list": ["wins", "orders", "stars"], "base": {"wins": 28, "orders": 100, "stars": 60}}
	Wallet.grant(d, "task:2026-10-16:wins", 2)
	d.settings.music = 0.3
	d.settings.reduced_motion = true
	d.settings.lang = "ar"
	d.story.seen = {"intro": true, "step:clean": true}
	d.daily.completed = {"2026-10-14": {"stars": 2, "moves": 20}}
	return d

func test_v3_migration_keeps_everything_and_backs_up() -> void:
	var s := _store("mig4")
	var v2 := _v2_player()
	var tokens := int(v2.tokens)
	var grants: Dictionary = v2.grants.duplicate()
	_write_env(s, 3, v2)
	var d := s.load_data()
	check(s.backup_written.ends_with(".schema3.bak"), "pre-migration backup written")
	check(FileAccess.file_exists(s.path + ".schema3.bak"))
	var bak = JSON.parse_string(FileAccess.get_file_as_string(s.path + ".schema3.bak"))
	eq(int(bak.schema), 3, "backup is the untouched old file")
	eq(Progression.is_cleared(d, "c030"), true, "completed levels")
	eq(int(d.campaign.stars["c002"]), 3, "stars")
	eq(int(d.tokens), tokens, "token balance unchanged")
	for k in grants:
		check(d.grants.has(k), "ledger key kept: %s" % k)
	eq(Restoration.steps(d), 5, "restoration steps")
	eq(Restoration.choice(d, "floor"), "checker", "selected décor")
	check(Restoration.owns_extra(d, "clock"), "owned extra")
	check(not Restoration.shown_extras(d).has("clock"), "hidden extra stays hidden")
	check(Achievements.is_claimed(d, "first_steps"), "claimed award")
	eq(Achievements.claim(d, "first_steps"), 0, "no duplicate award after migration")
	eq(Tasks.claim(d, "wins"), 0, "no duplicate task reward after migration")
	eq(d.tasks.list, ["wins", "orders", "stars"], "today's tasks kept")
	check(absf(float(d.settings.music) - 0.3) < 0.001 and bool(d.settings.reduced_motion) and d.settings.lang == "ar", "settings")
	check(Story.seen(d, "step:clean"), "story milestones")
	eq(d.daily.completed.size(), 1, "daily record")
	check(not Bakery.is_unlocked(d), "bakery starts locked")
	eq(d.campaign.mastery, {}, "mastery starts empty")
	eq(Progression.record_win(d, "c002", 3).tokens, 0, "replaying a migrated 3-star level pays nothing")
	# saved again at schema 4; a second load writes no new backup
	s.save(d)
	var s2 := SaveStore.new(s.path)
	var d2 := s2.load_data()
	eq(s2.backup_written, "", "no backup when already current")
	eq(int(d2.tokens), tokens)

func test_v1_save_reaches_v4() -> void:
	var s := _store("v1v4")
	var v1 := {"stars": [["c001", 3], ["c002", 1]], "tokens": 1, "settings": {"sfx": 0.4}}
	_write_env(s, 1, v1)
	var d := s.load_data()
	eq(int(d.tokens), 4, "1 old token -> 4 earned stars credited")
	check(Progression.is_cleared(d, "c002"))
	check(s.backup_written.ends_with(".schema1.bak"))

# ------------------------------------------------------------------ mastery

func test_mastery_separate_from_first_clear_and_paid_once() -> void:
	var d := GameData.fresh()
	var def := LevelDef.from_dict({"id": "mx", "counter": 3, "trays": 1, "crates": [["coffee"], ["tea"]],
		"orders": [[{"coffee": 1}], [{"tea": 1}]], "meta": {"metrics": {"min_counter": 0}}})
	var first := Progression.record_win(d, "mx", 2)
	var m0 := Progression.record_mastery(d, def, 1, 0)
	check(first.first_clear and not m0.mastery, "cleared without mastery")
	var m1 := Progression.record_mastery(d, def, 0, 1)
	check(not m1.mastery, "a hint forfeits mastery")
	var m2 := Progression.record_mastery(d, def, 0, 0)
	check(m2.mastery and m2.mastery_new and m2.mastery_tokens == 1)
	var m3 := Progression.record_mastery(d, def, 0, 0)
	check(m3.mastery and not m3.mastery_new and m3.mastery_tokens == 0, "ribbon pays once")
	check(Progression.has_mastery(d, "mx"))

# ------------------------------------------------------------------ specials

func test_special_rewards_once_and_unlock_bakery() -> void:
	var p := Progression.new()
	p.load_levels()
	var d := GameData.fresh()
	var r := Specials.on_win(d, p.def_for("p06"))
	check(r.new and Restoration.owns_extra(d, "chalkboard"), "chalkboard appears")
	check(not Specials.on_win(d, p.def_for("p06")).new, "second win: no new reward")
	check(not Bakery.is_unlocked(d))
	Specials.on_win(d, p.def_for("p12"))
	check(Bakery.is_unlocked(d), "p12 opens the bakery")
	eq(Specials.on_win(d, p.def_for("c010")), {}, "ordinary level")
	eq(Customers.for_order(p.def_for("p06"), 1), "theo", "special customer")
	check(Specials.is_special_order(p.def_for("p06"), 1))

# ------------------------------------------------------------------ challenges

func test_challenge_cards_valid_goals_and_once() -> void:
	var p := Progression.new()
	p.load_levels()
	var ids := {}
	for c in Challenges.LIST:
		check(p.def_for(str(c.level)) != null, "%s level exists" % c.id)
		check(not ids.has(c.level), "distinct puzzles")
		ids[c.level] = true
		check(str(c.goal) in ["win", "three", "no_hint", "no_undo", "tidy"])
	var d := GameData.fresh()
	check(not Challenges.is_open(d))
	Progression.record_win(d, "p01", 1)
	check(Challenges.is_open(d))
	var c1 := Challenges.def("ch05")
	var L := p.def_for(str(c1.level))
	check(not Challenges.goal_met(c1, L, 3, 0, 0, Progression.mastery_target(L) + 1), "tidy goal missed")
	check(Challenges.goal_met(c1, L, 1, 2, 3, Progression.mastery_target(L)), "tidy goal met")
	eq(Challenges.record(d, "ch05", false).tokens, 0)
	check(not Challenges.is_done(d, "ch05"))
	eq(Challenges.record(d, "ch05", true).tokens, int(c1.reward))
	eq(Challenges.record(d, "ch05", true).tokens, 0, "reward once")
	eq(Challenges.done_count(d), 1)

func test_challenge_goals_achievable_by_solver() -> void:
	# 'tidy' needs peak <= proven minimum: the minimum is achievable by definition.
	var p := Progression.new()
	p.load_levels()
	for c in Challenges.LIST:
		if str(c.goal) != "tidy":
			continue
		var L := p.def_for(str(c.level))
		var r := Solver.new(200000).solve(PuzzleState.create(L), Progression.mastery_target(L))
		eq(r.status, Solver.SOLVED, "%s tidy goal reachable" % c.id)

# ------------------------------------------------------------------ themes

func test_themes_apply_only_owned_categories() -> void:
	var d := GameData.fresh()
	d.restoration.steps = 3
	var tc := Restoration.theme_choices(d, "parisian")
	check(tc.has("walls") and tc.has("floor"), "open categories")
	check(not tc.has("seating"), "locked categories untouched")
	for cat in tc:
		check(Restoration.set_choice(d, cat, tc[cat]))
	eq(Restoration.current_theme(d), "parisian")
	for th in Restoration.THEMES:
		for cat in Restoration.THEMES[th]:
			var opts: Array = Restoration.CHOICES[cat].options.map(func(o): return o.id)
			check(Restoration.THEMES[th][cat] in opts, "%s.%s is a real option" % [th, cat])

# ------------------------------------------------------------------ bakery

func test_bakery_unlock_steps_choices_persist() -> void:
	var s := _store("bakery")
	var d := GameData.fresh()
	d.tokens = 100
	check(not Bakery.can_unlock(d), "locked until unlocked")
	d.bakery.unlocked = true
	eq(Bakery.unlock_next(d), "ovens")
	eq(Bakery.unlock_next(d), "shelves")
	check(Bakery.set_choice(d, "shelf", "whitewash"))
	check(not Bakery.set_choice(d, "awning", "mint"), "awning needs its step")
	eq(int(d.tokens), 100 - 16)
	s.save(d)
	var back := s.load_data()
	eq(Bakery.steps(back), 2)
	eq(Bakery.choice(back, "shelf"), "whitewash")
	check(Bakery.is_unlocked(back))

func test_bakery_levels_valid_and_oven_engaged() -> void:
	var p := Progression.new()
	p.load_levels()
	eq(p.bakery.size(), 8)
	for l in p.bakery:
		var def := LevelDef.from_dict(l)
		check(Solver.verify_path(def, PackedInt32Array(l.meta.solution)), "%s replays" % l.id)
		check(def.has_locks(), "%s has an oven" % l.id)
		var e := LevelValidator.mechanic_engagement(def, PackedInt32Array(l.meta.solution))
		check(int(e.lock_moves) >= 1, "%s oven matters" % l.id)
		for c in def.crates:
			for pr in c:
				check(pr in [Products.CROISSANT, Products.CUPCAKE, Products.STRAWBERRY, Products.CHOCOLATE], "%s pastries only" % l.id)
	check(p.def_for("m08").max_stages() >= 3, "bakery finale is a special order")

# ------------------------------------------------------------------ bell + restart

func test_restart_clears_bell_and_hint_respects_bell() -> void:
	var p := Progression.new()
	p.load_levels()
	var L := p.def_for("p01")
	var ps := PuzzleSession.start(L)
	ps.tap(0)
	ps.tap(0)
	ps.ring(1)
	var fresh := PuzzleSession.start(L)
	eq(fresh.state.pin, -1, "restart begins without a bell")
	# hint from the post-ring position continues correctly
	var h := ps.compute_hint()
	eq(h.status, Solver.SOLVED)
	var s := ps.state.copy()
	var r := Solver.new().solve(s)
	check(Solver.verify_path(L, PackedInt32Array(Array(ps.moves_log) + Array(r.path))), "hint path finishes the level from here")
