extends RefCounted
## Delivery Logic QA journeys, run by qa_driver.gd for `--qa=dl_*` (command
## line only: unreachable in a player build). Every action is a real input
## event on what is on screen: swipes on the board, taps on the arrow keys,
## taps on board cells (tap-to-walk) and buttons found by their visible text.
## Game state is read only to CHECK results; the solver stands in for a
## player deciding which move to make. Results: lines "QA: PASS/FAIL ...".
##
##   dl_journey   fresh install -> intro -> puzzle 1 by touch -> result ->
##                Next Puzzle; a proven dead cell -> card -> Undo -> recover;
##                a silent deadlock -> exhaustive card -> Restart; solve a
##                displacement and an order puzzle; hints; rapid input during
##                the win; replay without a second reward; last puzzle ->
##                Finish -> finale
##   dl_life_a    play part of a puzzle, background the app, hard exit
##   dl_life_b    relaunch: the same position and undo history are back
##   dl_look      screenshots of every puzzle (any --qa-lang / --qa-large-text)
##   dl_clip_*    short scripted flows for the recordings (win, loss, undo)
##   dl_rapid     an input storm on a hard puzzle, then integrity checks
##   dl_migrated  launched on a genuine v7 (schema 5) save
##   dl_evidence  puzzle 7: the tempting push, its proof, the strategy hint

var q: Node   # qa_driver.gd

func _init(driver: Node) -> void:
	q = driver

func scr() -> Node:
	return App.main.current

func expect(cond: bool, what: String) -> void:
	q._expect(cond, what)

func run(name: String) -> void:
	await q._apply_qa_settings()
	match name:
		"dl_journey": await journey()
		"dl_life_a": await life_a()
		"dl_life_b": await life_b()
		"dl_look": await look()
		"dl_clip_win": await clip_win()
		"dl_clip_blocked": await clip_blocked()
		"dl_clip_silent": await clip_silent()
		"dl_rapid": await rapid()
		"dl_migrated": await migrated()
		"dl_evidence": await evidence()
		_: print("QA: FAIL unknown scenario ", name)

# --------------------------------------------------------------- input helpers

## One direction through a real gesture. `how`: "swipe", "arrow" or "key".
func press_dir(d: int, how: String) -> void:
	var s := scr()
	if how == "arrow":
		var b: Button = s.arrows[[DeliveryRules.Dir.LEFT, DeliveryRules.Dir.UP, DeliveryRules.Dir.DOWN, DeliveryRules.Dir.RIGHT].find(d)]
		await q.click(b.get_global_rect().get_center())
		await q._frames(5)   # arrow keys drop presses faster than 90 ms
	elif how == "key":
		var ev := InputEventKey.new()
		ev.keycode = [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT][d]
		ev.pressed = true
		Input.parse_input_event(ev)
		await q._frames(1)
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		await q._frames(2)
	else:
		var b2: DeliveryBoard = s.board
		var c := b2.get_global_rect().get_center()
		var v := Vector2(DeliveryRules.DELTA[d]) * 110.0
		await q._drag(c - v * 0.5, c + v * 0.5)

func tap_cell(c: int) -> void:
	await q.click(scr().board.cell_global_center(c))

## Plays a direction list: walking runs become one tap-walk on the target
## cell, pushes alternate between swipes and arrow keys. Returns pushes made.
func play(moves: PackedInt32Array, label: String = "") -> int:
	var s := scr()
	var k := 0
	var pushes := 0
	var mode := 0
	while k < moves.size():
		if s.ps.is_won():
			break
		var st: DeliveryState = s.ps.state
		# a run of steps (no push) -> tap the run's last cell
		var cell := st.player
		var j := k
		while j < moves.size():
			var t: int = s.level.nbr(cell, moves[j])
			if not s.level.floor_at(t) or st.at[t] >= 0:
				break
			cell = t
			j += 1
		if j - k >= 2:
			var before := st.steps
			await tap_cell(cell)
			await q._wait(0.15)
			s.board.finish()
			if s.ps.state.player != cell or s.ps.state.steps != before + (j - k):
				expect(false, "%s tap-walk to %d reached %d (steps %d->%d)" % [label, cell, s.ps.state.player, before, s.ps.state.steps])
				return pushes
			k = j
			continue
		var how: String = ["swipe", "arrow", "key"][mode % 3] if j == k else ("arrow" if mode % 2 == 0 else "swipe")
		mode += 1
		var p0: int = s.ps.state.pushes
		var before_snap: PackedInt32Array = s.ps.state.snapshot()
		await press_dir(moves[k], how)
		await q._frames(2)
		if s.ps.state.snapshot() == before_snap:
			expect(false, "%s move %d (%s via %s) had no effect" % [label, k, DeliveryRules.DIR_IDS[moves[k]], how])
			return pushes
		pushes += s.ps.state.pushes - p0
		k += 1
	return pushes

## The solver's full action list from the current position.
func solution_moves() -> PackedInt32Array:
	var s := scr()
	var sv := DeliverySolver.solve(s.level, s.ps.state, 400000)
	return sv.moves() if sv.status == DeliverySolver.SOLVED else PackedInt32Array()

func wait_solved() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		if not App.main.overlays.is_empty() and App.main.overlays.back() is SolvedPanel:
			return true
		await q._frames(1)
	return false

func wait_blocked(timeout: float = 4.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000):
		if scr().blocked_card.visible:
			return true
		await q._frames(1)
	return false

func card_text() -> String:
	return q._texts(App.main.overlays.back()) if not App.main.overlays.is_empty() else ""

## Pushes from the start as in levels.json "mistake" (walking as needed).
func mistake_moves(l: DeliveryLevel, from: DeliveryState) -> PackedInt32Array:
	var src: Dictionary = l.meta
	var pl: Array[Vector2i] = []
	for p in src.get("mistake", []):
		pl.append(Vector2i(int(p[2]) * l.w + int(p[1]), DeliveryRules.DIR_IDS.find(str(p[3]))))
	return DeliverySolver.expand_pushes(l, from, pl)

## Opens a puzzle the way a player does: Home -> Puzzles -> its row.
func open_from_list(id: String) -> void:
	App.main.goto("home", {}, false)
	await q._wait(0.5)
	await q._tap_button(Loc.t("dl_puzzles"))
	await q._wait(0.5)
	var row: Button = App.main.current.find_child("Puzzle_" + id, true, false)
	if row == null:
		expect(false, "row for " + id)
		return
	var sc: ScrollContainer = q._find_scroll(App.main.current)
	if sc:
		sc.ensure_control_visible(row)
		await q._frames(3)
	await q.click(row.get_global_rect().get_center())
	await q._wait(0.6)

# --------------------------------------------------------------- journeys

func journey() -> void:
	var tokens0 := int(App.data.tokens)
	# 1. fresh start -> intro -> puzzle 1
	var told: int = await q._dismiss_stories("dl_00_intro")
	expect(told >= 1, "intro story shown on first launch")
	await q._wait(0.8)
	expect(App.main.current_name() == "puzzle" and scr().level_id == "d01", "first launch opens puzzle 1 (%s)" % App.main.current_name())
	await q.shot("dl_01_puzzle1_start")
	# an invalid move changes nothing
	var snap0: PackedInt32Array = scr().ps.state.snapshot()
	await press_dir(DeliveryRules.Dir.UP, "arrow")
	await q._frames(4)
	expect(scr().ps.state.snapshot() == snap0, "walking into a wall leaves position and counters unchanged")
	await q.shot("dl_02_invalid_feedback")
	var mv := solution_moves()
	await play(mv, "d01")
	var solved := await wait_solved()
	expect(solved, "Puzzle Solved! card after the last push")
	await q._wait(1.6)
	await q.shot("dl_03_puzzle1_solved")
	expect(card_text().contains(Loc.t("dl_solved_title")), "card title is Puzzle Solved!")
	expect(int(App.data.tokens) == tokens0 + 3, "first clear paid 3 tokens once (%d -> %d)" % [tokens0, App.data.tokens])
	expect(DeliveryProgress.is_cleared(App.data, "d01"), "puzzle 1 recorded as solved")
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	expect(scr().level_id == "d02", "Next Puzzle opens puzzle 2")
	await q.shot("dl_04_puzzle2_opened")
	# play puzzle 2 with the wrong-pad lesson: push B straight up onto the coffee pad
	await play(mistake_moves(scr().level, scr().ps.state), "d02-wrong")
	await q._wait(0.4)
	expect(not scr().ps.is_won() and not scr().is_blocked(), "crate on the wrong pad: not solved, not blocked")
	expect(scr().message_label.text == Loc.t("dl_c_d02_wrong"), "coach explains the wrong pad")
	await q.shot("dl_05_wrong_pad")
	await play(solution_moves(), "d02")
	expect(await wait_solved(), "puzzle 2 solved from a wrong-pad position")
	await q._wait(1.2)
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	# 2. puzzle 3: a proven dead cell -> card -> Undo -> recover
	expect(scr().level_id == "d03", "puzzle 3 open")
	await play(mistake_moves(scr().level, scr().ps.state), "d03-mistake")
	expect(await wait_blocked(1.0), "route-blocked card for a crate pushed onto the wall")
	var bt: String = scr().blocked_label.text
	expect(bt.contains(Loc.t("dl_sym_coffee")) and bt.begins_with(Loc.t("dl_blocked_dead", [Loc.t("dl_sym_coffee"), Loc.t("dl_sym_coffee")])), "card names the stuck coffee crate: " + bt)
	expect(scr().ps.state.pushes == 1, "board kept as it was (player stays in control)")
	await q.shot("dl_06_blocked_dead_cell")
	var undo_b: Button = scr().find_child("BlockedUndo", true, false)
	await q.click(undo_b.get_global_rect().get_center())
	await q._wait(0.5)
	expect(not scr().blocked_card.visible and scr().ps.state.pushes == 0, "Undo on the card recovers the position")
	await q.shot("dl_07_after_undo")
	await play(solution_moves(), "d03")
	expect(await wait_solved(), "puzzle 3 solved after recovering")
	await q._wait(1.2)
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	# 3. puzzle 4: a silent deadlock only search can prove -> Restart
	expect(scr().level_id == "d04", "puzzle 4 open")
	await play(mistake_moves(scr().level, scr().ps.state), "d04-mistake")
	expect(scr().deadlock_code_now() == DeliveryRules.Dead.NONE, "no crate is visibly stuck (instant checks see nothing)")
	expect(await wait_blocked(4.0), "exhaustive search proves the delivered croissant blocks the coffee")
	expect(scr().blocked_label.text.begins_with(Loc.t("dl_blocked_search")), "card says every sequence was checked")
	await q.shot("dl_08_blocked_by_search")
	# hint in a blocked position says how far to go back
	await q._tap_named(scr(), Loc.t("hint"))
	await q._wait(0.6)
	await q._wait(1.0)
	var want := -1
	var hs: Array = scr().ps.history
	for kk in range(1, hs.size() + 1):
		if DeliverySolver.solve(scr().level, DeliveryState.from_snapshot(scr().level, hs[hs.size() - kk])).status == DeliverySolver.SOLVED:
			want = kk
			break
	expect(want > 0 and card_text().contains(Loc.t("dl_hint_stuck", [want])), "hint: undo %d move(s) back to the last solvable position: %s" % [want, card_text().left(200)])
	await q.shot("dl_09_hint_when_blocked")
	await q._tap_button(Loc.t("close"))
	await q._wait(0.3)
	var rs_b: Button = scr().find_child("BlockedRestart", true, false)
	await q.click(rs_b.get_global_rect().get_center())
	await q._wait(0.5)
	var fresh := DeliveryRules.start_state(scr().level)
	expect(scr().ps.state.equals(fresh) and not scr().blocked_card.visible, "Restart gives a fresh playable board (counters 0)")
	expect(scr().ps.can_undo(), "the restart itself can be undone")
	await q.shot("dl_10_after_restart")
	# hints: three tiers, recomputed from the position
	await q._tap_named(scr(), Loc.t("hint"))
	await q._wait(0.5)
	expect(card_text().contains(Loc.t("dl_n_d04")), "tier 1: the level's idea")
	await q._tap_button(Loc.t("dl_hint_more"))
	await q._wait(0.6)
	expect(card_text().contains(Loc.t("dl_hint_left", [scr().level.min_pushes()])), "tier 2: strategy with the proven shortest finish")
	await q._tap_button(Loc.t("dl_hint_show_push"))
	await q._wait(0.4)
	await q.shot("dl_11_hint_tiers")
	await q._tap_button(Loc.t("close"))
	await q._wait(0.3)
	var hc: int = scr().board.hint_crate
	var hd: int = scr().board.hint_dir
	expect(hc >= 0 and hd >= 0, "tier 3 shows one push on the board")
	await q.shot("dl_12_hint_arrow")
	if hc >= 0:
		# follow it: the position must stay solvable
		var l: DeliveryLevel = scr().level
		var stand: int = l.nbr(scr().ps.state.crates[hc], DeliveryRules.opposite(hd))
		var path := DeliveryRules.walk_path(l, scr().ps.state, stand)
		path.append(hd)
		await play(path, "d04-hint")
		await q._wait(0.3)
		var sv := DeliverySolver.solve(l, scr().ps.state)
		expect(sv.status == DeliverySolver.SOLVED and sv.push_list.size() == l.min_pushes() - 1, "the hinted push is on a shortest solution")
		expect(scr().board.hint_crate == -1, "hint arrow cleared by the move")
	await play(solution_moves(), "d04")
	expect(await wait_solved(), "puzzle 4 solved")
	await q._wait(1.2)
	expect(not card_text().contains(Loc.t("dl_medal_unassisted")), "hint used: no unassisted badge")
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	# 4. puzzle 5: temporary displacement of a delivered crate
	expect(scr().level_id == "d05", "puzzle 5 open")
	var l5: DeliveryLevel = scr().level
	var left_pad := false
	var mv5 := solution_moves()
	var sim: DeliveryState = scr().ps.state.copy()
	for d in mv5:
		DeliveryRules.move(l5, sim, d)
		for i in sim.crates.size():
			if l5.crate_sym[i] == 1 and not DeliveryRules.on_match(l5, sim, i):
				left_pad = true
	await q.shot("dl_13_displacement_start")
	await play(mv5, "d05")
	expect(await wait_solved(), "puzzle 5 solved by moving the delivered croissant away and back (%s)" % left_pad)
	await q._wait(1.2)
	await q.shot("dl_14_displacement_solved")
	expect(card_text().contains(Loc.t("dl_medal_unassisted")), "no hint used: unassisted badge")
	expect(card_text().contains(Loc.t("dl_medal_fewest", [l5.min_pushes()])), "solver's line has the proven fewest pushes: medal")
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	await play(solution_moves(), "d06")
	expect(await wait_solved(), "puzzle 6 solved")
	await q._wait(1.2)
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	# 5. puzzle 7: delivery order (the closest crate goes last)
	expect(scr().level_id == "d07", "puzzle 7 open")
	var order: Array = []
	var mv7 := solution_moves()
	var sim7: DeliveryState = scr().ps.state.copy()
	var l7: DeliveryLevel = scr().level
	for d in mv7:
		DeliveryRules.move(l7, sim7, d)
		for i in sim7.crates.size():
			var sy := l7.crate_sym[i]
			if DeliveryRules.on_match(l7, sim7, i) and not (sy in order):
				order.append(sy)
	expect(not order.is_empty() and order.back() == 0, "coffee (one push from home at the start) is delivered last: %s" % [order])
	# rapid input during the win: hammer arrows and swipes right after the last push
	await play(mv7.slice(0, mv7.size() - 1), "d07")
	var tok7 := int(App.data.tokens)
	await press_dir(mv7[mv7.size() - 1], "arrow")
	for k in 3:
		await press_dir(k % 4, "arrow")
		await press_dir((k + 1) % 4, "swipe")
	expect(await wait_solved(), "solved card despite rapid input")
	await q._wait(1.0)
	var cards := 0
	for o in App.main.overlays:
		if o is SolvedPanel:
			cards += 1
	expect(cards == 1, "exactly one result card (%d)" % cards)
	expect(int(App.data.tokens) == tok7 + 4, "reward paid exactly once under rapid input (%d -> %d)" % [tok7, App.data.tokens])
	await q.shot("dl_15_order_solved")
	# 7. replay after winning: no second reward
	await q._tap_button(Loc.t("replay"))
	await q._wait(0.8)
	expect(scr().level_id == "d07" and scr().ps.state.pushes == 0, "Replay opens a fresh board")
	var tok_r := int(App.data.tokens)
	await play(solution_moves(), "d07-replay")
	expect(await wait_solved(), "replay solved")
	await q._wait(1.2)
	expect(int(App.data.tokens) == tok_r, "replay pays nothing (%d -> %d)" % [tok_r, App.data.tokens])
	expect(card_text().contains(Loc.t("dl_res_reward_done")), "card says the reward was already collected")
	await q.shot("dl_16_replay_no_reward")
	# every remaining puzzle by touch, then the last one -> Finish
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	var last_id := App.delivery.id_at(App.delivery.count() - 1)
	for i in range(7, App.delivery.count() - 1):
		var id := App.delivery.id_at(i)
		expect(scr().level_id == id, id + " open")
		await play(solution_moves(), id)
		expect(await wait_solved(), id + " solved")
		await q._wait(1.0)
		if id == "d13":
			await q.shot("dl_16b_chapter5_solved")
		await q._tap_button(Loc.t("dl_next_puzzle"))
		await q._wait(0.8)
	expect(scr().level_id == last_id, "last puzzle open")
	await q.shot("dl_16c_last_puzzle")
	await play(solution_moves(), last_id)
	expect(await wait_solved(), "last puzzle solved")
	await q._wait(1.2)
	expect(card_text().contains(Loc.t("dl_finish")) and not card_text().contains(Loc.t("dl_next_puzzle")), "last card offers Finish, not a missing next puzzle")
	await q.shot("dl_17_last_solved")
	await q._tap_button(Loc.t("dl_finish"))
	await q._wait(1.0)
	expect(App.main.current_name() == "home" and card_text().contains(Loc.t("dl_finale_title")), "Finish -> home with the finale message")
	await q.shot("dl_18_finale")
	expect(App.delivery.cleared_count(App.data) == App.delivery.count(), "all puzzles recorded solved")
	var paid := 0
	for k in App.data.grants:
		if str(k).begins_with("dl:clear:"):
			paid += int(App.data.grants[k])
	var expect_paid := 0
	for l in App.delivery.levels:
		expect_paid += int(l.reward)
	expect(paid == expect_paid and int(App.data.tokens) - tokens0 == expect_paid, "every completion reward paid exactly once (%d of %d)" % [paid, expect_paid])
	App.save_now()

# --------------------------------------------------------------- lifecycle

func life_a() -> void:
	await q._dismiss_stories("")
	await q._wait(0.6)
	# solve puzzle 1, then make some moves on puzzle 2 and leave mid-way
	await play(solution_moves(), "d01")
	await wait_solved()
	await q._wait(1.0)
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(0.8)
	var mv := solution_moves()
	await play(mv.slice(0, 9), "d02-part")
	await q._wait(0.3)
	var s: Node = scr()
	print("QA: LIFE state=%s history=%d hints=%d tokens=%d" % [JSON.stringify(Array(s.ps.state.snapshot())), s.ps.history.size(), s.ps.hints_used, App.data.tokens])
	App.notification(Node.NOTIFICATION_APPLICATION_PAUSED)   # what Android sends on background
	await q._wait(0.2)
	expect(DeliveryProgress.current_id(App.data) == "d02", "attempt saved on background")
	OS.kill(OS.get_process_id())   # hard exit, no clean shutdown

func life_b() -> void:
	await q._wait(1.0)
	expect(App.main.current_name() == "home", "relaunch lands on home (not first-run intro)")
	expect(DeliveryProgress.is_cleared(App.data, "d01"), "puzzle 1 still solved after restart")
	await q.shot("dl_20_home_after_restart")
	var play_b: Button = App.main.current.find_child("PlayButton", true, false)
	expect(play_b != null and q._btn_text(play_b).contains(Loc.t("home_continue")), "Play says Continue")
	await q.click(play_b.get_global_rect().get_center())
	await q._wait(0.8)
	var s: Node = scr()
	print("QA: LIFE state=%s history=%d hints=%d tokens=%d" % [JSON.stringify(Array(s.ps.state.snapshot())), s.ps.history.size(), s.ps.hints_used, App.data.tokens])
	expect(s.level_id == "d02" and s.ps.history.size() > 0, "continues puzzle 2 with its undo history")
	await q.shot("dl_21_resumed")
	var p: int = s.ps.state.pushes
	await q._tap_named(s, Loc.t("undo"))
	await q._wait(0.4)
	expect(s.ps.state.pushes <= p and s.ps.can_redo(), "undo works on the restored history")
	await play(solution_moves(), "d02-resumed")
	expect(await wait_solved(), "resumed puzzle solved")
	await q._wait(1.0)
	expect(int(App.data.tokens) == 6, "tokens after two first clears: %d" % App.data.tokens)

# --------------------------------------------------------------- screenshots / clips

func _unlock_all() -> void:
	for l in App.delivery.levels:
		App.data.logic.cleared[str(l.id)] = true
	App.data.story.seen["dl_intro"] = true

func look() -> void:
	await q._dismiss_stories("")
	_unlock_all()
	var tag := "ar_" if Loc.is_rtl() else ""
	if Style.text_scale > 1.0:
		tag += "large_"
	App.main.goto("home", {}, false)
	await q._wait(0.8)
	await q.shot(tag + "look_home")
	App.main.goto("puzzles")
	await q._wait(0.8)
	await q.shot(tag + "look_puzzles")
	for l in App.delivery.levels:
		App.main.goto("puzzle", {"id": str(l.id)}, false)
		await q._wait(0.7)
		await q.shot(tag + "look_" + str(l.id))
	App.main.goto("help")
	await q._wait(0.6)
	await q.shot(tag + "look_help")

func clip_win() -> void:
	await q._dismiss_stories("")
	await q._wait(0.5)
	await play(solution_moves(), "clip")
	await wait_solved()
	await q._wait(2.5)
	await q._tap_button(Loc.t("dl_next_puzzle"))
	await q._wait(1.5)

func clip_blocked() -> void:
	await q._dismiss_stories("")
	_unlock_all()
	App.data.logic.cleared.erase("d03")
	App.main.goto("puzzle", {"id": "d03"}, false)
	await q._wait(1.0)
	await play(mistake_moves(scr().level, scr().ps.state), "clip")
	await wait_blocked()
	await q._wait(2.5)
	var undo_b: Button = scr().find_child("BlockedUndo", true, false)
	await q.click(undo_b.get_global_rect().get_center())
	await q._wait(1.0)
	await play(solution_moves(), "clip")
	await wait_solved()
	await q._wait(2.0)

func clip_silent() -> void:
	await q._dismiss_stories("")
	_unlock_all()
	App.data.logic.cleared.erase("d04")
	App.main.goto("puzzle", {"id": "d04"}, false)
	await q._wait(1.0)
	await play(mistake_moves(scr().level, scr().ps.state), "clip")
	await wait_blocked()
	await q._wait(2.5)
	var rs_b: Button = scr().find_child("BlockedRestart", true, false)
	await q.click(rs_b.get_global_rect().get_center())
	await q._wait(1.0)
	await play(solution_moves(), "clip")
	await wait_solved()
	await q._wait(2.0)

# --------------------------------------------------------------- input storm, migration, evidence

## Rapid mixed input on a hard puzzle, then integrity: the position is
## legal, and undoing everything returns exactly to the start (counters 0).
func rapid() -> void:
	await q._dismiss_stories("")
	_unlock_all()
	App.data.logic.cleared.erase("d12")
	App.main.goto("puzzle", {"id": "d12"}, false)
	await q._wait(0.8)
	var s: Node = scr()
	var l: DeliveryLevel = s.level
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var undo_b: Button = null
	for b in s.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text == Loc.t("undo"):
			undo_b = b
	var kinds := [0, 0, 0, 0, 0, 0]
	var changed := 0
	var pushes_seen := 0
	for k in 260:
		if s.ps.is_won() or not App.main.overlays.is_empty():
			break
		var snap0: PackedInt32Array = s.ps.state.snapshot()
		var p0: int = s.ps.state.pushes
		var kind := rng.randi_range(0, 5)
		kinds[kind] += 1
		match kind:
			0:
				await press_dir(rng.randi_range(0, 3), "arrow")
			1:
				# arrow presses faster than the 90 ms guard: extra presses are dropped whole
				var b: Button = s.arrows[rng.randi_range(0, 3)]
				for r in 3:
					await q.click(b.get_global_rect().get_center())
			2:
				await press_dir(rng.randi_range(0, 3), "swipe")
			3:
				await tap_cell(rng.randi_range(0, l.n - 1))
			4:
				for r in 4:
					var ev := InputEventKey.new()
					ev.keycode = [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT][rng.randi_range(0, 3)]
					ev.pressed = true
					Input.parse_input_event(ev)
					var up := ev.duplicate()
					up.pressed = false
					Input.parse_input_event(up)
				await q._frames(1)
			5:
				if undo_b and not undo_b.disabled:
					await q.click(undo_b.get_global_rect().get_center())
		if s.ps.state.snapshot() != snap0:
			changed += 1
		pushes_seen += maxi(0, s.ps.state.pushes - p0)
	await q._wait(0.5)
	print("QA: storm inputs by kind ", kinds, " position changes=", changed, " pushes made=", pushes_seen, " history=", s.ps.history.size())
	expect(changed > 60 and pushes_seen >= 5, "the storm really moved and pushed (%d changes, %d pushes)" % [changed, pushes_seen])
	var st: DeliveryState = s.ps.state
	var ok := l.floor_at(st.player) and st.at[st.player] < 0
	var seen := {}
	for c in st.crates:
		ok = ok and l.floor_at(c) and not seen.has(c)
		seen[c] = true
	expect(ok, "position legal after the storm (no overlaps, nothing in walls)")
	expect(s.board.is_animating() == false, "animations settled")
	while s.ps.can_undo():
		s.ps.undo()
	expect(s.ps.state.equals(DeliveryRules.start_state(l)), "undoing every recorded action returns exactly to the start, counters 0")

## Launched on a genuine v7 (schema 5) save produced by the v7 build.
func migrated() -> void:
	var bak := App.store.path + ".schema5.bak"
	expect(FileAccess.file_exists(bak), "pre-migration copy of the v7 save kept (" + bak.get_file() + ")")
	var env = JSON.parse_string(FileAccess.get_file_as_string(bak))
	var old = JSON.parse_string(str(env.payload)) if env is Dictionary else {}
	expect(int(env.schema) == 5, "the backup is the untouched schema-5 file")
	expect(int(App.data.tokens) == int(old.tokens), "tokens kept (%d)" % int(old.tokens))
	var kept := true
	for id in old.campaign.cleared:
		kept = kept and Progression.is_cleared(App.data, str(id))
	for id in old.campaign.best:
		kept = kept and Progression.best_score(App.data, str(id)) == int(old.campaign.best[id])
	expect(kept and old.campaign.cleared.size() > 0, "sorting records kept (%d cleared, best scores)" % old.campaign.cleared.size())
	expect(int(App.data.restoration.steps) == int(old.restoration.steps), "restoration kept")
	expect(App.delivery.cleared_count(App.data) == 0, "no Delivery Logic puzzle marked solved")
	var told: int = await q._dismiss_stories("dl_30_migrated_intro")
	expect(told >= 1, "an upgrading player sees the new intro once")
	await q._wait(0.8)
	expect(App.main.current_name() == "puzzle" and scr().level_id == "d01", "then lands on puzzle 1")
	var t0 := int(App.data.tokens)
	await play(solution_moves(), "d01")
	expect(await wait_solved(), "puzzle 1 solved on the migrated save")
	await q._wait(1.0)
	expect(int(App.data.tokens) == t0 + 3, "first clear pays on top of the old balance (%d -> %d)" % [t0, App.data.tokens])
	await q.shot("dl_31_migrated_solved")
	App.save_now()
	var now = JSON.parse_string(FileAccess.get_file_as_string(App.store.path))
	expect(int(now.schema) == 6, "save rewritten as schema 6")

## Evidence: puzzle 7's strategic choice and its tempting wrong approach.
func evidence() -> void:
	await q._dismiss_stories("")
	_unlock_all()
	App.data.logic.cleared.erase("d07")
	App.main.goto("puzzle", {"id": "d07"}, false)
	await q._wait(0.8)
	await q.shot("ev_01_d07_start")
	var mv := mistake_moves(scr().level, scr().ps.state)
	await play(mv, "d07-tempting")
	await q._wait(0.2)
	expect(DeliveryRules.on_match(scr().level, scr().ps.state, 0), "the coffee is home after one push (the tempting move)")
	expect(await wait_blocked(4.0), "...and search proves the puzzle can no longer be finished")
	await q.shot("ev_02_d07_tempting_push_proved_blocked")
	var undo_b: Button = scr().find_child("BlockedUndo", true, false)
	await q.click(undo_b.get_global_rect().get_center())
	await q._wait(0.6)
	await q._tap_named(scr(), Loc.t("hint"))
	await q._wait(0.6)
	await q._tap_button(Loc.t("dl_hint_more"))
	await q._wait(0.8)
	var t: String = card_text()
	expect(t.contains(Loc.t("dl_hint_wait", [Loc.t("dl_sym_coffee")])), "strategy hint: leave the coffee for later")
	await q.shot("ev_03_d07_strategy_hint")
	await q._tap_button(Loc.t("close"))
	await q._wait(0.3)
	await play(solution_moves(), "d07")
	expect(await wait_solved(), "solved with the coffee delivered last")
	await q._wait(1.2)
	await q.shot("ev_04_d07_solved")
