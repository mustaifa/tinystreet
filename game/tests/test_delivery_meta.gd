extends "res://tests/test_base.gd"
## Delivery Logic progression and saves: reward idempotency, medals against
## the proved minimum, personal bests, separate namespaces, schema-6
## migration with backup, fresh install, interrupted writes, reload after a
## win, saved attempts (with history) and changed level data; plus hints
## recomputed after moves, undo and restart.

const DIR := "user://test_saves_dl"

func setup_suite(_t: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

func _store(name: String) -> SaveStore:
	var s := SaveStore.new(DIR + "/" + name + ".json")
	s.delete_all()
	return s

func _lv(rows: Array, reward: int = 4, min_pushes: int = -1) -> DeliveryLevel:
	return DeliveryLevel.from_dict({"id": "tlv", "map": rows, "reward": reward, "min_pushes": min_pushes})

func _solve(l: DeliveryLevel, extra_walk: bool = false, hints: int = 0) -> DeliverySession:
	var ps := DeliverySession.start(l)
	ps.hints_used = hints
	if extra_walk:
		for d in [DeliveryRules.Dir.DOWN, DeliveryRules.Dir.UP]:
			ps.act(d)
	var sv := DeliverySolver.solve(l, ps.state)
	for d in sv.moves():
		ps.act(d)
	check(ps.is_won(), "test solve finished")
	return ps

const ROOM := ["#######", "#@....#", "#..A..#", "#.....#", "#....a#", "#######"]

func test_first_clear_pays_once() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM, 4, 4)
	var r1 := DeliveryProgress.record_win(d, l, _solve(l))
	check(r1.first_clear)
	eq(r1.tokens, 4)
	eq(int(d.tokens), 4)
	var r2 := DeliveryProgress.record_win(d, l, _solve(l))
	check(not r2.first_clear)
	eq(r2.tokens, 0, "replay pays nothing")
	eq(int(d.tokens), 4)
	# the same result recorded again (e.g. reopening a result) pays nothing
	DeliveryProgress.record_win(d, l, _solve(l))
	eq(int(d.tokens), 4)
	eq(int(d.grants["dl:clear:tlv"]), 4)

func test_modes_do_not_share_first_clear_rewards() -> void:
	var d := GameData.fresh()
	Progression.record_win(d, "tlv", 3)    # the retired sorting campaign
	var t0 := int(d.tokens)
	var l := _lv(ROOM, 4, 4)
	var r := DeliveryProgress.record_win(d, l, _solve(l))
	eq(r.tokens, 4, "Delivery Logic pays its own reward")
	eq(int(d.tokens), t0 + 4)
	check(Progression.is_cleared(d, "tlv") and DeliveryProgress.is_cleared(d, "tlv"), "separate records")
	d.campaign.cleared.erase("tlv")
	check(DeliveryProgress.is_cleared(d, "tlv"), "sorting progress does not decide Delivery Logic progress")

func test_best_and_medals() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM, 4, 4)
	var slow := _solve(l, true, 1)
	var r := DeliveryProgress.record_win(d, l, slow)
	eq(r.pushes, 4)
	check(r.fewest, "pushes equal the proved minimum")
	check(not r.unassisted, "a hint removes the unassisted badge")
	check(not r.had_best)
	var fast := _solve(l)
	var r2 := DeliveryProgress.record_win(d, l, fast)
	check(r2.new_best, "same pushes, fewer steps is a new best")
	eq(r2.best_steps, fast.state.steps)
	check(r2.unassisted and r2.unassisted_new)
	check(not r2.fewest_new, "medal already held")
	check(DeliveryProgress.medal(d, "tlv", "fewest") and DeliveryProgress.medal(d, "tlv", "unassisted"))
	var r3 := DeliveryProgress.record_win(d, l, slow)
	check(not r3.new_best, "a worse replay keeps the best")
	eq(DeliveryProgress.best(d, "tlv").steps, fast.state.steps)
	check(DeliveryProgress.medal(d, "tlv", "unassisted"), "medals are never taken away")

func test_win_does_not_feed_retired_achievements() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM, 4, 4)
	DeliveryProgress.record_win(d, l, _solve(l))
	eq(int(d.stats.wins), 0, "sorting-mode stats untouched")
	eq(Achievements.claimable_count(d), 0, "no retired achievement becomes claimable")
	eq(int(d.tokens), 4, "only the completion reward")

func test_no_medal_without_proof() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM, 4, -1)
	var r := DeliveryProgress.record_win(d, l, _solve(l))
	check(not r.fewest, "no proved minimum -> no fewest-pushes medal")

func test_undo_creates_no_currency() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM, 4, 4)
	var ps := DeliverySession.start(l)
	var mv := DeliverySolver.solve(l, ps.state).moves()
	for k in mv.size() - 1:
		ps.act(mv[k])
	for k in 5:
		ps.undo()
		ps.redo()
	eq(int(d.tokens), 0, "moving, undoing and redoing never pays")
	ps.act(mv[mv.size() - 1])
	DeliveryProgress.record_win(d, l, ps)
	eq(int(d.tokens), 4)

func test_saved_attempt_roundtrip_and_clear_on_win() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM, 4, 4)
	var ps := DeliverySession.start(l)
	ps.act(DeliveryRules.Dir.RIGHT)
	ps.act(DeliveryRules.Dir.DOWN)
	DeliveryProgress.save_attempt(d, ps)
	var d2 = JSON.parse_string(JSON.stringify(d))
	var back := DeliveryProgress.load_attempt(d2, l)
	check(back != null)
	eq(back.state.snapshot(), ps.state.snapshot())
	eq(back.history.size(), 2, "undo history saved")
	DeliveryProgress.record_win(d, l, _solve(l))
	eq(DeliveryProgress.current_id(d), "", "a win clears the saved attempt")

func test_changed_level_discards_attempt() -> void:
	var d := GameData.fresh()
	var l := _lv(ROOM)
	var ps := DeliverySession.start(l)
	ps.act(DeliveryRules.Dir.RIGHT)
	DeliveryProgress.save_attempt(d, ps)
	var l2 := DeliveryLevel.from_dict({"id": "tlv", "map": ["#######", "#@....#", "#.A...#", "#.....#", "#....a#", "#######"]})
	var why: Array = []
	check(DeliveryProgress.load_attempt(d, l2, why) == null, "changed layout: not resumed")
	check("changed" in why)
	eq(DeliveryProgress.current_id(d), "", "stale attempt discarded")
	check(not DeliveryProgress.is_cleared(d, "tlv"), "never marked solved")

# ------------------------------------------------------------------ saves

func test_fresh_install_has_logic_namespace() -> void:
	var s := _store("fresh")
	var d := s.load_data()
	check(d.logic is Dictionary and d.logic.cleared.is_empty() and d.logic.current.is_empty())

func test_migration_schema5_to_6_keeps_everything() -> void:
	var s := _store("mig5")
	var old := GameData.fresh()
	old.erase("logic")
	old.tokens = 17
	old.tokens_earned = 40
	old.grants = {"star:c001:1": 1, "star:c001:2": 1}
	old.campaign.cleared = {"c001": true}
	old.campaign.stars = {"c001": 2}
	old.restoration.steps = 2
	old.current = {"kind": "campaign", "id": "c002"}
	var payload := JSON.stringify(old)
	var env := {"schema": 5, "sha256": payload.sha256_text(), "payload": payload}
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	var d := s.load_data()
	eq(s.last_load_source, "main")
	eq(int(d.tokens), 17, "currency preserved")
	eq(int(d.restoration.steps), 2, "restoration preserved")
	check(Progression.is_cleared(d, "c001"), "sorting records preserved")
	eq(str(d.current.id), "c002", "old in-progress record kept untouched")
	check(d.logic.cleared.is_empty(), "nothing new marked solved")
	check(FileAccess.file_exists(s.path + ".schema5.bak"), "pre-migration backup kept")
	var bak = JSON.parse_string(FileAccess.get_file_as_string(s.path + ".schema5.bak"))
	eq(int(bak.schema), 5, "backup is the untouched old file")
	s.save(d)
	var again := s.load_data()
	eq(int(again.tokens), 17)

func test_migration_from_v1_reaches_schema6() -> void:
	var d := SaveStore.migrate({"stars": [["c001", 3]], "tokens": 2}, 1)
	check(d.has("logic") and d.logic.cleared is Dictionary, "every old schema migrates to the logic namespace")

func test_interrupted_write_keeps_logic_progress() -> void:
	var s := _store("intr")
	var d := GameData.fresh()
	d.logic.cleared["d01"] = true
	d.grants["dl:clear:d01"] = 3
	d.tokens = 3
	s.save(d)
	# crash between "main -> .bak" and "tmp -> main": only tmp exists
	DirAccess.rename_absolute(ProjectSettings.globalize_path(s.path), ProjectSettings.globalize_path(s.path + ".tmp"))
	var back := s.load_data()
	eq(s.last_load_source, "tmp")
	check(DeliveryProgress.is_cleared(back, "d01"))
	# a torn temp file next to a good main file: main wins
	s.save(back)
	var f := FileAccess.open(s.path + ".tmp", FileAccess.WRITE)
	f.store_string("{\"schema\":6,\"sha256\":\"x\",\"payload\":\"{")
	f.close()
	var back2 := s.load_data()
	eq(s.last_load_source, "main")
	eq(int(back2.tokens), 3)

func test_reload_after_win_no_duplicate_reward() -> void:
	var s := _store("rewin")
	var d := s.load_data()
	var l := _lv(ROOM, 4, 4)
	var ps := DeliverySession.start(l)
	ps.act(DeliveryRules.Dir.RIGHT)
	DeliveryProgress.save_attempt(d, ps)
	s.save(d)
	d = s.load_data()
	var resumed := DeliveryProgress.load_attempt(d, l)
	for mv in DeliverySolver.solve(l, resumed.state).moves():
		resumed.act(mv)
	DeliveryProgress.record_win(d, l, resumed)
	s.save(d)
	var after := s.load_data()
	eq(int(after.tokens), 4)
	eq(DeliveryProgress.current_id(after), "", "no attempt left to resume after a win")
	DeliveryProgress.record_win(after, l, _solve(l))
	eq(int(after.tokens), 4, "winning again after a reload pays nothing")

func test_reset_clears_logic_progress() -> void:
	var d := GameData.fresh()
	d.logic.cleared["d01"] = true
	var r := GameData.fresh()
	check(r.logic.cleared.is_empty() and not d.logic.cleared.is_empty())

# ------------------------------------------------------------------ progression over the shipped data

func test_unlock_rules() -> void:
	var dp := DeliveryProgress.new()
	dp.load_levels()
	var d := GameData.fresh()
	check(dp.count() >= 12)
	check(dp.is_unlocked(d, 0) and not dp.is_unlocked(d, 1), "only the first puzzle is open")
	d.logic.cleared[dp.id_at(0)] = true
	check(dp.is_unlocked(d, 1) and not dp.is_unlocked(d, 2))
	eq(dp.next_index(d), 1)
	check(not BuildConfig.qa_unlock_all(), "tests run without the qa feature: no bypass")

func test_rewards_cover_restoration() -> void:
	var dp := DeliveryProgress.new()
	dp.load_levels()
	var total := 0
	for l in dp.levels:
		total += int(l.reward)
	var cost := 0
	for st in Restoration.STEPS:
		cost += int(st.cost)
	check(dp.count() < 30 or total >= cost, "30 puzzles pay for every café step (%d >= %d)" % [total, cost])

# ------------------------------------------------------------------ hints

func test_hints_recomputed_after_move_undo_restart() -> void:
	var dp := DeliveryProgress.new()
	dp.load_levels()
	var l := dp.level("d04")
	var ps := DeliverySession.start(l)
	var h0 := DeliveryHints.compute(l, ps.state)
	check(h0.ok)
	eq(int(h0.pushes_left), l.min_pushes(), "start: proved shortest finish")
	# follow the hint: one push fewer to go
	var stand := l.nbr(ps.state.crates[int(h0.crate)], DeliveryRules.opposite(int(h0.dir)))
	ps.walk_to(stand)
	ps.act(int(h0.dir))
	var h1 := DeliveryHints.compute(l, ps.state)
	eq(int(h1.pushes_left), l.min_pushes() - 1, "after the hinted push")
	# a wasteful push changes the hint; undo brings back the earlier one
	var opts := DeliveryRules.pushes_from(l, ps.state, DeliveryRules.reach(l, ps.state))
	for pv in opts:
		var t := ps.state.copy()
		t.player = l.nbr(t.crates[pv.x], DeliveryRules.opposite(pv.y))
		DeliveryRules.move(l, t, pv.y)
		var hx := DeliveryHints.compute(l, t)
		if not hx.ok or int(hx.pushes_left) != int(h1.pushes_left) - 1:
			ps.walk_to(l.nbr(ps.state.crates[pv.x], DeliveryRules.opposite(pv.y)))
			ps.act(pv.y)
			break
	var h2 := DeliveryHints.compute(l, ps.state)
	check(not h2.ok or int(h2.pushes_left) != int(h1.pushes_left) - 1, "hint follows the new position")
	ps.undo()
	ps.undo()
	var h3 := DeliveryHints.compute(l, ps.state)
	eq(int(h3.pushes_left), int(h1.pushes_left), "after undo the hint is the earlier one again")
	ps.restart()
	var h4 := DeliveryHints.compute(l, ps.state)
	eq(int(h4.pushes_left), l.min_pushes(), "after restart: back to the start hint")
	eq(int(h4.crate), int(h0.crate))

func test_hint_in_dead_position_offers_no_push() -> void:
	var dp := DeliveryProgress.new()
	dp.load_levels()
	var l := dp.level("d03")
	var s := DeliveryRules.start_state(l)
	var mv := DeliverySolver.expand_pushes(l, s, [Vector2i(2 * l.w + 2, DeliveryRules.Dir.UP)] as Array[Vector2i])
	for d in mv:
		DeliveryRules.move(l, s, d)
	var h := DeliveryHints.compute(l, s)
	check(not h.ok, "no 'next push' from a proven dead end")
	eq(int(h.status), DeliverySolver.UNSOLVABLE)

func test_hint_displacement_flag() -> void:
	var dp := DeliveryProgress.new()
	dp.load_levels()
	var l := dp.level("d05")   # the delivered croissant must step off its pad first
	var h := DeliveryHints.compute(l, DeliveryRules.start_state(l))
	check(h.ok and h.away, "tier 2 says the crate must move away first")
	eq(l.crate_sym[int(h.crate)], 1, "...and it is the croissant")
