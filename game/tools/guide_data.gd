extends SceneTree
## Exports level facts for the player guide's reference appendix and the
## separate solutions appendix, computed from the SHIPPED level files with the
## real rules (Rules / PuzzleSession), so nothing is re-implemented elsewhere.
##   godot --headless --path game -s res://tools/guide_data.gd -- OUT.json
## For every level: mode, display name, objective facts (orders, tickets,
## counter, crates, items), mechanics, unlock rule inputs, and a replay of the
## stored solution (won?, moves, rings, peak counter, stars without undo).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://guide_data.json"
	var prog := Progression.new()
	prog.load_levels()
	var out := {"version": ProjectSettings.get_setting("application/config/version"), "chapters": [], "campaign": [],
		"bakery": [], "daily": [], "ledger": [], "challenges": []}
	for ci in prog.chapters.size():
		var r := prog.chapter_range(ci)
		out.chapters.append({"title": str(prog.chapters[ci].title), "first": r.x + 1, "last": r.y})
	for i in prog.campaign.size():
		var e := _facts(prog.campaign[i])
		e["n"] = i + 1
		e["chapter"] = prog.chapter_of(i)
		out.campaign.append(e)
	for i in prog.bakery.size():
		var e2 := _facts(prog.bakery[i])
		e2["n"] = i + 1
		out.bakery.append(e2)
	for i in prog.daily_pool.size():
		var e3 := _facts(prog.daily_pool[i])
		e3["n"] = i + 1
		out.daily.append(e3)
	for p in Ledger.pages():
		var e4 := _facts(p)
		var info := Ledger.info(p)
		e4["n"] = Ledger.index(p.id) + 1
		e4["group"] = Ledger.group(p)
		e4["name"] = str(info.get("name", ""))
		e4["tagline"] = str(info.get("tagline", ""))
		e4["precision_target"] = int(info.get("precision_target", 0))
		e4["min_rings"] = int(info.get("min_rings", 0))
		e4["min_rings_proved"] = bool(info.get("proof", {}).get("min_rings_proved", false))
		e4["witness_replay"] = bool(info.get("proof", {}).get("witness_replay", false))
		e4["difficulty_estimate"] = int(info.get("difficulty_estimate", 0))
		out.ledger.append(e4)
	for c in Challenges.LIST:
		out.challenges.append({"id": c.id, "level": c.level, "goal": c.goal, "reward": c.reward,
			"tidy_target": Progression.mastery_target(prog.def_for(str(c.level)))})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("guide_data: campaign=%d bakery=%d daily=%d ledger=%d -> %s" % [out.campaign.size(), out.bakery.size(),
		out.daily.size(), out.ledger.size(), out_path])
	quit(0)

func _facts(d: Dictionary) -> Dictionary:
	var def := LevelDef.from_dict(d)
	var items := 0
	for c in def.crates:
		items += (c as PackedInt32Array).size()
	var two := 0
	for o in def.orders:
		if (o as Array).size() > 1:
			two += 1
	var seq: Array = []
	for o in def.sequence:
		seq.append(Customers.for_order(def, o))
	var locks: Array = []
	for i in def.locks.size():
		if def.locks[i] > 0:
			locks.append([i + 1, def.locks[i]])
	var sp := Specials.of(def)
	var e := {
		"id": def.id, "orders": def.orders.size(), "trays": def.trays, "counter": def.counter_slots,
		"crates": def.crates.size(), "items": items, "fresh": def.count_flag(LevelDef.FRESH),
		"bags": def.count_flag(LevelDef.BAG), "locks": locks, "two_stage": two,
		"bell": def.allow_bell, "bell_budget": def.bell_budget, "sequence": seq,
		"tutorial": str(def.meta.get("tutorial", "")), "par_counter": Scoring.par_counter(def),
		"mastery_target": Progression.mastery_target(def),
		"special": {} if sp.is_empty() else {"customer": str(sp.get("customer", "")), "reward": str(sp.get("reward", ""))},
	}
	# Replay the stored solution (ledger: the proven witness) through the rules.
	var path: Array = def.meta.get("ledger", {}).get("witness", def.meta.get("solution", []))
	var ps := PuzzleSession.start(def)
	var ok := true
	var rings := 0
	for a in path:
		var act := int(a)
		var ev: Array
		if act >= 0:
			ev = ps.tap(act)
		else:
			ev = ps.ring(Rules.action_tray(act))
			rings += 1
		if ev.is_empty():
			ok = false
			break
	var sol: Array = []
	for a in path:
		sol.append(int(a))
	e["solution"] = sol
	e["solution_won"] = ok and ps.is_won()
	e["solution_moves"] = sol.size()
	e["solution_rings"] = rings
	e["solution_peak"] = ps.state.peak_counter
	e["solution_stars"] = ps.stars() if ps.is_won() else 0
	return e
