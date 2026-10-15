extends Node
## QA automation, active ONLY when launched with `-- --qa=<scenario>`.
## Drives the real game through real GUI input events and captures
## screenshots from the actual rendered viewport.
##   shots       capture every screen (EN + AR)
##   play=N-M    play campaign levels N..M with solver moves via input events
##   rapid       rapid random tapping; checks state integrity
##   lifecycle_a start a level, make moves, simulate background, hard-exit
##   lifecycle_b relaunch and verify the in-progress puzzle was restored
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

func click(pos: Vector2) -> void:
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
	elif scenario == "icon":
		await _icon()
	elif scenario == "rapid":
		await _rapid()
	elif scenario == "lifecycle_a":
		await _lifecycle_a()
	elif scenario == "lifecycle_b":
		await _lifecycle_b()
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
		App.main.goto("restore", {}, false)
		await _wait(0.4)
		await shot(lang + "_05_restore")
		App.main.goto("home", {}, false)
		await _wait(0.4)
		await shot(lang + "_06_home")
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
		var p := cv.get_global_rect().get_center()
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
