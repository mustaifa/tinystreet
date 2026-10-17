extends Node
## QA automation, active ONLY when launched with `-- --qa=<scenario>`.
## Drives the real game through real GUI input events and captures
## screenshots from the actual rendered viewport.
##   shots       capture every screen (EN + AR)
##   play=N-M    play campaign levels N..M with solver moves via input events
##   rapid       rapid random tapping; checks state integrity
##   lifecycle_a start a level, make moves, simulate background, hard-exit
##   lifecycle_b relaunch and verify the in-progress puzzle was restored
##   cafe        capture the café at every restoration step and decor variant
##   v2          v2 flows: mechanics, drag, restore via UI, tasks, rush, pause
##   tour        every screen, popup and state, in a fixed order (before/after
##               comparisons; --qa-lang=ar for Arabic)
##   player      v7 new-player journey through REAL taps only (fresh save):
##               first win -> result -> next level, a genuine loss -> retry,
##               undo/restart score checks, taps during the result, replay
##   player_reopen  relaunch on the same save: progress, best scores, Play
##   finale      last campaign level -> "grand finale" action -> home
## Results are printed as lines starting with "QA:".

var scenario := ""
var out_dir := "user://qa"
var frame_times: Array = []
var _measure := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			scenario = a.substr(5)
		if a.begins_with("--qa-out="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	OS.low_processor_usage_mode = false  # keep frames flowing for captures
	_run.call_deferred()

func _process(delta: float) -> void:
	if _measure:
		frame_times.append(delta)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("QA: shot ", name)

## `pos` is in canvas coordinates; input events need window coordinates.
func click(canvas_pos: Vector2) -> void:
	var pos: Vector2 = get_tree().root.get_final_transform() * canvas_pos
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	await _frames(1)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)

func game() -> Node:
	return App.main.current

func tap_crate(i: int) -> void:
	var g := game()
	var cv: CrateView = g.crate_views[i]
	await click(cv.get_global_rect().get_center())

## Plays one solver action through real input: a crate tap, or a tap on the
## order ticket for a bell ring (v3).
func act(a: int) -> void:
	if a >= 0:
		await tap_crate(a)
	else:
		var oc: OrderCard = game().order_cards[Rules.action_tray(a)]
		await click(oc.get_global_rect().get_center())

func _run() -> void:
	await _wait(1.5)
	if scenario == "shots":
		await _shots()
	elif scenario.begins_with("play="):
		var r := scenario.substr(5).split("-")
		await _play(int(r[0]), int(r[1]))
	elif scenario == "layouts":
		await _layouts()
	elif scenario == "nav":
		await _nav()
	elif scenario == "rewards":
		await _rewards()
	elif scenario == "icon":
		await _icon()
	elif scenario == "rapid":
		await _rapid()
	elif scenario == "lifecycle_a":
		await _lifecycle_a()
	elif scenario == "lifecycle_b":
		await _lifecycle_b()
	elif scenario == "cafe":
		await _cafe()
	elif scenario == "v2":
		await _v2()
	elif scenario == "slice":
		await _slice()
	elif scenario == "v3":
		await _v3()
	elif scenario == "ledger":
		await _ledger()
	elif scenario == "tour":
		await _tour()
	elif scenario == "player":
		await _player()
	elif scenario == "player_reopen":
		await _player_reopen()
	elif scenario == "finale":
		await _finale()
	elif scenario.begins_with("dl_"):
		var qd = load("res://src/app/qa_delivery.gd")
		if qd is GDScript and qd.can_instantiate():
			await qd.new(self).run(scenario)
		else:
			print("QA: FAIL qa_delivery.gd did not load")
	print("QA: done ", scenario)
	get_tree().quit()

# ------------------------------------------------------------------ scenarios

func _shots() -> void:
	for lang in ["en", "ar"]:
		App.set_setting("lang", lang)
		await _wait(0.3)
		App.main.goto("game", {"kind": "campaign", "id": "c001"}, false)
		await _wait(0.6)
		await shot(lang + "_01_tutorial")
		await tap_crate(game().ps.compute_hint().crate)
		await _wait(0.1)
		await shot(lang + "_02_move_anim")
		App.main.goto("game", {"kind": "campaign", "id": "c003"}, false)
		await _wait(0.5)
		await shot(lang + "_03_two_trays")
		var g := game()
		for c in Solver.new().solve(g.ps.state).path:
			await tap_crate(c)
			await _wait(0.05)
		await _wait(1.0)
		await shot(lang + "_04_win")
		App.data.tokens = 20
		App.data.restoration.steps = 3
		App.main.goto("restore", {}, false)
		await _wait(0.4)
		await shot(lang + "_05_restore")
		App.main.goto("home", {}, false)
		await _wait(0.4)
		await shot(lang + "_06_home")
		for id in ["f01", "b01", "k01", "x05"]:
			App.data.tutorial.done.erase("tut_" + {"f": "fresh", "b": "bag", "k": "lock", "x": ""}[id[0]])
			App.main.goto("game", {"kind": "campaign", "id": id}, false)
			await _wait(0.3)
			App.main.close_all_overlays()
			var gg := game()
			var sol: Array = gg.def.meta.solution
			for k in mini(2, sol.size()):
				await tap_crate(int(sol[k]))
				await _wait(0.05)
			await _wait(0.7)
			await shot(lang + "_09_mech_" + id)
		App.main.goto("home", {}, false)
		App.data.story.seen.erase("lvl:c016")
		Story.level_start("c016")
		await _wait(0.6)
		await shot(lang + "_10_story")
		App.main.close_all_overlays()
		App.data.stats.wins = 3
		for t in ["tasks", "achievements", "progress"]:
			App.main.goto("journal", {"tab": t}, false)
			await _wait(0.4)
			await shot(lang + "_11_journal_" + t)
		for s in ["levels", "daily", "settings", "help", "credits", "privacy", "shop"]:
			App.main.goto(s, {}, false)
			await _wait(0.4)
			await shot(lang + "_07_" + s)
		App.main.goto("game", {"kind": "campaign", "id": "c002"}, false)
		await _wait(0.3)
		App.main.current._open_pause()
		await _wait(0.4)
		await shot(lang + "_08_pause")
	App.set_setting("lang", "en")

func _play(from: int, to: int) -> void:
	var ok := 0
	var fail := 0
	_measure = true
	for n in range(from, to + 1):
		var id: String = App.progression.campaign[n - 1].id
		App.main.goto("game", {"kind": "campaign", "id": id}, false)
		await _wait(0.3)
		App.main.close_all_overlays() # story bubbles
		var g := game()
		var path: Array = g.def.meta.get("solution", [])
		for c in path:
			await act(int(c))
			await _wait(0.08)
		await _wait(0.8)
		if g.ps.is_won() and Progression.is_cleared(App.data, id):
			ok += 1
		else:
			fail += 1
			print("QA: FAIL level ", id, " moves=", g.ps.state.moves)
	_measure = false
	print("QA: play %d-%d won=%d failed=%d tokens=%d" % [from, to, ok, fail, App.data.tokens])
	_report_frames()

func _rapid() -> void:
	App.main.goto("game", {"kind": "campaign", "id": App.progression.campaign[min(20, App.progression.campaign.size() - 1)].id}, false)
	await _wait(0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_measure = true
	var taps := 0
	for i in 400:
		var g := game()
		if g.ps.is_won() or g.ps.is_lost():
			if g.ps.can_undo():
				g._on_undo()
			else:
				g._on_restart()
			App.main.close_all_overlays()
		var cv: CrateView = g.crate_views[rng.randi_range(0, g.crate_views.size() - 1)]
		var p: Vector2 = get_tree().root.get_final_transform() * cv.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = p
		Input.parse_input_event(down)
		var up := down.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		taps += 1
		if i % 3 == 0:
			await _frames(1)
		if i % 50 == 25:
			g._on_undo()
	await _wait(1.0)
	_measure = false
	var g2 := game()
	var replay := PuzzleSession.start(g2.def)
	for m in g2.ps.moves_log:
		replay.tap(m)
	var consistent: bool = replay.state.key() == g2.ps.state.key()
	print("QA: rapid taps=%d moves=%d consistent=%s fx_left=%d" % [taps, g2.ps.state.moves, consistent, g2._fx_nodes.size()])
	_report_frames()

func _lifecycle_a() -> void:
	App.main.goto("game", {"kind": "campaign", "id": "c005"}, false)
	await _wait(0.4)
	var g := game()
	var path: Array = g.def.meta.solution
	for k in 3:
		await tap_crate(int(path[k]))
		await _wait(0.1)
	g._on_undo()
	await tap_crate(int(path[2]))
	App._notification(NOTIFICATION_APPLICATION_PAUSED)
	print("QA: lifecycle_a key=", g.ps.state.key(), " undos=", g.ps.undo_count)
	# hard exit without a close request (simulates process termination)
	OS.kill(OS.get_process_id())

func _lifecycle_b() -> void:
	var cur: Dictionary = App.data.current
	print("QA: lifecycle_b current=", cur.get("id", "none"), " moves=", cur.get("session", {}).get("moves", []))
	App.main.goto("game", {"kind": "campaign", "id": "c005"}, false)
	await _wait(0.4)
	var g := game()
	print("QA: lifecycle_b key=", g.ps.state.key(), " undos=", g.ps.undo_count)

func _layouts() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--qa-large-text":
			App.set_setting("large_text", true)
	var tag := "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-tag="):
			tag = a.substr(9)
	for id in ["c031", "c052", "c060", "x06"]:
		App.main.goto("game", {"kind": "campaign", "id": id}, false)
		await _wait(0.5)
		App.main.close_all_overlays()
		var g := game()
		var path: Array = g.def.meta.solution
		for k in mini(5, path.size()):
			await tap_crate(int(path[k]))
			await _wait(0.05)
		await _wait(0.6)
		await shot("%s_%s" % [tag, id])
	App.data.restoration.steps = 8
	App.data.restoration.choices = {"walls": "sage", "floor": "checker", "seating": "rattan", "plants": "flowers", "sign": "block", "lights": "string"}
	App.data.restoration.extras = {"cat": true, "clock": true, "gramophone": true, "cakestand": true}
	App.main.goto("home", {}, false)
	await _wait(0.5)
	await shot("%s_home_done" % tag)

## The café at every restoration step, then decor variants and extras.
func _cafe() -> void:
	for st in 9:
		App.data.restoration.steps = st
		App.data.restoration.choices = {}
		App.data.restoration.extras = {}
		App.main.goto("home", {}, false)
		await _wait(0.4)
		await shot("cafe_step_%d" % st)
	var variants := [
		{"walls": "sage", "floor": "checker", "counter": "marble", "lights": "string", "seating": "rattan", "plants": "olive", "sign": "block"},
		{"walls": "blush", "floor": "terracotta", "counter": "teal", "lights": "globe", "seating": "booth", "plants": "flowers", "sign": "painted"},
	]
	for i in variants.size():
		App.data.restoration.steps = 8
		App.data.restoration.choices = variants[i]
		App.data.restoration.extras = {"cat": true, "clock": true, "gramophone": true, "cakestand": true} if i == 1 else {}
		App.data.stats.cast = {"theo": 20, "basil": 20, "mira": 20} if i == 1 else {}
		App.main.goto("home", {}, false)
		await _wait(0.4)
		await shot("cafe_variant_%d" % i)

## v2 flows through real input where it matters.
func _v2() -> void:
	App.data.tutorial.done = {"tut_tap": true, "tut_counter": true, "tut_priority": true}
	# 1. Fresh item refusal through a real tap: f01 crate 1 front is fresh coffee.
	App.main.goto("game", {"kind": "campaign", "id": "f01"}, false)
	await _wait(0.4)
	App.main.close_all_overlays()
	var g := game()
	await tap_crate(1)
	await _wait(0.2)
	_expect(g.ps.state.moves == 0 and g.ps.state.counter_used() == 0, "fresh item refused (no counter parking)")
	_expect(g.status_label.text == Loc.t("invalid_fresh"), "fresh refusal explained")
	# 2. Drag: press on crate 0, drag to its order ticket, release -> move.
	var cv: CrateView = g.crate_views[0]
	var from: Vector2 = cv.get_global_rect().get_center()
	var to: Vector2 = g.order_cards[0].get_global_rect().get_center()
	await _drag(from, to)
	await _wait(0.3)
	_expect(g.ps.state.moves == 1, "drag to destination makes the move")
	# 3. Drag away and release elsewhere cancels.
	var cv2: CrateView = g.crate_views[2]
	await _drag(cv2.get_global_rect().get_center(), Vector2(40, 200))
	await _wait(0.2)
	_expect(g.ps.state.moves == 1, "drag away cancels")
	# 4. Pause during an animation, resume, state intact.
	await tap_crate(2)
	g._open_pause()
	await _wait(0.2)
	App.main.close_all_overlays()
	var replay := PuzzleSession.start(g.def)
	for m in g.ps.moves_log:
		replay.tap(m)
	_expect(replay.state.key() == g.ps.state.key() and g._fx_nodes.is_empty(), "pause mid-animation keeps state and clears effects")
	# 5. Locks: k01 crate 2 refuses until two deliveries.
	App.main.goto("game", {"kind": "campaign", "id": "k01"}, false)
	await _wait(0.4)
	App.main.close_all_overlays()
	g = game()
	await tap_crate(2)
	_expect(g.ps.state.moves == 0, "locked crate refused")
	for c in g.def.meta.solution:
		await tap_crate(int(c))
		await _wait(0.05)
	await _wait(1.2)
	_expect(g.ps.is_won(), "k01 solved through taps")
	# 6. Restore through the UI: buy step 1 with a double tap, spend once.
	App.main.close_all_overlays()
	App.data.restoration.steps = 0
	App.data.tokens = 3 + 5
	App.main.goto("restore", {}, false)
	await _wait(0.4)
	var scr = App.main.current
	scr._unlock()
	scr._unlock()
	await _wait(0.6)
	App.main.close_all_overlays()
	_expect(Restoration.steps(App.data) == 1 and int(App.data.tokens) == 5, "double-tap restore spends once")
	await shot("v2_restore_after")
	# 7. Tasks: claim twice -> once.
	App.data.tasks = {"date": Progression.today_key(), "list": ["wins", "orders", "three_star"], "base": {"wins": 0, "orders": 0, "three_star": 0}}
	App.data.stats.wins = 5
	var before := int(App.data.tokens)
	App.main.goto("journal", {"tab": "tasks"}, false)
	await _wait(0.3)
	App.main.current._claim_task("wins")
	App.main.current._claim_task("wins")
	_expect(int(App.data.tokens) == before + 2, "task claimed once")
	# 8. Rush: three puzzles through taps, best time recorded.
	App.main.goto("daily", {}, false)
	await _wait(0.3)
	App.main.current._start_rush()
	for k in RushRun.LENGTH:
		await _wait(0.5)
		var rg := game()
		for c in rg.def.meta.solution:
			await tap_crate(int(c))
			await _wait(0.03)
		await _wait(1.5)
	_expect(int(App.data.stats.rush_done) >= 1 and int(App.data.stats.rush_best_ms) > 0, "rush finished and timed")
	await shot("v2_rush_done")
	App.main.close_all_overlays()

## v3 slice p01..p12 through real input, with screenshots at key moments.
func _slice() -> void:
	App.data.tutorial.done = {"tut_tap": true, "tut_counter": true, "tut_priority": true, "tut_fresh": true}
	for id in ["c001", "c002", "c003", "c004", "c005", "c006", "f01", "c007"]:
		Progression.record_win(App.data, id, 3)
	App.data.stats.wins = 8
	var ok := 0
	for n in range(1, 13):
		var id := "p%02d" % n
		App.main.goto("game", {"kind": "campaign", "id": id}, false)
		await _wait(0.5)
		if n == 1 or n == 6 or n == 12:
			await shot("slice_%s_story" % id)
		App.main.close_all_overlays()
		await _wait(0.2)
		var g := game()
		if n == 1:
			await shot("slice_p01_start")
		var path: Array = g.def.meta.solution
		for k in path.size():
			var a := int(path[k])
			if n == 1 and a < 0:
				await shot("slice_p01_before_ring")
			await act(a)
			await _wait(0.12)
			if n == 1 and a < 0:
				await _wait(0.3)
				await shot("slice_p01_after_ring")
			if n == 6 and k == 6:
				await _wait(0.5)
				await shot("slice_p06_special")
		await _wait(1.4)
		if n == 6 or n == 12:
			await shot("slice_%s_win" % id)
		App.main.close_all_overlays()
		await _wait(0.3)
		App.main.close_all_overlays()
		if g.ps.is_won() and Progression.is_cleared(App.data, id):
			ok += 1
		else:
			print("QA: FAIL slice ", id)
	_expect(ok == 12, "slice p01-p12 won through input (%d/12)" % ok)
	_expect(Restoration.owns_extra(App.data, "chalkboard"), "p06 special reward: chalkboard")
	_expect(bool(App.data.bakery.unlocked), "p12 special reward: bakery unlocked")
	var before := int(App.data.tokens)
	Specials.on_win(App.data, App.progression.def_for("p06"))
	_expect(int(App.data.tokens) == before and Wallet.has_grant(App.data, "special:p06"), "special reward once")
	App.main.goto("levels", {}, false)
	await _wait(0.5)
	await shot("slice_levels")

## v3: café life, customization preview/keep/revert, challenge cards, bakery.
func _v3() -> void:
	App.data.tutorial.done = {"tut_tap": true, "tut_counter": true, "tut_priority": true, "tut_fresh": true, "tut_bell": true}
	App.data.story.seen = {"intro": true, "first_served": true}
	# --- café life at several moments of the visit cycle
	App.data.restoration.steps = 6
	App.data.restoration.choices = {}
	App.data.restoration.extras = {"chalkboard": true}
	App.main.goto("home", {}, false)
	await _wait(0.4)
	var cafe: CafeView = App.main.current.cafe
	for t in [1.5, 4.8, 7.0]:
		cafe._t = t
		cafe.queue_redraw()
		await shot("v3_cafe_t%d" % int(t * 10))
	_expect(not cafe._visit_state().is_empty(), "a visitor is in the café once the counter is restored")
	cafe.cheer()
	await shot("v3_cafe_cheer")
	# --- customization: theme preview, revert, keep
	App.data.tokens = 40
	App.main.goto("restore", {}, false)
	await _wait(0.4)
	var rs = App.main.current
	var before := Restoration.effective_choices(App.data)
	rs._preview = Restoration.theme_choices(App.data, "parisian")
	rs._refresh_cafe()
	rs._fill_panel()
	await _wait(0.3)
	await shot("v3_restore_theme_preview")
	_expect(Restoration.effective_choices(App.data) == before, "preview saves nothing")
	rs._revert()
	_expect(Restoration.effective_choices(App.data) == before and rs.cafe.choices == before, "revert restores the saved look")
	rs._preview = Restoration.theme_choices(App.data, "garden")
	rs._keep()
	_expect(Restoration.current_theme(App.data) == "garden", "keep saves the theme")
	var tok := int(App.data.tokens)
	rs._try("walls", "blush")
	rs._keep()
	_expect(int(App.data.tokens) == tok and Restoration.choice(App.data, "walls") == "blush", "switching owned choices is free")
	rs._preview_extra = "cat"
	rs._refresh_cafe()
	rs._fill_panel()
	await _wait(0.3)
	await shot("v3_restore_extra_preview")
	_expect(not Restoration.owns_extra(App.data, "cat"), "extra preview doesn't buy")
	rs._revert()
	# --- challenge card
	Progression.record_win(App.data, "p01", 3)
	App.main.goto("daily", {}, false)
	await _wait(0.4)
	await shot("v3_challenges")
	App.main.goto("game", {"kind": "challenge", "id": "d004", "challenge": "ch01"}, false)
	await _wait(0.4)
	App.main.close_all_overlays()
	var g := game()
	var tok2 := int(App.data.tokens)
	for c in g.def.meta.solution:
		await act(int(c))
		await _wait(0.05)
	await _wait(1.4)
	await shot("v3_challenge_win")
	_expect(Challenges.is_done(App.data, "ch01") and int(App.data.tokens) == tok2 + 2, "challenge pays its reward")
	_expect(Challenges.record(App.data, "ch01", true).tokens == 0, "challenge reward pays once")
	App.main.close_all_overlays()
	# --- bakery: unlock, first visit beat, a step, the oven level
	App.data.bakery.unlocked = true
	App.data.tokens = 30
	App.main.goto("home", {}, false)
	await _wait(0.4)
	await shot("v3_home_bakery_door")
	App.main.goto("bakery", {}, false)
	await _wait(0.6)
	await shot("v3_bakery_intro")
	App.main.close_all_overlays()
	var bs = App.main.current
	bs._unlock()
	await _wait(0.5)
	bs._unlock()
	await _wait(0.5)
	_expect(Bakery.steps(App.data) == 2 and int(App.data.tokens) == 30 - 16, "two bakery steps bought once each")
	await shot("v3_bakery_steps2")
	App.main.goto("game", {"kind": "bakery", "id": "m01"}, false)
	await _wait(0.5)
	App.main.close_all_overlays()
	g = game()
	await tap_crate(2)
	_expect(g.ps.state.moves == 0, "oven closed until the first order")
	await shot("v3_bakery_oven")
	for c in g.def.meta.solution:
		await act(int(c))
		await _wait(0.06)
	await _wait(1.4)
	_expect(g.ps.is_won() and Progression.is_cleared(App.data, "m01"), "bakery level won through input")
	App.main.close_all_overlays()
	App.data.bakery.steps = 4
	App.data.bakery.choices = {"awning": "mint", "shelf": "whitewash", "bsign": "whisk"}
	App.main.goto("bakery", {}, false)
	await _wait(0.5)
	await shot("v3_bakery_done")

## v4 Midnight Ledger through the real UI.
func _ledger() -> void:
	App.data.tutorial.done = {"tut_tap": true, "tut_counter": true, "tut_priority": true, "tut_fresh": true, "tut_bell": true}
	App.data.story.seen = {"intro": true, "first_served": true}
	Progression.record_win(App.data, "p01", 3)
	App.main.goto("home", {}, false)
	await _wait(0.4)
	await shot("ledger_home_offer")
	App.main.goto("daily", {}, false)
	await _wait(0.4)
	await shot("ledger_challenges_entry")
	App.main.goto("ledger", {}, false)
	await _wait(0.4)
	await shot("ledger_list")
	_expect(bool(App.data.ledger.offer_seen), "visiting the ledger retires the home invitation")
	# --- e01: budget enforcement, then solve through input
	App.main.goto("game", {"kind": "ledger", "id": "e01"}, false)
	await _wait(0.5)
	var g := game()
	await shot("ledger_e01_start")
	g.ledger.show_rules()
	await _wait(0.3)
	await shot("ledger_rules_card")
	App.main.close_all_overlays()
	await _wait(0.15)
	var w: Array = g.def.meta.ledger.witness
	for a in w:
		await act(int(a))
		await _wait(0.06)
		if int(a) < 0:
			# budget spent: another ring is refused with a message
			await act(Rules.bell_action(0))
			_expect(g.ps.state.rings_used == 1 and g.status_label.text == Loc.t("invalid_no_rings"), "bell budget enforced in the UI")
	await _wait(1.4)
	await shot("ledger_e01_won")
	_expect(Ledger.is_done(App.data, "e01") and bool(App.data.ledger.nohint.get("e01", false)), "stamp + no-hint badge")
	App.main.close_all_overlays()
	await _wait(0.15)
	_expect(Array(g.ps.moves_log) == Array(PackedInt32Array(g.def.meta.ledger.witness)), "played the reference route")
	g.ledger._why()
	await _wait(0.3)
	await shot("ledger_why")
	_expect(App.main.overlays.size() == 1, "why panel shown")
	App.main.close_all_overlays()
	await _wait(0.15)
	# --- e02: sequence refusal, hints, wrong turn and recovery, redo
	Ledger.record(App.data, "e01", 99, 1)
	App.main.goto("game", {"kind": "ledger", "id": "e02"}, false)
	await _wait(0.5)
	g = game()
	# crate 2's croissant would feed Mr. Basil's ticket (allowed), so find a tap the sequence refuses
	var refused := -1
	for c in g.def.crates.size():
		if Rules.preview(g.ps.state, c).block == Rules.Block.SEQUENCE:
			refused = c
	if refused >= 0:
		await tap_crate(refused)
		_expect(g.ps.state.moves == 0 and g.status_label.text.begins_with(Loc.t("invalid_sequence", ["X"]).split("X")[0]), "sequence refusal explained")
	g._on_hint()
	await _wait(0.3)
	await shot("ledger_hint1")
	App.main.close_all_overlays()
	await _wait(0.15)
	g.ledger._show_stage(2)
	await _wait(0.3)
	await shot("ledger_hint2")
	App.main.close_all_overlays()
	await _wait(0.15)
	g.ledger._show_stage(3)
	await _wait(0.4)
	await shot("ledger_hint3")
	App.main.close_all_overlays()
	await _wait(0.15)
	_expect(g.hint_crate == int(g.def.meta.ledger.witness[0]), "stage 3 = the verified next move")
	# a proven dead end: feed ticket 2 early (croissant from crate 2)
	await tap_crate(1)
	await _wait(0.2)
	var st := LedgerAnalysis.status(g.ps.state)
	_expect(st == Solver.UNSOLVABLE, "a wrong turn is proven unsolvable")
	g.ledger._show_stage(3)
	await _wait(1.5)
	await shot("ledger_stuck_hint")
	_expect(App.main.overlays.size() >= 1, "stuck position offers recovery")
	App.main.close_all_overlays()
	await _wait(0.15)
	g.ledger._undo_n(g.ledger._witness_checkpoint())
	_expect(g.ps.moves_log.size() == 0, "recovered to a point on the proven solution")
	await tap_crate(int(g.def.meta.ledger.witness[0]))
	g._on_undo()
	g.hint_crate = 0
	g.hint_bell = 0
	g._on_redo()
	_expect(g.ps.moves_log.size() == 1, "redo re-applies")
	_expect(g.hint_crate == -1 and g.hint_bell == -1, "redo clears the old hint")
	# restart keeps the page's hint count (no-hint badge) and drops the bell hint
	var hints_before: int = g.ps.hints_used
	g.hint_bell = 0
	g._on_restart()
	await _wait(0.2)
	_expect(g.ps.hints_used == hints_before and hints_before >= 3, "restart keeps hint stages opened")
	_expect(g.hint_bell == -1 and not g.order_cards[0].hint_glow, "restart clears the bell hint")
	await tap_crate(int(g.def.meta.ledger.witness[0]))
	# --- resume: leave and come back
	g.persist()
	App.main.goto("ledger", {}, false)
	await _wait(0.3)
	App.main.goto("game", {"kind": "ledger", "id": "e02"}, false)
	await _wait(0.4)
	_expect(game().ps.moves_log.size() == 1, "resume restores the attempt")
	# a changed page (hash mismatch) is not resumed
	App.main.goto("ledger", {}, false)
	await _wait(0.2)
	App.data.current.hash = "stale"
	App.main.goto("game", {"kind": "ledger", "id": "e02"}, false)
	await _wait(0.4)
	_expect(game().ps.moves_log.size() == 0, "stale saved attempt is set aside")
	# --- final page and collection lantern
	for p in Ledger.pages():
		if p.id != "e13":
			Ledger.record(App.data, p.id, 99, 1)
	App.main.goto("game", {"kind": "ledger", "id": "e13"}, false)
	await _wait(0.5)
	g = game()
	await shot("ledger_final_start")
	for a in g.def.meta.ledger.witness:
		await act(int(a))
		await _wait(0.05)
	await _wait(1.4)
	await shot("ledger_final_won")
	_expect(Restoration.owns_extra(App.data, "lamp"), "lantern for the full collection")
	var tok := int(App.data.tokens)
	g._on_restart()
	_expect(int(App.data.tokens) == tok, "restart grants nothing")
	App.main.close_all_overlays()
	await _wait(0.15)
	App.data.restoration.steps = 8
	App.main.goto("home", {}, false)
	await _wait(0.5)
	await shot("ledger_lantern_cafe")

func _drag(from: Vector2, to: Vector2) -> void:
	var tf := get_tree().root.get_final_transform()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = tf * from
	down.global_position = down.position
	Input.parse_input_event(down)
	await _frames(2)
	for i in range(1, 9):
		var mv := InputEventMouseMotion.new()
		mv.position = tf * from.lerp(to, i / 8.0)
		mv.global_position = mv.position
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
		await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = tf * to
	up.global_position = up.position
	Input.parse_input_event(up)
	await _frames(2)

func _expect(cond: bool, what: String) -> void:
	print("QA: %s %s" % ["PASS" if cond else "FAIL", what])

func _stack() -> String:
	return ",".join(App.main.stack.map(func(e): return e.name))

## Rewarded continue + hint through the real UI with the simulated ad service.
func _rewards() -> void:
	var ads: SimulatedAdService = App.ads
	# Find a dead-end: play random legal moves on c020 until lost.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lost := false
	for attempt in 40:
		App.main.goto("game", {"kind": "campaign", "id": "c020"}, false)
		await _wait(0.3)
		var g := game()
		if attempt > 0:
			g._on_restart()
		while not g.ps.is_won() and not g.ps.is_lost():
			var lm := Rules.legal_moves(g.ps.state)
			g.tap(lm[rng.randi_range(0, lm.size() - 1)])
		if g.ps.is_lost():
			lost = true
			break
	_expect(lost, "reached a lost state")
	await _wait(1.0)
	_expect(App.main.overlays.size() == 1, "loss dialog shown")
	var g2 := game()
	var slots_before: int = g2.ps.state.counter.size()
	ads.auto_resolve = "cancel"
	App.rewards.request("continue", func(): g2.ps.grant_continue())
	await _wait(0.3)
	_expect(g2.ps.state.counter.size() == slots_before, "cancelled ad grants nothing")
	ads.auto_resolve = "earn"
	App.rewards.request("continue", func(): g2.ps.grant_continue())
	await _wait(0.3)
	_expect(g2.ps.state.counter.size() == slots_before + 1, "earned ad grants one slot")
	App.rewards.request("continue", func(): g2.ps.grant_continue())
	await _wait(0.3)
	_expect(g2.ps.state.counter.size() == slots_before + 1, "second continue refused (max one)")
	App.main.close_all_overlays()
	g2._on_restart()
	g2._on_hint()
	await _wait(2.0)
	_expect(g2.hint_crate >= 0 and g2.free_hints == 0, "free hint highlights a crate")
	var before_hints: int = g2.ps.hints_used
	g2._on_hint()     # no free hint: offers ad dialog
	await _wait(0.3)
	_expect(App.main.overlays.size() == 1, "second hint offers optional ad")
	App.main.close_all_overlays()
	App.rewards.request("hint", func(): g2._run_hint(false))
	await _wait(2.0)
	_expect(g2.ps.hints_used == before_hints + 1, "ad hint granted after reward")
	ads.auto_resolve = ""

## Android back behaviour and navigation stack.
func _nav() -> void:
	App.main.goto("home", {}, false)
	await _wait(0.3)
	App.main.goto("game", {"kind": "campaign", "id": "c004"})
	await _wait(0.4)
	_expect(App.main.overlays.size() == 1, "c004 opens with Theo's story bubble")
	App.main.handle_back()           # back skips the story
	await _wait(0.2)
	_expect(App.main.overlays.is_empty() and App.main.current_name() == "game", "back skips the story, stays in game")
	await tap_crate(int(game().def.meta.solution[0]))
	App.main.handle_back()           # back in game -> pause overlay
	await _wait(0.3)
	_expect(App.main.overlays.size() == 1 and App.main.current_name() == "game", "back in game opens pause")
	App.main.handle_back()           # back again closes pause
	await _wait(0.2)
	_expect(App.main.overlays.is_empty(), "back closes overlay")
	game()._leave()
	await _wait(0.3)
	_expect(_stack() == "home,levels", "pause->level map lands on levels (stack %s)" % _stack())
	_expect(App.data.current.get("id", "") == "c004", "progress kept for continue")
	App.main.handle_back()
	await _wait(0.3)
	_expect(_stack() == "home", "back from levels -> home")
	App.main.handle_back()
	await _wait(0.3)
	_expect(App.main.overlays.size() == 1, "back on home asks before exit")
	App.main.close_all_overlays()
	for s in ["settings", "help", "credits", "privacy", "daily", "restore", "shop", "journal"]:
		App.main.goto(s)
		await _wait(0.2)
		App.main.handle_back()
		await _wait(0.2)
		_expect(_stack() == "home", "back from %s -> home" % s)
	App.main.goto("game", {"kind": "campaign", "id": "c004"})
	await _wait(0.4)
	_expect(game().ps.state.moves == 1, "continue restores in-progress move")

## Renders launcher icon layers from the game's own vector art.
func _icon() -> void:
	for layer in ["full", "fg", "bg"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(432, 432) if layer != "full" else Vector2i(512, 512)
		vp.transparent_bg = layer != "bg"
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var art := IconArt.new()
		art.layer = layer
		art.size = Vector2(vp.size)
		vp.add_child(art)
		add_child(vp)
		await _frames(4)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir.path_join("icon_%s.png" % layer))
		vp.queue_free()
	print("QA: icons written")

class IconArt extends Control:
	var layer := "full"
	func _draw() -> void:
		var s := size.x
		if layer != "fg":
			var sb := StyleBoxFlat.new()
			sb.bg_color = Style.TEAL
			sb.set_corner_radius_all(int(s * 0.22) if layer == "full" else 0)
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
			draw_circle(size / 2 + Vector2(0, s * 0.03), s * (0.36 if layer == "full" else 0.3), Style.CREAM)
		if layer != "bg":
			var k := 1.0 if layer == "full" else 0.8
			ProductArt.draw_vector(self, Products.COFFEE, size / 2 + Vector2(-s * 0.02, s * 0.03), s * 0.56 * k)

func _report_frames() -> void:
	if frame_times.is_empty():
		return
	var s := frame_times.duplicate()
	s.sort()
	var avg := 0.0
	for t in s:
		avg += t
	avg /= s.size()
	print("QA: frames n=%d avg=%.1fms p95=%.1fms max=%.1fms" % [s.size(), avg * 1000, s[int(s.size() * 0.95)] * 1000, s.back() * 1000])
	frame_times.clear()

## Every player-facing screen and popup in a fixed order, from a staged save.
## Names are stable so before/after shots line up.
func _tour() -> void:
	var lang := "en"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-lang="):
			lang = a.substr(10)
		if a == "--qa-large-text":
			App.set_setting("large_text", true)
	App.set_setting("lang", lang)
	await _wait(0.3)
	# --- a brand-new player
	App.main.goto("home", {}, false)
	await _wait(0.5)
	await shot("t01_home_new")
	App.main.goto("levels", {}, false)
	await _wait(0.5)
	await shot("t02_levels_new")
	App.main.goto("game", {"kind": "campaign", "id": "c001"}, false)
	await _wait(0.7)
	await shot("t03_game_tutorial")
	# --- a returning player, mid-campaign
	App.data.tutorial.done = {"tut_tap": true, "tut_counter": true, "tut_priority": true, "tut_fresh": true, "tut_bell": true, "tut_bag": true, "tut_lock": true, "tut_two_stage": true}
	App.data.story.seen = {"intro": true, "first_served": true}
	for i in 30:
		var lid: String = App.progression.campaign[i].id
		Progression.record_win(App.data, lid, 3 if i % 4 != 1 else 2)
		if i % 5 == 0:
			App.data.campaign.mastery[lid] = true
	App.data.tokens = 23
	App.data.restoration.steps = 4
	App.main.goto("home", {}, false)
	await _wait(0.6)
	await shot("t04_home_mid")
	App.main.goto("levels", {}, false)
	await _wait(0.6)
	await shot("t05_levels_mid")
	App.main.goto("game", {"kind": "campaign", "id": "c031"}, false)
	await _wait(0.6)
	App.main.close_all_overlays()
	var g := game()
	var sol: Array = g.def.meta.solution
	for k in mini(4, sol.size()):
		await tap_crate(int(sol[k]))
		await _wait(0.08)
	await _wait(0.7)
	await shot("t06_game_mid")
	# selection / pressed feedback while a crate is held
	var cv: CrateView = g.crate_views[int(sol[4])] if sol.size() > 4 else g.crate_views[0]
	var tf := get_tree().root.get_final_transform()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = tf * cv.get_global_rect().get_center()
	down.global_position = down.position
	Input.parse_input_event(down)
	await _wait(0.5)
	await shot("t07_game_hold")
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.8)
	for id in ["p01", "f01", "k01", "b01", "x05"]:
		App.main.goto("game", {"kind": "campaign", "id": id}, false)
		await _wait(0.5)
		App.main.close_all_overlays()
		g = game()
		var s2: Array = g.def.meta.solution
		for k in mini(2, s2.size()):
			await act(int(s2[k]))
			await _wait(0.08)
		await _wait(0.8)
		await shot("t08_game_" + id)
	App.main.goto("game", {"kind": "campaign", "id": "c002"}, false)
	await _wait(0.5)
	g = game()
	g._open_pause()
	await _wait(0.4)
	await shot("t09_pause")
	App.main.close_all_overlays()
	await _wait(0.1)
	g._show_lost()
	await _wait(0.5)
	await shot("t10_lost")
	App.main.close_all_overlays()
	App.main.goto("game", {"kind": "campaign", "id": "c003"}, false)
	await _wait(0.5)
	g = game()
	for c in Solver.new().solve(g.ps.state).path:
		await act(c)
		await _wait(0.05)
	await _wait(1.6)
	await shot("t11_win")
	App.main.close_all_overlays()
	# --- restoration
	App.data.tokens = 40
	App.main.goto("restore", {}, false)
	await _wait(0.6)
	await shot("t12_restore")
	App.main.current._unlock()
	await _wait(2.5)
	await shot("t13_restore_after_unlock")
	App.main.close_all_overlays()
	await _wait(0.2)
	App.main.goto("restore", {}, false)
	await _wait(0.5)
	App.main.current._choice_panel("walls")
	await _wait(0.4)
	await shot("t14_restore_choice")
	# --- challenges, ledger, bakery
	App.main.goto("daily", {}, false)
	await _wait(0.5)
	await shot("t15_challenges")
	var sc: ScrollContainer = _find_scroll(App.main.current)
	if sc:
		sc.scroll_vertical = 900
		await _wait(0.3)
		await shot("t16_challenges_scrolled")
	Ledger.record(App.data, "e01", 99, 0)
	Ledger.record(App.data, "e02", 99, 1)
	App.main.goto("ledger", {}, false)
	await _wait(0.5)
	await shot("t17_ledger_list")
	App.main.goto("game", {"kind": "ledger", "id": "e03"}, false)
	await _wait(0.6)
	g = game()
	var w: Array = g.def.meta.ledger.witness
	for k in 3:
		await act(int(w[k]))
		await _wait(0.1)
	await _wait(0.6)
	await shot("t18_ledger_play")
	g.ledger.show_rules()
	await _wait(0.4)
	await shot("t19_ledger_rules")
	App.main.close_all_overlays()
	await _wait(0.15)
	g.ledger._show_stage(2)
	await _wait(0.4)
	await shot("t20_ledger_hint2")
	App.main.close_all_overlays()
	await _wait(0.15)
	for k in range(3, w.size()):
		await act(int(w[k]))
		await _wait(0.06)
	await _wait(1.6)
	await shot("t21_ledger_won")
	App.main.close_all_overlays()
	await _wait(0.15)
	g.ledger._why()
	await _wait(0.4)
	await shot("t22_ledger_why")
	App.main.close_all_overlays()
	App.data.bakery.unlocked = true
	App.data.tokens = 30
	App.main.goto("bakery", {}, false)
	await _wait(0.6)
	await shot("t23_bakery")
	App.main.goto("game", {"kind": "bakery", "id": "m01"}, false)
	await _wait(0.6)
	App.main.close_all_overlays()
	await _wait(0.3)
	await shot("t24_bakery_game")
	# --- secondary screens
	App.data.stats.wins = 30
	for t in ["tasks", "achievements", "progress"]:
		App.main.goto("journal", {"tab": t}, false)
		await _wait(0.5)
		await shot("t25_journal_" + t)
	for s in ["settings", "help", "credits", "privacy", "shop"]:
		App.main.goto(s, {}, false)
		await _wait(0.5)
		await shot("t26_" + s)
	App.main.goto("home", {}, false)
	await _wait(0.4)
	App.data.story.seen.erase("lvl:c016")
	Story.level_start("c016")
	await _wait(0.7)
	await shot("t27_story")
	App.main.close_all_overlays()
	await _wait(0.2)
	App.main._confirm_exit()
	await _wait(0.4)
	await shot("t28_exit_dialog")
	App.main.close_all_overlays()
	# --- a finished café
	App.data.restoration.steps = 8
	App.data.restoration.extras = {"cat": true, "clock": true, "gramophone": true, "cakestand": true}
	App.main.goto("home", {}, false)
	await _wait(0.6)
	await shot("t29_home_done")
	App.set_setting("lang", "en")

func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var r := _find_scroll(c)
		if r:
			return r
	return null

# ------------------------------------------------------------ v7 player journey
# Everything below acts only through input events on what is on screen:
# buttons are found by their visible text (or accessible caption), crates by
# their rectangles. The only shortcuts are reading state to CHECK it, and the
# solver standing in for a player who follows the glowing hint.

func _btn_text(b: Button) -> String:
	var t := b.text + " " + b.tooltip_text
	for l in b.find_children("*", "Label", true, false):
		t += " " + (l as Label).text
	return t

func _top() -> Control:
	return App.main.overlays.back() if not App.main.overlays.is_empty() else App.main.current

func _visible_buttons() -> Array:
	var out: Array = []
	for b in _top().find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and not (b as Button).disabled:
			out.append(b)
	return out

func _tap_button(txt: String) -> bool:
	await _wait(0.45)   # screens ignore presses while they fade in
	for b in _visible_buttons():
		if _btn_text(b).contains(txt):
			await click((b as Button).get_global_rect().get_center())
			return true
	print("QA: FAIL no button '%s' among: %s" % [txt, ", ".join(_visible_buttons().map(func(x): return _btn_text(x).strip_edges()))])
	return false

## Presses an icon-only key by its accessible caption (tooltip), e.g. Pause.
func _tap_named(root: Node, caption: String) -> void:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text == caption and (b as Button).is_visible_in_tree():
			await click((b as Button).get_global_rect().get_center())
			return
	print("QA: FAIL no key named '%s'" % caption)

func _tap_dock(b: Button) -> void:
	await click(b.get_global_rect().get_center())

## Taps through any story bubbles (as a player would), capturing the first.
func _dismiss_stories(name: String) -> int:
	var n := 0
	for i in 12:
		await _wait(0.5)
		if App.main.overlays.is_empty() or not (App.main.overlays.back() is SpeechBubble):
			break
		if n == 0 and name != "":
			await shot(name)
		n += 1
		await click(Vector2(360, 900))
	return n

## Every visible string under `n`: labels and button captions.
func _texts(n: Node) -> String:
	var t := ""
	for l in n.find_children("*", "Label", true, false):
		t += (l as Label).text + " | "
	for b in n.find_children("*", "Button", true, false):
		t += (b as Button).text + " | "
	return t

## Plays the level to a win through crate/ticket taps, following the hint
## line. Returns ms from the last tap to the result card (-1 if none).
func _solve_by_taps(shot_after: int = -1, name: String = "") -> int:
	var g := game()
	var n := 0
	while not g.ps.is_won() and n < 80:
		var r := Solver.new(200000).solve(g.ps.state)
		if r.status != Solver.SOLVED or r.path.is_empty():
			print("QA: FAIL solver could not continue ", g.level_id)
			return -1
		await act(int(r.path[0]))
		n += 1
		if g.ps.is_won():
			break
		await _wait(0.3)
		if n == shot_after:
			await _wait(0.3)
			await shot(name)
	return await _wait_result()

func _wait_result() -> int:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		if not App.main.overlays.is_empty() and App.main.overlays.back() is WinPanel:
			return Time.get_ticks_msec() - t0
		await _frames(1)
	return -1

## A sequence of legal crate taps (no bell) that ends in a genuine loss.
func _losing_line(s: PuzzleState, depth: int = 0) -> Array:
	if Rules.is_lost(s):
		return [[]]
	if Rules.is_won(s) or depth > 40:
		return []
	for c in Rules.legal_moves(s):
		var nx := s.copy()
		Rules.apply_move(nx, c)
		var sub := _losing_line(nx, depth + 1)
		if not sub.is_empty():
			return [[c] + sub[0]]
	return []

## Optional player settings for a run: --qa-lang=ar, --qa-large-text,
## --qa-reduced-motion (applied the way the Settings screen applies them).
func _apply_qa_settings() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-lang="):
			App.set_setting("lang", a.substr(10))
		if a == "--qa-large-text":
			App.set_setting("large_text", true)
		if a == "--qa-reduced-motion":
			App.set_setting("reduced_motion", true)
	await _wait(0.4)

func _player() -> void:
	var expect_file := out_dir.path_join("expect.json")
	await _apply_qa_settings()
	# ---- A. fresh install -> tutorial -> first win -> rewards -> level 2
	await _wait(0.5)
	_expect(int(App.data.tokens) == 0 and not Progression.is_cleared(App.data, "c001"), "A fresh save")
	# A first launch goes straight into level 1 (no menus), after Mira's welcome.
	await _dismiss_stories("pA01_intro_story")
	_expect(App.main.current_name() == "game" and game().level_id == "c001", "A first launch opens level 1")
	await _wait(0.4)
	await shot("pA03_level1_start")
	var g := game()
	_expect(_texts(g).contains(Loc.t("goal_orders", [g.def.orders.size()])), "A objective shown")
	var dt := await _solve_by_taps(1, "pA04_level1_first_delivery")
	_expect(dt >= 0 and dt < 1500, "A result card %d ms after the last delivery" % dt)
	_expect(App.main.overlays.size() == 1, "A nothing covers the result (story comes after)")
	var pts := Scoring.points(g.ps.state)
	var stars: int = g.ps.stars()
	await _wait(1.6)
	await shot("pA05_level1_result")
	var card := _texts(_top())
	_expect(card.contains(Loc.t("win_level_complete")), "A title says Level complete")
	_expect(card.contains(str(pts)), "A final score %d shown" % pts)
	_expect(card.contains("+%d" % stars), "A tokens shown (+%d)" % stars)
	_expect(int(App.data.tokens) >= stars and Progression.is_cleared(App.data, "c001"), "A level 1 cleared, tokens paid")
	_expect(Progression.best_score(App.data, "c001") == pts, "A best score saved")
	await _tap_button(Loc.t("next_level"))
	var beats := await _dismiss_stories("pA06_story_after_result")
	_expect(beats >= 1, "A first-served story plays after the result")
	await _wait(0.5)
	_expect(App.main.current_name() == "game" and game().level_id == "c002", "A Next level opened level 2")
	await shot("pA07_level2_opened")
	# levels 2 and 3 (can't be lost) through the result card's Next button
	for lv in ["c002", "c003"]:
		dt = await _solve_by_taps()
		_expect(dt >= 0 and dt < 1500, "A %s result card in %d ms" % [lv, dt])
		await _wait(1.2)
		await _tap_button(Loc.t("next_level"))
		await _dismiss_stories("")
	_expect(game().level_id == "c004", "A reached level 4")
	# ---- B. a genuine loss -> clear reason -> Retry -> playable board
	g = game()
	var tokens_before := int(App.data.tokens)
	var line: Array = _losing_line(g.ps.state)
	_expect(not line.is_empty(), "B level 4 can be lost")
	var lose: Array = line[0] if not line.is_empty() else []
	for k in lose.size():
		if k == lose.size() - 1:
			await _wait(0.4)
			await shot("pB01_before_losing_move")
		await tap_crate(int(lose[k]))
		await _wait(0.3)
	await _wait(0.8)
	_expect(g.ps.is_lost(), "B board is genuinely lost")
	var dlg := _top()
	var lost_txt := _texts(dlg)
	_expect(dlg is Dialog and not (dlg is WinPanel) and lost_txt.contains(Loc.t("lost_title")), "B failure card shown")
	_expect(lost_txt.contains(g._lost_reason()), "B reason: " + g._lost_reason())
	_expect(not Progression.is_cleared(App.data, "c004") and int(App.data.tokens) == tokens_before, "B no unlock or reward on a loss")
	await shot("pB02_loss")
	var att := int(g.attempt)
	await _tap_button(Loc.t("lost_retry"))
	await _wait(0.5)
	_expect(App.main.overlays.is_empty() and g.ps.state.moves == 0 and g.attempt == att + 1, "B Retry gives a fresh attempt")
	_expect(g.progress.score() == 0 and int(g.progress.shown_score) == 0, "B score reset on retry")
	await shot("pB03_after_retry")
	# ---- C. undo / restart never inflate the score
	var sol: Array = g.def.meta.solution
	await act(int(sol[0]))
	await _wait(0.3)
	var p1 := Scoring.points(g.ps.state)
	await act(int(sol[1]))
	await _wait(0.3)
	await act(int(sol[2]))
	await _wait(0.6)
	var p3 := Scoring.points(g.ps.state)
	await shot("pC01_score_live")
	await _tap_dock(g.undo_btn)
	await _wait(0.3)
	await _tap_dock(g.undo_btn)
	await _wait(0.3)
	_expect(Scoring.points(g.ps.state) == p1 and int(g.progress.shown_score) == p1, "C two undos: score back to %d" % p1)
	await act(int(sol[1]))
	await _wait(0.3)
	await act(int(sol[2]))
	await _wait(0.6)
	_expect(Scoring.points(g.ps.state) == p3, "C replaying the moves gives the same score, not more")
	var restart_btn: Button = null
	for b in g.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text == Loc.t("restart"):
			restart_btn = b
	await _tap_dock(restart_btn)
	await _wait(0.4)
	_expect(g.ps.state.moves == 0 and Scoring.points(g.ps.state) == 0, "C Restart resets the attempt score")
	# taps on Restart/Undo/Pause/crates right after the winning move change nothing
	var n := 0
	while not g.ps.is_won():
		await act(int(sol[n]))
		n += 1
		if not g.ps.is_won():
			await _wait(0.12)
	var won_pts := Scoring.points(g.ps.state)
	var tok_after_win := int(App.data.tokens)
	# board keys pressed before the card lands are refused (a won attempt is final)
	for k in [restart_btn, g.undo_btn]:
		if App.main.overlays.is_empty():
			await _tap_dock(k)
	if App.main.overlays.is_empty():
		await _tap_named(g, Loc.t("paused"))
	if App.main.overlays.is_empty():
		await _tap_named(g, Loc.t("help"))
	if App.main.overlays.is_empty():
		await tap_crate(0)
	dt = await _wait_result()
	_expect(dt >= 0, "C result card still arrives after stray taps")
	# a tap that lands on a card key the instant the card appears is swallowed
	var replay_key: Button = null
	for b in _visible_buttons():
		if (b as Button).text == Loc.t("replay"):
			replay_key = b
	if replay_key:
		await click(replay_key.get_global_rect().get_center())
	await _wait(0.1)
	_expect(_stack() == "home,game" and App.main.overlays.size() == 1, "C a tap as the card lands is not taken as a choice")
	_expect(g.ps.is_won() and Scoring.points(g.ps.state) == won_pts and App.main.overlays.size() == 1, "C stray taps ignored")
	_expect(int(App.data.tokens) == tok_after_win, "C rewards paid once")
	await _wait(1.4)
	await shot("pC02_level4_result")
	var best4 := Progression.best_score(App.data, "c004")
	await _tap_button(Loc.t("replay"))
	await _dismiss_stories("")
	g = game()
	_expect(g.level_id == "c004" and g.ps.state.moves == 0, "C Replay opens a fresh attempt")
	var tok_before_replay := int(App.data.tokens)
	await _solve_by_taps()
	await _wait(1.4)
	await shot("pC03_replay_result")
	_expect(int(App.data.tokens) == tok_before_replay or g.ps.stars() > int(App.data.campaign.stars.get("c004", 0)), "C replay pays no repeat tokens")
	_expect(Progression.best_score(App.data, "c004") == maxi(best4, Scoring.points(g.ps.state)), "C best score kept")
	await _tap_button(Loc.t("next_level"))
	await _dismiss_stories("")
	_expect(game().level_id == "c005", "C Next after a replay opens level 5")
	await _wait(0.4)
	# leave the level from the pause menu, as a player would, then quit
	await _tap_named(game(), Loc.t("paused"))
	await _wait(0.4)
	await shot("pC04_pause")
	await _tap_button(Loc.t("quit_to_map"))
	await _wait(0.6)
	await shot("pC05_level_map")
	App.save_now()
	var exp := {"tokens": int(App.data.tokens), "best": App.data.campaign.best.duplicate(), "cleared": App.data.campaign.cleared.keys()}
	var f := FileAccess.open(expect_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(exp))
	f.close()

## D. Close and reopen after wins: progress, best scores and the way back in.
func _player_reopen() -> void:
	await _wait(0.8)
	await _dismiss_stories("")
	var exp = JSON.parse_string(FileAccess.get_file_as_string(out_dir.path_join("expect.json")))
	_expect(exp != null, "D expectations from the first run")
	if exp == null:
		return
	_expect(int(App.data.tokens) == int(exp.tokens), "D tokens kept (%d)" % int(exp.tokens))
	for id in ["c001", "c002", "c003", "c004"]:
		_expect(Progression.is_cleared(App.data, id), "D %s still cleared" % id)
		_expect(Progression.best_score(App.data, id) == int(exp.best.get(id, -1)), "D %s best score kept" % id)
	_expect(not Progression.is_cleared(App.data, "c005"), "D level 5 not cleared")
	await shot("pD01_home_after_reopen")
	await _tap_button(Loc.t("level_n", [5]))
	await _dismiss_stories("")
	_expect(App.main.current_name() == "game" and game().level_id == "c005", "D Play/Continue opens level 5")
	await _wait(0.4)
	await shot("pD02_level5")

## E. The last campaign level ends in the finale, not a missing level.
func _finale() -> void:
	App.data.tutorial.done = {"tut_tap": true, "tut_counter": true, "tut_priority": true, "tut_fresh": true, "tut_bell": true, "tut_bag": true, "tut_lock": true, "tut_two_stage": true}
	App.data.story.seen = {"intro": true, "first_served": true}
	var camp: Array = App.progression.campaign
	for i in camp.size() - 1:
		Progression.record_win(App.data, str(camp[i].id), 3)   # QA setup: a nearly finished campaign
	App.main.goto("home", {}, false)
	await _dismiss_stories("")
	await _tap_button(Loc.t("level_n", [camp.size()]))
	await _dismiss_stories("")
	_expect(game().level_id == str(camp[camp.size() - 1].id), "E last level opens from Play")
	var dt := await _solve_by_taps()
	_expect(dt >= 0, "E result card on the last level")
	await _wait(1.4)
	await shot("pE01_last_level_result")
	_expect(_texts(_top()).contains(Loc.t("campaign_finish")) and not _texts(_top()).contains(Loc.t("next_level")), "E main action is the finale")
	await _tap_button(Loc.t("campaign_finish"))
	await _dismiss_stories("")
	await _wait(0.8)
	await shot("pE02_finale")
	_expect(App.main.current_name() == "home", "E finale lands on home")
	_expect(_texts(_top()).contains(Loc.t("finale_campaign_body")) or _texts(_top()).contains(Loc.t("finale_title")), "E finale message shown")
