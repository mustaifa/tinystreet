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
			await tap_crate(int(c))
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
