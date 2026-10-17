extends "res://tests/test_base.gd"
## v2 meta systems: save migration, idempotent rewards, café tasks,
## achievements, restoration extras and the Rush challenge.

const DIR := "user://test_saves_v2"

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

# ------------------------------------------------------------------ migration

func test_migration_v2_keeps_visible_cafe_and_choices() -> void:
	var s := _store("v2cafe")
	var v2 := GameData.fresh()
	v2.erase("grants")
	v2.restoration = {"milestones": 4, "choices": {"wall": "sage", "seating": "rattan", "plants": "olive"}}
	v2.tokens = 3
	for i in 40:
		var id := "c%03d" % (i + 1)
		v2.campaign.cleared[id] = true
		v2.campaign.stars[id] = 2
	_write_env(s, 2, v2)
	var d := s.load_data()
	eq(Restoration.steps(d), 7, "v1 seating milestone -> through the plants step")
	eq(Restoration.choice(d, "walls"), "sage", "wall choice carried over")
	eq(Restoration.choice(d, "seating"), "rattan")
	eq(Restoration.choice(d, "plants"), "olive")
	# 80 earned stars - (3+6+10+14+18+22+26 = 99) < 0 -> keep the old 3 tokens.
	eq(d.tokens, 3, "never fewer tokens than before the update")
	check(Wallet.has_grant(d, "star:c001:2"))
	eq(Progression.record_win(d, "c001", 2).tokens, 0, "migrated stars can't pay twice")
	eq(Progression.record_win(d, "c001", 3).tokens, 1, "a new third star still pays")

func test_migration_v2_credits_unspent_stars() -> void:
	var s := _store("v2tok")
	var v2 := GameData.fresh()
	v2.erase("grants")
	v2.restoration = {"milestones": 1, "choices": {}}
	v2.tokens = 0
	for i in 20:
		var id := "c%03d" % (i + 1)
		v2.campaign.cleared[id] = true
		v2.campaign.stars[id] = 3
	_write_env(s, 2, v2)
	var d := s.load_data()
	eq(Restoration.steps(d), 2)
	eq(d.tokens, 60 - 9, "60 stars earned, clean+walls (9) owned")
	eq(d.tokens_earned, 60)

func test_migrated_save_roundtrips_at_v3() -> void:
	var s := _store("v3rt")
	var v2 := GameData.fresh()
	v2.restoration = {"milestones": 2, "choices": {}}
	_write_env(s, 2, v2)
	var d := s.load_data()
	check(s.save(d))
	var env = JSON.parse_string(FileAccess.get_file_as_string(s.path))
	eq(int(env.schema), SaveStore.SCHEMA)
	var back := s.load_data()
	eq(Restoration.steps(back), 3)

# ------------------------------------------------------------------ duplicate prevention

func test_wallet_grants_are_idempotent() -> void:
	var d := GameData.fresh()
	check(Wallet.grant(d, "x", 5))
	check(not Wallet.grant(d, "x", 5), "same key twice")
	check(not Wallet.grant(d, "", 5))
	check(not Wallet.grant(d, "y", 0))
	eq(d.tokens, 5)
	check(not Wallet.spend(d, 6))
	check(Wallet.spend(d, 5))
	eq(d.tokens, 0)

func test_rewards_survive_reload_without_duplicating() -> void:
	var s := _store("reload")
	var d := GameData.fresh()
	Progression.record_win(d, "c001", 3)
	s.save(d)
	var back := s.load_data()
	eq(Progression.record_win(back, "c001", 3).tokens, 0, "reloading can't re-pay stars")
	eq(back.tokens, 3)

func test_restoration_double_unlock_spends_once() -> void:
	var d := GameData.fresh()
	d.tokens = 3 + 5
	eq(Restoration.unlock_next(d), "clean")
	eq(Restoration.unlock_next(d), "", "second tap can't afford the next step")
	eq(d.tokens, 5)
	eq(Restoration.steps(d), 1)

func test_extras_buy_once_and_toggle() -> void:
	var d := GameData.fresh()
	d.restoration.steps = 2
	d.tokens = 25
	check(Restoration.can_buy_extra(d, "clock"))
	check(Restoration.buy_extra(d, "clock"))
	check(not Restoration.buy_extra(d, "clock"), "no double purchase")
	eq(d.tokens, 15)
	check(not Restoration.can_buy_extra(d, "cat"), "cat needs the seating step")
	check(Restoration.shown_extras(d).has("clock"))
	Restoration.toggle_extra(d, "clock")
	check(not Restoration.shown_extras(d).has("clock"), "hidden but still owned")
	check(Restoration.owns_extra(d, "clock"))
	check(not Restoration.can_buy_extra(d, "photos"), "achievement extras can't be bought")

# ------------------------------------------------------------------ tasks

func _summary(stars: int, hints: int = 0, peak: int = 1, streak: int = 0) -> Dictionary:
	return {"kind": "campaign", "stars": stars, "hints": hints, "peak": peak, "best_streak": streak, "tokens": stars}

func test_tasks_rotate_by_date_and_are_deterministic() -> void:
	var d := GameData.fresh()
	Tasks.refresh(d, "2026-10-16", ["fresh", "bag"])
	var a: Array = d.tasks.list.duplicate()
	eq(a.size(), Tasks.PER_DAY)
	Tasks.refresh(d, "2026-10-16", ["fresh", "bag"])
	eq(d.tasks.list, a, "same day, same tasks")
	var d2 := GameData.fresh()
	Tasks.refresh(d2, "2026-10-16", ["fresh", "bag"])
	eq(d2.tasks.list, a, "deterministic for a date")
	var seen := {}
	for day in range(1, 21):
		Tasks.refresh(d, "2026-11-%02d" % day, ["fresh", "bag"])
		for id in d.tasks.list:
			seen[id] = true
	check(seen.size() >= 8, "tasks rotate across the pool")

func test_tasks_never_offer_unmet_mechanics() -> void:
	var d := GameData.fresh()
	for day in range(1, 29):
		Tasks.refresh(d, "2026-12-%02d" % day, [])
		check(not ("fresh" in d.tasks.list) and not ("bags" in d.tasks.list), "mechanic task before mechanic")

func test_task_progress_and_single_claim() -> void:
	var d := GameData.fresh()
	d.tasks = {"date": "2026-10-16", "list": ["wins", "orders", "three_star"], "base": {}}
	d.tasks.base = {"wins": 0, "orders": 0, "three_star": 0}
	var L := LevelDef.from_dict({"id": "t1", "counter": 2, "trays": 1, "crates": [["coffee"]], "orders": [[{"coffee": 1}]]})
	eq(Tasks.claim(d, "wins"), 0, "not done yet")
	for i in 3:
		Meta.on_level_won(d, L, _summary(3))
	check(Tasks.is_done(d, "wins"))
	eq(Tasks.progress(d, "wins"), 3)
	eq(Tasks.claim(d, "wins"), 2)
	eq(Tasks.claim(d, "wins"), 0, "claimed once")
	eq(Tasks.claim(d, "streak"), 0, "not today's task")
	eq(d.tokens, 2)
	# a new day: same task id, new key, fresh baseline
	Tasks.refresh(d, "2026-10-17", [])
	for id in d.tasks.list:
		eq(Tasks.progress(d, id), 0, "new day starts from zero")

# ------------------------------------------------------------------ achievements and stats

func test_level_win_updates_stats() -> void:
	var d := GameData.fresh()
	var L := LevelDef.from_dict({"id": "t2", "counter": 2, "trays": 1, "locks": [0, 1],
		"crates": [["coffee!", "?tea"], ["tea"]], "orders": [[{"coffee": 1}], [{"tea": 2}]]})
	var r := Meta.on_level_won(d, L, _summary(3, 0, 0, 6))
	eq(int(d.stats.wins), 1)
	eq(int(d.stats.orders), 2)
	eq(int(d.stats.fresh), 1)
	eq(int(d.stats.bags), 1)
	eq(int(d.stats.unlocks), 1)
	eq(int(d.stats.three_star), 1)
	eq(int(d.stats.no_hint_wins), 1)
	eq(int(d.stats.tidy_wins), 1)
	eq(int(d.stats.best_streak), 6)
	eq(int(d.stats.streak5_wins), 1)
	eq(int(d.stats.cast.theo), 1, "coffee-only order is Theo's")
	check("first_steps" in r.new_achievements)

func test_achievement_claim_once_and_announce_once() -> void:
	var d := GameData.fresh()
	check(not Achievements.is_unlocked(d, "first_steps"))
	eq(Achievements.claim(d, "first_steps"), 0, "locked achievements pay nothing")
	d.stats.wins = 1
	eq(Achievements.take_new(d), ["first_steps"])
	eq(Achievements.take_new(d), [], "announced once")
	eq(Achievements.claim(d, "first_steps"), 2)
	eq(Achievements.claim(d, "first_steps"), 0)
	check(Achievements.is_claimed(d, "first_steps"))

func test_achievement_cosmetics_unlock() -> void:
	var d := GameData.fresh()
	d.restoration.steps = 8
	check(not Restoration.is_option_available(d, "sign", "gilded"))
	d.stats.three_star = 20
	check(Restoration.is_option_available(d, "sign", "gilded"), "perfectionist unlocks the gilded sign")
	check(not Restoration.owns_extra(d, "photos"))
	d.stats.cast = {"theo": 20, "basil": 20, "mira": 20}
	check(Restoration.owns_extra(d, "photos"), "the regulars award gives the photo wall")

func test_every_achievement_is_reachable() -> void:
	var p := Progression.new()
	p.load_levels()
	var total_orders := 0
	var cast := {"mira": 0, "theo": 0, "basil": 0}
	var fresh := 0
	var bags := 0
	var locks := 0
	for l in p.campaign:
		var def := LevelDef.from_dict(l)
		total_orders += def.orders.size()
		fresh += def.count_flag(LevelDef.FRESH)
		bags += def.count_flag(LevelDef.BAG)
		for v in def.locks:
			if v > 0:
				locks += 1
		var c := Customers.cast_counts(def)
		for k in c:
			cast[k] += int(c[k])
	# one pass of the campaign provides enough of each counter
	for a in Achievements.LIST:
		match String(a.stat):
			"wins": check(p.campaign.size() >= int(a.goal), a.id)
			"fresh": check(fresh >= int(a.goal), "%s needs %d fresh, campaign has %d" % [a.id, a.goal, fresh])
			"bags": check(bags >= int(a.goal), "%s needs %d bags, campaign has %d" % [a.id, a.goal, bags])
			"unlocks": check(locks >= int(a.goal), "%s needs %d locks, campaign has %d" % [a.id, a.goal, locks])
			"@stars": check(p.campaign.size() * 3 >= int(a.goal), a.id)
			"@steps": check(Restoration.STEPS.size() >= int(a.goal), a.id)
		if String(a.stat).begins_with("cast."):
			check(int(cast[String(a.stat).substr(5)]) >= int(a.goal), a.id)

# ------------------------------------------------------------------ rush

func test_rush_run_flow_and_best_time() -> void:
	var p := Progression.new()
	p.load_levels()
	var r := RushRun.create(p.daily_pool, 42)
	eq(r.ids.size(), RushRun.LENGTH)
	var uniq := {}
	for id in r.ids:
		uniq[id] = true
	eq(uniq.size(), RushRun.LENGTH, "distinct puzzles")
	eq(RushRun.create(p.daily_pool, 42).ids, r.ids, "seeded")
	var d := GameData.fresh()
	check(not r.record(d), "unfinished run records nothing")
	r.tick(10.0)
	check(not r.advance())
	check(not r.advance())
	check(r.advance(), "third win finishes")
	r.tick(5.0)
	eq(int(r.elapsed_ms), 10000, "clock stops when finished")
	check(r.record(d), "first time is a best")
	eq(int(d.stats.rush_best_ms), 10000)
	var r2 := RushRun.create(p.daily_pool, 7)
	r2.tick(20.0)
	r2.advance(); r2.advance(); r2.advance()
	check(not r2.record(d), "slower run is not a best")
	eq(int(d.stats.rush_best_ms), 10000)
	eq(int(d.stats.rush_done), 2)
	eq(RushRun.fmt_time(83000), "1:23")

# ------------------------------------------------------------------ story

func test_story_beats_have_strings() -> void:
	for id in Story.BEATS:
		for line in Story.BEATS[id]:
			check(Loc.has_key("name_" + str(line[0])), "name for %s" % line[0])
			check(Loc.has_key(str(line[1])), "line %s" % line[1])
	for id in Story.JOURNAL:
		check(Story.BEATS.has(id), "journal beat %s exists" % id)
		check(Loc.has_key("beat_" + id.replace(":", "_")), "journal title for %s" % id)
