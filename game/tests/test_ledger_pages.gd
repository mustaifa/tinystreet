extends "res://tests/test_base.gd"
## v4 Midnight Ledger: the shipped pages (proof records re-checked against the
## current rules), rewards (once, never tokens), unlocks, resume safety and
## save compatibility with schema 4.

const DIR := "user://test_saves_v4"

func setup_suite(_t: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

func _defs() -> Array:
	var out: Array = []
	for p in Ledger.pages():
		out.append(LevelDef.from_dict(p))
	return out

func test_collection_shape() -> void:
	var groups := {}
	for p in Ledger.pages():
		groups[Ledger.group(p)] = int(groups.get(Ledger.group(p), 0)) + 1
	eq(groups, {"lesson": 3, "puzzle": 9, "final": 1})
	var ids := {}
	for p in Ledger.pages():
		check(not ids.has(p.id), "unique id")
		ids[p.id] = true

## Every recorded proof still holds for the CURRENT rules and content.
func test_witnesses_replay_and_hashes_match() -> void:
	for d in _defs():
		var info: Dictionary = d.meta.ledger
		eq(str(info.proof.content_hash), d.content_hash(), "%s content hash matches its proof" % d.id)
		eq(str(info.proof.solver), Solver.VERSION, "%s proved with this solver version" % d.id)
		var rep := LedgerAnalysis.replay(d, PackedInt32Array(info.witness))
		check(rep.ok and rep.won and rep.sequence_ok and rep.budget_ok, "%s witness replays with all constraints: %s" % [d.id, rep])
		eq(int(rep.rings), int(info.min_rings), "%s witness uses exactly the proven minimum rings" % d.id)

func test_every_order_visible_and_nothing_hidden() -> void:
	for d in _defs():
		check(d.orders.size() <= d.trays + 3, "%s: every order visible at the start" % d.id)
		eq(d.count_flag(LevelDef.BAG), 0, "%s: no hidden items" % d.id)
		eq((d.meta.customers as Array).size(), d.orders.size())
		var uniq := {}
		for c in d.meta.customers:
			uniq[c] = true
		eq(uniq.size(), d.orders.size(), "%s: distinct customers" % d.id)

func test_min_rings_proofs_hold() -> void:
	for d in _defs():
		var mr := LedgerAnalysis.min_rings(d)
		check(mr.proved, "%s min rings proved" % d.id)
		eq(int(mr.min), int(d.meta.ledger.min_rings), "%s min rings" % d.id)

func test_precision_targets_are_proven_minimal() -> void:
	var offered := 0
	for d in _defs():
		var tgt := int(d.meta.ledger.precision_target)
		if tgt <= 0:
			continue
		offered += 1
		eq(tgt, d.total_items() + int(d.meta.ledger.min_rings), "%s: taps are fixed, so target = items + min rings" % d.id)
		check(d.bell_budget < 0 or d.bell_budget > int(d.meta.ledger.min_rings), "%s: the budget allows more rings than the target" % d.id)
		# one fewer ring is impossible: proven by exhaustive search
		eq(Solver.new(400000).solve(PuzzleState.create(d.with_budget(int(d.meta.ledger.min_rings) - 1))).status, Solver.UNSOLVABLE)
	eq(offered, 2, "precision offered on exactly the pages where it is meaningful")

func test_ideas_reverified() -> void:
	for d in _defs():
		var info: Dictionary = d.meta.ledger
		var w := PackedInt32Array(info.witness)
		var tr := LedgerAnalysis.trace(d, w)
		eq(int(tr.unknown), 0, "%s: every alternative classified" % d.id)
		var v := LedgerAnalysis.verify_idea(d, w, tr, LedgerAnalysis.min_rings(d), str(info.idea_tag))
		check(v.ok, "%s idea %s: %s" % [d.id, info.idea_tag, v.evidence])
		check(int(tr.choice_points) >= 2, "%s has real decisions" % d.id)

func test_strings_for_every_page() -> void:
	for p in Ledger.pages():
		for k in ["name", "tagline", "idea", "hint1", "hint2", "why"]:
			var key := str(Ledger.info(p).get(k, ""))
			check(Loc.has_key(key, "en") and Loc.has_key(key, "ar"), "%s.%s string" % [p.id, k])

# ------------------------------------------------------------------ rewards and unlocks

func test_rewards_once_and_no_tokens() -> void:
	var d := GameData.fresh()
	d.tokens = 5
	var id: String = Ledger.pages()[0].id
	var r1 := Ledger.record(d, id, 7, 2)
	check(r1.stamp_new and not r1.nohint_met and not r1.nohint_new)
	var r2 := Ledger.record(d, id, 7, 0)
	check(not r2.stamp_new, "stamp only once")
	check(r2.nohint_new, "improved badge later")
	var r3 := Ledger.record(d, id, 7, 0)
	check(not r3.stamp_new and not r3.nohint_new, "nothing new on repeat")
	eq(int(d.tokens), 5, "the ledger never pays tokens")
	var p3 := Ledger.page("e03")
	var tgt := Ledger.precision_target(p3)
	check(not Ledger.record(d, "e03", tgt + 1, 0).precision_met)
	var rp := Ledger.record(d, "e03", tgt, 0)
	check(rp.precision_met and rp.precision_new)
	check(not Ledger.record(d, "e03", tgt, 0).precision_new, "precision once")

func test_collection_lamp_once() -> void:
	var d := GameData.fresh()
	var last := {}
	for p in Ledger.pages():
		last = Ledger.record(d, p.id, 99, 1)
	check(last.lamp_new, "lamp on the final stamp")
	check(Restoration.owns_extra(d, "lamp"))
	var again := Ledger.record(d, Ledger.pages()[0].id, 1, 0)
	check(not again.lamp_new, "lamp once")
	check(not Restoration.can_buy_extra(d, "lamp"), "lamp can't be bought")

func test_unlock_rules() -> void:
	var d := GameData.fresh()
	check(not Ledger.is_unlocked(d, "e01"), "closed before the bell lesson")
	Progression.record_win(d, "p01", 1)
	check(Ledger.is_unlocked(d, "e01"))
	check(not Ledger.is_unlocked(d, "e02"), "lessons in order")
	check(not Ledger.is_unlocked(d, "e04"), "puzzles after the lessons")
	for id in ["e01", "e02", "e03"]:
		Ledger.record(d, id, 1, 0)
	check(Ledger.is_unlocked(d, "e04") and Ledger.is_unlocked(d, "e12"), "all nine puzzles open")
	check(not Ledger.is_unlocked(d, "e13"))
	for id in ["e04", "e05", "e06", "e07", "e08", "e09"]:
		Ledger.record(d, id, 1, 0)
	check(Ledger.is_unlocked(d, "e13"), "final after six puzzles")

# ------------------------------------------------------------------ sessions and saves

func test_undo_redo_restart_restore_full_state() -> void:
	var d := App.progression.def_for("e09")
	var w := PackedInt32Array(d.meta.ledger.witness)
	var ps := PuzzleSession.start(d)
	for k in 5:
		var a := w[k]
		check(not (ps.tap(a) if a >= 0 else ps.ring(Rules.action_tray(a))).is_empty())
	var key5 := ps.state.key()
	var rings5 := ps.state.rings_used
	ps.undo()
	ps.undo()
	check(ps.can_redo())
	ps.redo()
	ps.redo()
	eq(ps.state.key(), key5, "redo restores the exact state")
	eq(ps.state.rings_used, rings5, "including rings used")
	ps.undo()
	var back := PuzzleSession.restore(d, ps.to_dict())
	eq(back.state.key(), ps.state.key(), "resume rebuilds the state")
	eq(Array(back.redo_log), Array(ps.redo_log), "and the redo stack")
	ps.tap(w[4]) if w[4] >= 0 else ps.ring(Rules.action_tray(w[4]))
	check(not ps.can_redo(), "a new action clears redo")
	var fresh := PuzzleSession.start(d)
	eq(fresh.state.rings_used, 0, "restart: full budget again")

func test_schema4_save_gets_ledger_defaults() -> void:
	var s := SaveStore.new(DIR + "/v3save.json")
	s.delete_all()
	var v3 := GameData.fresh()
	v3.erase("ledger")
	v3.tokens = 12
	Progression.record_win(v3, "p01", 3)
	var payload := JSON.stringify(v3)
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 4, "sha256": payload.sha256_text(), "payload": payload}))
	f.close()
	var d := s.load_data()
	eq(SaveStore.SCHEMA, 4, "no schema bump was needed")
	eq(s.backup_written, "", "no migration, so no backup")
	eq(d.ledger.done, {}, "ledger defaults added")
	eq(int(d.tokens), 15, "v3 balance kept (12 + 3 stars)")
	check(Progression.is_cleared(d, "p01"))
	check(Ledger.is_open(d))
