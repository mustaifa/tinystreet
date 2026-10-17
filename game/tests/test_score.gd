extends "res://tests/test_base.gd"
## v7: live score (Scoring.points), personal bests, schema-5 migration, the
## result card's main action, and win/loss state for the result flow.

const DIR := "user://test_score"

func setup_suite(_tree: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	if App.progression.campaign.is_empty():
		App.progression.load_levels()

## Two orders: coffee then tea. The tea crate is first, so tapping crate 0
## parks a tea on the counter while the coffee order is open.
func _level() -> LevelDef:
	return lvl({"counter": 3, "trays": 1, "crates": [["tea", "coffee"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"tea": 1, "coffee": 1}]]})

func test_points_reward_deliveries_not_taps() -> void:
	var ps := PuzzleSession.start(_level())
	eq(Scoring.points(ps.state), 0, "nothing served yet")
	ps.tap(0)   # tea -> counter: no points
	eq(Scoring.points(ps.state), 0, "parking an item earns nothing")
	ps.tap(1)   # coffee -> order 1 (direct) -> delivered; tea waits for order 2
	eq(ps.state.served_direct, 1)
	eq(ps.state.completed, 1)
	# order 2 arrived and took the tea from the counter automatically
	eq(ps.state.served_counter, 1, "counter item served")
	eq(Scoring.points(ps.state), 10 + 5 + 25)
	ps.tap(0)   # coffee -> order 2 direct -> win
	check(ps.is_won())
	var b := Scoring.breakdown(ps.state)
	eq(b.direct, 2)
	eq(b.via_counter, 1)
	eq(b.orders, 2)
	eq(b.spare, 2, "peak 1 of 3 spaces")
	eq(b.tidy, 20)
	eq(b.total, 2 * 10 + 5 + 2 * 25 + 20)

func test_tidy_bonus_only_on_completion() -> void:
	var ps := PuzzleSession.start(_level())
	ps.tap(1)
	eq(Scoring.tidy_bonus(ps.state), 0, "no bonus before the win")
	check(not ps.is_won())

func test_bell_rings_earn_nothing() -> void:
	var L := lvl({"counter": 2, "trays": 2, "crates": [["coffee", "coffee"]],
		"orders": [[{"coffee": 1}], [{"coffee": 1}]]})
	var ps := PuzzleSession.start(L)
	ps.ring(1)
	eq(Scoring.points(ps.state), 0)
	ps.ring(1)
	eq(Scoring.points(ps.state), 0)

func test_undo_redo_restart_keep_score_exact() -> void:
	var ps := PuzzleSession.start(_level())
	ps.tap(0)
	ps.tap(1)
	var after_two := Scoring.points(ps.state)
	check(ps.undo())
	eq(Scoring.points(ps.state), 0, "undo takes the points back with the move")
	ps.redo_log.clear()
	ps.tap(1)   # the parked tea stayed: it is served from the counter now
	var direct_first := Scoring.points(ps.state)
	eq(direct_first, 10 + 25 + 5, "coffee direct + order + tea from the counter")
	check(ps.undo())
	eq(Scoring.points(ps.state), 0)
	ps.redo()
	eq(Scoring.points(ps.state), direct_first, "redo restores exactly, not twice")
	check(not ps.can_redo())
	ps.redo()
	eq(Scoring.points(ps.state), direct_first, "a second redo adds nothing")
	var fresh := PuzzleSession.start(_level())
	eq(Scoring.points(fresh.state), 0, "restart begins at zero")
	check(after_two > 0)

func test_saved_attempt_rebuilds_same_score() -> void:
	var ps := PuzzleSession.start(_level())
	ps.tap(0)
	ps.tap(1)
	ps.undo()
	ps.tap(1)
	var back := PuzzleSession.restore(_level(), JSON.parse_string(JSON.stringify(ps.to_dict())))
	eq(Scoring.points(back.state), Scoring.points(ps.state))
	eq(back.state.served_direct, ps.state.served_direct)
	eq(back.state.served_counter, ps.state.served_counter)

func test_solver_key_ignores_score_tallies() -> void:
	# Two routes to the same board must stay one solver state.
	var a := PuzzleState.create(_level())
	var b := a.copy()
	b.served_direct = 5
	b.served_counter = 2
	eq(a.key(), b.key())

func test_points_on_every_shipped_solution() -> void:
	# The score is well defined on the real levels: replaying each recorded
	# solution gives a positive total that includes every order.
	check(App.progression.campaign.size() == 96, "levels loaded")
	for i in App.progression.campaign.size():
		var def := App.progression.def_for(str(App.progression.campaign[i].id))
		var s := PuzzleState.create(def)
		for a in def.meta.get("solution", []):
			Rules.apply_action(s, int(a))
		check(Rules.is_won(s), def.id + " solution wins")
		var items := 0
		for c in def.crates:
			items += c.size()
		eq(s.served_direct + s.served_counter, items, def.id + ": every item is served exactly once")
		check(Scoring.points(s) >= Scoring.PTS_ORDER * def.orders.size() + Scoring.PTS_VIA_COUNTER * items, def.id)

func test_personal_best_is_kept_and_never_pays() -> void:
	var d := GameData.fresh()
	var tokens := int(d.tokens)
	var r := Progression.record_score(d, "c001", 120)
	eq(r.best, 120)
	check(not r.new_best, "a first score is not called a new best")
	r = Progression.record_score(d, "c001", 105)
	eq(r.best, 120, "a lower score keeps the best")
	check(not r.new_best)
	r = Progression.record_score(d, "c001", 130)
	check(r.new_best)
	eq(Progression.best_score(d, "c001"), 130)
	eq(int(d.tokens), tokens, "scores never pay tokens")

func test_win_rewards_are_idempotent() -> void:
	var d := GameData.fresh()
	var a := Progression.record_win(d, "c004", 3)
	var b := Progression.record_win(d, "c004", 3)
	eq(int(a.tokens), 3)
	eq(int(b.tokens), 0, "the same result pays nothing twice")
	eq(int(d.tokens), 3)

func test_schema4_save_migrates_to_best_scores() -> void:
	var s := SaveStore.new(DIR + "/v6save.json")
	s.delete_all()
	var v6 := GameData.fresh()
	v6.campaign.erase("best")
	Progression.record_win(v6, "c001", 3)
	Progression.record_win(v6, "c002", 2)
	var payload := JSON.stringify(v6)
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 4, "sha256": payload.sha256_text(), "payload": payload}))
	f.close()
	var d := s.load_data()
	eq(d.campaign.best, {}, "best scores start empty")
	eq(int(d.tokens), 5, "balance untouched")
	eq(int(d.campaign.stars.c002), 2, "stars untouched")
	check(Progression.is_cleared(d, "c001"))
	check(s.backup_written != "", "old file kept before migrating")
	s.save(d)
	var again := SaveStore.new(DIR + "/v6save.json").load_data()
	eq(again.campaign.best, {}, "round-trips at schema 5")

func test_next_action_on_last_levels() -> void:
	var camp: Array = App.progression.campaign
	eq(WinPanel._next_text("campaign", str(camp[0].id)), Loc.t("next_level"))
	eq(WinPanel._next_text("campaign", str(camp[camp.size() - 1].id)), Loc.t("campaign_finish"),
		"the last level leads to the finale")
	var bak: Array = App.progression.bakery
	eq(WinPanel._next_text("bakery", str(bak[bak.size() - 1].id)), Loc.t("bakery_finish"))

func test_full_counter_with_a_delivery_left_is_not_lost() -> void:
	# The owner's level-2 observation: a full counter is not a loss while an
	# order still wants some crate's front item.
	var L := lvl({"counter": 1, "trays": 1, "crates": [["tea", "coffee"], ["coffee"]],
		"orders": [[{"coffee": 2}], [{"tea": 1}]]})
	var s := PuzzleState.create(L)
	Rules.apply_move(s, 0)   # tea parked: counter full
	eq(s.counter_free(), 0)
	check(not Rules.is_lost(s), "coffee can still go to the order")

func test_loss_is_detected_and_retry_is_clean() -> void:
	var L := lvl({"counter": 1, "trays": 1, "crates": [["tea", "croissant"], ["coffee"]],
		"orders": [[{"coffee": 1}], [{"croissant": 1}], [{"tea": 1}]]})
	var ps := PuzzleSession.start(L)
	ps.tap(0)   # tea parked: counter full, croissant now in front, order wants coffee... still legal via crate 1
	check(not ps.is_lost())
	var L2 := lvl({"counter": 1, "trays": 1, "crates": [["tea", "croissant"], ["coffee"]],
		"orders": [[{"croissant": 1}], [{"coffee": 1}], [{"tea": 1}]]})
	var p2 := PuzzleSession.start(L2)
	p2.tap(1)   # coffee parked (order wants croissant): counter full
	check(p2.is_lost(), "tea in front, coffee on the counter, order wants croissant")
	check(not p2.is_won())
	var retry := PuzzleSession.start(L2)
	check(not retry.is_lost() and retry.state.moves == 0 and Scoring.points(retry.state) == 0, "retry is a clean board")
	check(p2.undo() and not p2.is_lost(), "undo recovers")
