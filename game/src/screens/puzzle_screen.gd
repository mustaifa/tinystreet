extends Control
## Delivery Logic play screen. The view is a function of DeliverySession
## state; DeliveryRules decides every move. After each change the position is
## checked for a proven deadlock: instant checks at once, then a budgeted
## exhaustive search spread over frames (no threads, so the web build works).
## A new move, undo, redo, restart or leaving cancels a check or hint that is
## still running; a timeout never claims "no solution".

const CHECK_NODES := 60000       # exhaustive check budget per position
const FRAME_BUDGET_USEC := 4000  # search time per frame
const ARROW_REPEAT_MS := 90      # one arrow press = one move; faster presses are dropped

var level_id := ""
var level: DeliveryLevel
var ps: DeliverySession
var index := 0

var board: DeliveryBoard
var title_label: Label
var sub_label: Label
var hud: _Hud
var message: PanelContainer
var message_label: Label
var message_icon: Control
var blocked_card: PanelContainer
var blocked_label: Label
var undo_btn: Button
var redo_btn: Button
var hint_btn: Button
var arrows: Array = []
var arow: HBoxContainer

var _check: DeliverySolver
var _check_key := PackedByteArray()
var _cache := {}                 # position key -> {status, pushes}
var _blocked_code := DeliveryRules.Dead.NONE
var _won := false
var _flash := ""                 # transient message (invalid move)
var _flash_until := 0
var _hint_dialog: Dialog
var _hint_tier := {}             # position key -> highest tier shown (1..3)
var _hint_key := PackedByteArray()
var _hint_body: VBoxContainer
var _last_arrow := 0
# "Undo N moves" search for a blocked position: walks back through the
# history, checking each earlier position until one is solvable.
var _rewind_k := 0               # history depth being checked (0 = idle)
var _rewind_solver: DeliverySolver
var _rewind_result := -1         # -1 running/idle, 0 not found, k found

func setup(params: Dictionary) -> void:
	level_id = str(params.get("id", ""))
	level = App.delivery.level(level_id)
	index = App.delivery.index_of(level_id)
	if level == null or not level.is_valid() or not App.delivery.is_unlocked(App.data, index):
		App.main.goto("home", {}, false)
		return
	var why: Array = []
	ps = DeliveryProgress.load_attempt(App.data, level, why)
	if ps == null:
		ps = DeliverySession.start(level)
		App.analytics.event("dl_start", {"level": level_id})
	if "changed" in why:
		App.main.toast(Loc.t("dl_changed"))
	_build()
	board.setup(level, ps.state)
	_after_change(false)

# --------------------------------------------------------------- layout

func _build() -> void:
	var root := UI.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := UI.hbox(12)
	top.add_child(UI.chip("pause", _open_pause, "ChipButton", Style.CHIP, 0, Loc.t("paused")))
	var titles := UI.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	title_label = UI.label(Loc.t("dl_puzzle_n", [index + 1]), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	titles.add_child(title_label)
	sub_label = UI.label(level.title(), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(sub_label)
	top.add_child(titles)
	top.add_child(UI.chip("help", func(): if not _won: App.main.goto("help"), "ChipButton", Style.CHIP, 0, Loc.t("help")))
	root.add_child(top)
	hud = _Hud.new()
	hud.screen = self
	hud.custom_minimum_size = Vector2(0, 74)
	root.add_child(hud)
	# message row: coach (lessons), hint result or a refusal; reserved height
	message = PanelContainer.new()
	message.custom_minimum_size = Vector2(0, 76)
	var msb := Style.box(Style.PAPER, 22, Style.GOLD, 3)
	msb.content_margin_left = 14
	msb.content_margin_right = 14
	msb.content_margin_top = 8
	msb.content_margin_bottom = 8
	message.add_theme_stylebox_override("panel", msb)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mrow := UI.hbox(12)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_icon = UI.medallion("hint", Style.GOLD_SOFT, Style.GOLD_EDGE, 48)
	mrow.add_child(message_icon)
	message_label = UI.label("", "", UI.al())
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.add_theme_font_size_override("font_size", Style.fs(24))
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(message_label)
	message.add_child(mrow)
	root.add_child(message)
	board = DeliveryBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 320)
	board.swiped.connect(_on_dir)
	board.tapped.connect(_on_tap)
	root.add_child(board)
	blocked_card = _make_blocked_card()
	blocked_card.visible = false
	root.add_child(blocked_card)
	# arrows: spatial, so always left-to-right even in Arabic
	arow = UI.hbox(14)
	arow.layout_direction = Control.LAYOUT_DIRECTION_LTR
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	for d in [DeliveryRules.Dir.LEFT, DeliveryRules.Dir.UP, DeliveryRules.Dir.DOWN, DeliveryRules.Dir.RIGHT]:
		var b := _arrow_button(d)
		arow.add_child(b)
		arrows.append(b)
	root.add_child(arow)
	var dock := PanelContainer.new()
	var dsb := Style.box(Color(Style.PAPER, 0.9), 30, Style.PAPER_EDGE, 2, true)
	dsb.content_margin_top = 8
	dsb.content_margin_bottom = 6
	dock.add_theme_stylebox_override("panel", dsb)
	var tools := UI.hbox(8)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_child(tools)
	var u := _dock_item("undo", Loc.t("undo"), _on_undo)
	undo_btn = u.get_meta("button")
	tools.add_child(u)
	var r := _dock_item("redo", Loc.t("redo"), _on_redo)
	redo_btn = r.get_meta("button")
	tools.add_child(r)
	var h := _dock_item("hint", Loc.t("hint"), _on_hint)
	hint_btn = h.get_meta("button")
	tools.add_child(h)
	tools.add_child(_dock_item("restart", Loc.t("restart"), _on_restart))
	root.add_child(dock)

func _dock_item(glyph: String, caption: String, cb: Callable) -> Control:
	var w := UI.icon_button(glyph, caption, cb, "ChipButton", 80)
	w.custom_minimum_size = Vector2(150, 0)
	return w

## Arrow keys of the on-screen pad. They act on press (no 350 ms UI
## debounce), one move per press.
func _arrow_button(d: int) -> Button:
	var b := Button.new()
	b.theme_type_variation = "SecondaryButton"
	b.custom_minimum_size = Vector2(132, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Loc.t("dl_dir_" + DeliveryRules.DIR_IDS[d])
	b.name = "Arrow_" + DeliveryRules.DIR_IDS[d]
	var g := Glyph.new()
	g.kind = "arrow_" + DeliveryRules.DIR_IDS[d]
	g.color = Style.TEAL_DARK
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.offset_bottom = -Style.EDGE / 2.0
	b.add_child(g)
	UI.press_feedback(b)
	b.button_down.connect(func():
		var now := Time.get_ticks_msec()
		if now - _last_arrow < ARROW_REPEAT_MS or App.main.input_locked():
			return
		_last_arrow = now
		_on_dir(d))
	return b

func _make_blocked_card() -> PanelContainer:
	# Compact: it replaces the arrow row, so every pixel it adds shrinks the board.
	var p := PanelContainer.new()
	var sb := Style.box(Style.TERRA_SOFT, 22, Style.DANGER, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.name = "BlockedCard"
	var v := UI.vbox(6)
	var head := UI.hbox(10)
	head.add_child(UI.medallion("lock", Style.PAPER, Style.DANGER, 40))
	var t := UI.label(Loc.t("dl_blocked_title"), "StrongLabel", UI.al(), false)
	t.add_theme_color_override("font_color", Style.DANGER)
	t.add_theme_font_size_override("font_size", Style.fs(28))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	v.add_child(head)
	blocked_label = UI.label("", "", UI.al())
	blocked_label.add_theme_font_size_override("font_size", Style.fs(22))
	blocked_label.custom_minimum_size = Vector2(560, 0)
	v.add_child(blocked_label)
	var row := UI.hbox(12)
	var ub := UI.icon_text_button("undo", Loc.t("undo"), _on_undo, "", 76)
	ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ub.name = "BlockedUndo"
	row.add_child(ub)
	var rb := UI.icon_text_button("restart", Loc.t("restart"), _on_restart, "SecondaryButton", 76)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.name = "BlockedRestart"
	row.add_child(rb)
	v.add_child(row)
	p.add_child(v)
	return p

# --------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or _won or not App.main.overlays.is_empty():
		return
	var k: int = e.keycode
	var d := -1
	match k:
		KEY_UP, KEY_W: d = DeliveryRules.Dir.UP
		KEY_RIGHT, KEY_D: d = DeliveryRules.Dir.RIGHT
		KEY_DOWN, KEY_S: d = DeliveryRules.Dir.DOWN
		KEY_LEFT, KEY_A: d = DeliveryRules.Dir.LEFT
		KEY_Z, KEY_BACKSPACE: _on_undo()
		KEY_Y: _on_redo()
	if d >= 0:
		_on_dir(d)
	if d >= 0 or k in [KEY_Z, KEY_BACKSPACE, KEY_Y]:
		get_viewport().set_input_as_handled()

## One step or push.
func _on_dir(d: int) -> void:
	if _won or ps == null or not App.main.overlays.is_empty():
		return
	board.finish()
	var before_on := DeliveryRules.delivered_count(level, ps.state)
	var target := level.nbr(ps.state.player, d)
	var pushed := ps.state.at[target] if level.floor_at(target) else -1
	var r := ps.act(d)
	if r == DeliveryRules.INVALID:
		_invalid(d, target)
		return
	board.animate_move(ps.state, d, pushed if r == DeliveryRules.PUSH else -1)
	if r == DeliveryRules.PUSH:
		App.audio.play("place", 1.0)
		App.haptic(12)
		if DeliveryRules.on_match(level, ps.state, pushed):
			board.pop_crate(pushed)
			App.audio.play("deliver")
			App.haptic(20)
		elif DeliveryRules.delivered_count(level, ps.state) < before_on:
			App.audio.play("undo", 0.8)
	_after_change(true)

## Tap-to-walk: only through crate-free floor; never pushes.
func _on_tap(cell: int) -> void:
	if _won or ps == null or not App.main.overlays.is_empty():
		return
	board.finish()
	if cell == ps.state.player:
		return
	var path := DeliveryRules.walk_path(level, ps.state, cell)
	if path.is_empty():
		if level.floor_at(cell) and ps.state.at[cell] < 0:
			_show_flash(Loc.t("dl_walk_no"))
			App.audio.play("invalid")
		return
	var cells := PackedInt32Array()
	var c := ps.state.player
	for d in path:
		c = level.nbr(c, d)
		cells.append(c)
	ps.walk_to(cell)
	board.animate_walk(ps.state, cells, path)
	_after_change(true)

func _invalid(d: int, target: int) -> void:
	App.audio.play("invalid")
	App.haptic(30)
	board.bump(d)
	if level.floor_at(target) and ps.state.at[target] >= 0:
		_show_flash(Loc.t("dl_bump_block"))
	else:
		_show_flash(Loc.t("dl_bump_wall"))

func _on_undo() -> void:
	if _won or not ps.undo():
		return
	App.audio.play("undo")
	board.set_state(ps.state)
	_after_change(true)

func _on_redo() -> void:
	if _won or not ps.redo():
		return
	App.audio.play("undo", 1.2)
	board.set_state(ps.state)
	_after_change(true)

func _on_restart() -> void:
	if _won:
		return
	App.main.close_all_overlays()
	ps.restart()
	App.analytics.event("dl_restart", {"level": level_id})
	board.set_state(ps.state)
	_after_change(true)

# --------------------------------------------------------------- after every change

func _after_change(save: bool) -> void:
	board.hint_crate = -1
	board.hint_dir = -1
	_close_hint()
	_rewind_k = 0
	_rewind_solver = null
	_rewind_result = -1
	if ps.is_won():
		_on_won()
		return
	if save:
		persist()
	_evaluate()
	_refresh()

func _refresh() -> void:
	hud.queue_redraw()
	undo_btn.disabled = not ps.can_undo()
	redo_btn.disabled = not ps.can_redo()
	_update_message()

## Instant sound checks first; otherwise a budgeted exhaustive search.
func _evaluate() -> void:
	_check = null
	var dl := DeliveryRules.deadlock(level, ps.state)
	if dl.code != DeliveryRules.Dead.NONE:
		_set_blocked(dl.code, dl.crates)
		return
	var k := DeliveryRules.key(level, ps.state, DeliveryRules.reach(level, ps.state))
	if _cache.has(k):
		var st: int = _cache[k].status
		_set_blocked(DeliveryRules.Dead.EXHAUSTIVE if st == DeliverySolver.UNSOLVABLE else DeliveryRules.Dead.NONE, [])
		return
	_set_blocked(DeliveryRules.Dead.NONE, [])
	_check_key = k
	_check = DeliverySolver.new(level, ps.state, CHECK_NODES)

func _process(_delta: float) -> void:
	if _flash != "" and Time.get_ticks_msec() > _flash_until:
		_flash = ""
		_update_message()
	if _check == null:
		_step_rewind()
		return
	var t0 := Time.get_ticks_usec()
	while _check.status == DeliverySolver.RUNNING and Time.get_ticks_usec() - t0 < FRAME_BUDGET_USEC:
		_check.step(48)
	if _check.status == DeliverySolver.RUNNING:
		return
	var done := _check
	_check = null
	_cache[_check_key] = {"status": done.status, "pushes": done.push_list.duplicate()}
	if done.status == DeliverySolver.UNSOLVABLE:
		_set_blocked(DeliveryRules.Dead.EXHAUSTIVE, [])
		App.analytics.event("dl_blocked", {"level": level_id, "kind": "search"})
	if _hint_dialog and is_instance_valid(_hint_dialog) and _hint_key == _check_key:
		_fill_hint()
	_update_message()

func _set_blocked(code: int, crates: Array) -> void:
	var was := _blocked_code
	_blocked_code = code
	board.blocked = crates
	blocked_card.visible = code != DeliveryRules.Dead.NONE
	# The card takes the arrow row's place so the board keeps its size;
	# swipes and taps still work, so the player stays in control.
	arow.visible = not blocked_card.visible
	if code == DeliveryRules.Dead.NONE:
		return
	match code:
		DeliveryRules.Dead.DEAD_CELL:
			var sym := Loc.t("dl_sym_" + DeliveryLevel.SYMBOL_IDS[level.crate_sym[int(crates[0])]])
			blocked_label.text = Loc.t("dl_blocked_dead", [sym, sym]) + " " + Loc.t("dl_blocked_tip")
		DeliveryRules.Dead.FROZEN:
			blocked_label.text = Loc.t("dl_blocked_frozen") + " " + Loc.t("dl_blocked_tip")
		_:
			blocked_label.text = Loc.t("dl_blocked_search") + " " + Loc.t("dl_blocked_tip")
	if was == DeliveryRules.Dead.NONE:
		# The card takes the arrows' place: a quick tap meant for an arrow
		# must not land on its Restart or Undo.
		App.main.lock_input(600)
		App.audio.play("warn")
		App.haptic(40)
		if code != DeliveryRules.Dead.EXHAUSTIVE:
			App.analytics.event("dl_blocked", {"level": level_id, "kind": "instant"})
	_update_message()

func is_blocked() -> bool:
	return _blocked_code != DeliveryRules.Dead.NONE

## Coach (lesson levels, until cleared), else a transient refusal or nothing.
func _update_message() -> void:
	var txt := ""
	if _flash != "":
		txt = _flash
	else:
		txt = _coach_text()
	message_label.text = txt
	message.modulate.a = 1.0 if txt != "" else 0.0

func _coach_text() -> String:
	var coach: Dictionary = level.meta.get("coach", {}) if level.meta.get("coach") is Dictionary else {}
	if coach.is_empty() or DeliveryProgress.is_cleared(App.data, level_id):
		return ""
	var phase := "start"
	if is_blocked():
		phase = "blocked"
	else:
		var wrong := false
		for i in ps.state.crates.size():
			var g := level.goal[ps.state.crates[i]]
			if g >= 0 and g != level.crate_sym[i]:
				wrong = true
		if wrong and coach.has("wrong"):
			phase = "wrong"
		elif DeliveryRules.delivered_count(level, ps.state) > 0 and coach.has("one"):
			phase = "one"
		elif ps.state.pushes > 0 and coach.has("push"):
			phase = "push"
	if not coach.has(phase):
		phase = "start" if phase != "blocked" else ""
	return Loc.t(str(coach[phase])) if phase != "" and coach.has(phase) else ""

func _show_flash(t: String) -> void:
	_flash = t
	_flash_until = Time.get_ticks_msec() + 1600
	_update_message()

# --------------------------------------------------------------- hints

func _on_hint() -> void:
	if _won:
		return
	board.finish()
	ps.hints_used += 1
	persist()
	App.analytics.event("dl_hint", {"level": level_id})
	_hint_key = DeliveryRules.key(level, ps.state, DeliveryRules.reach(level, ps.state))
	var tier := int(_hint_tier.get(_hint_key, 1))
	_hint_tier[_hint_key] = tier
	_hint_body = UI.vbox(12)
	_hint_dialog = Dialog.make(Loc.t("dl_hint_title"), "", [[Loc.t("close"), func(): pass, "SecondaryButton"]], _hint_body, "hint")
	_fill_hint()
	App.main.show_overlay(_hint_dialog)

func _close_hint() -> void:
	if _hint_dialog and is_instance_valid(_hint_dialog):
		App.main.close_overlay(_hint_dialog)
	_hint_dialog = null

func _fill_hint() -> void:
	if _hint_body == null or not is_instance_valid(_hint_body):
		return
	for c in _hint_body.get_children():
		c.queue_free()
	var tier := int(_hint_tier.get(_hint_key, 1))
	var lines: Array = []   # [caption, text]
	if is_blocked():
		lines.append([Loc.t("dl_blocked_title"), _stuck_text()])
		tier = 3
	else:
		lines.append([Loc.t("dl_hint_idea"), Loc.t(str(level.meta.get("nudge", "")))])
		if tier >= 2:
			lines.append([Loc.t("dl_hint_strategy"), _strategy_text()])
		if tier >= 3:
			lines.append([Loc.t("dl_hint_next_push"), _next_push_text()])
	for ln in lines:
		var cap := UI.label(ln[0], "StrongLabel", UI.al())
		cap.add_theme_color_override("font_color", Style.TEAL_DARK)
		_hint_body.add_child(cap)
		var t := UI.label(ln[1], "", UI.al())
		t.custom_minimum_size = Vector2(540, 0)
		_hint_body.add_child(t)
	if tier < 3:
		var more := UI.button(Loc.t("dl_hint_more") if tier == 1 else Loc.t("dl_hint_show_push"), func():
			_hint_tier[_hint_key] = tier + 1
			_fill_hint(), "", 80)
		more.name = "HintMore"
		_hint_body.add_child(more)
	var note := UI.label(Loc.t("dl_hint_note"), "CaptionLabel", UI.al())
	note.custom_minimum_size = Vector2(540, 0)
	_hint_body.add_child(note)

## The cached solution from the current position, or null while searching.
func _solution() -> Dictionary:
	return _cache.get(_hint_key, {})

func _hint() -> Dictionary:
	var sol := _solution()
	if sol.is_empty() or int(sol.status) != DeliverySolver.SOLVED:
		return {}
	return DeliveryHints.from_solution(level, ps.state, sol.pushes)

func _sym_name(i: int) -> String:
	return Loc.t("dl_sym_" + DeliveryLevel.SYMBOL_IDS[level.crate_sym[i]])

func _strategy_text() -> String:
	var sol := _solution()
	if sol.is_empty():
		return Loc.t("dl_hint_thinking")
	var h := _hint()
	if not bool(h.get("ok", false)):
		return Loc.t("dl_hint_timeout")
	var out := Loc.t("dl_hint_focus", [_sym_name(h.crate)])
	if h.away:
		out += " " + Loc.t("dl_hint_away")
	elif int(h.wait_crate) >= 0:
		out += " " + Loc.t("dl_hint_wait", [_sym_name(h.wait_crate)])
	return out + " " + Loc.t("dl_hint_left", [h.pushes_left])

func _next_push_text() -> String:
	var sol := _solution()
	if sol.is_empty():
		return Loc.t("dl_hint_thinking")
	var h := _hint()
	if not bool(h.get("ok", false)):
		return Loc.t("dl_hint_timeout")
	board.hint_crate = h.crate
	board.hint_dir = h.dir
	return Loc.t("dl_hint_next", [_sym_name(h.crate), Loc.t("dl_dir_" + DeliveryRules.DIR_IDS[h.dir])])

## How many undos lead back to a solvable position (searched backwards,
## spread over frames; positions checked earlier come from the cache).
func _stuck_text() -> String:
	if _rewind_result > 0:
		return Loc.t("dl_hint_stuck", [_rewind_result])
	if _rewind_result == 0:
		return Loc.t("dl_hint_stuck_far")
	if _rewind_k == 0:
		_rewind_k = 1
	return Loc.t("dl_hint_thinking")

func _step_rewind() -> void:
	if _rewind_k == 0 or _rewind_result >= 0:
		return
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < FRAME_BUDGET_USEC:
		if _rewind_k > mini(ps.history.size(), 60):
			_rewind_done(0)
			return
		var snap := DeliveryState.from_snapshot(level, ps.history[ps.history.size() - _rewind_k])
		if _rewind_solver == null:
			if DeliveryRules.deadlock(level, snap).code != DeliveryRules.Dead.NONE:
				_rewind_k += 1
				continue
			var key := DeliveryRules.key(level, snap, DeliveryRules.reach(level, snap))
			if _cache.has(key):
				var st := int(_cache[key].status)
				if st == DeliverySolver.SOLVED:
					_rewind_done(_rewind_k)
					return
				if st == DeliverySolver.TIMEOUT:
					_rewind_done(0)
					return
				_rewind_k += 1
				continue
			_rewind_solver = DeliverySolver.new(level, snap, CHECK_NODES)
		_rewind_solver.step(48)
		if _rewind_solver.status == DeliverySolver.RUNNING:
			continue
		var key2 := DeliveryRules.key(level, snap, DeliveryRules.reach(level, snap))
		_cache[key2] = {"status": _rewind_solver.status, "pushes": _rewind_solver.push_list.duplicate()}
		var st2 := _rewind_solver.status
		_rewind_solver = null
		if st2 == DeliverySolver.SOLVED:
			_rewind_done(_rewind_k)
			return
		if st2 == DeliverySolver.TIMEOUT:
			_rewind_done(0)
			return
		_rewind_k += 1

func _rewind_done(k: int) -> void:
	_rewind_result = k
	if _hint_dialog and is_instance_valid(_hint_dialog):
		_fill_hint()

func deadlock_code_now() -> int:
	return DeliveryRules.deadlock(level, ps.state).code

# --------------------------------------------------------------- outcome

func _on_won() -> void:
	if _won:
		return
	_won = true
	_check = null
	board.hint_crate = -1
	App.main.lock_input(700)
	# Only Delivery Logic records change here: the retired sorting mode's
	# stats feed its own achievements and tasks, which must not pay for this.
	var res := DeliveryProgress.record_win(App.data, level, ps)
	App.analytics.event("dl_win", {"level": level_id, "pushes": ps.state.pushes, "steps": ps.state.steps,
		"hints": ps.hints_used, "first": res.first_clear})
	App.save_now()
	_refresh()
	message.modulate.a = 0.0
	App.audio.play("win")
	App.haptic(40)
	var last := index + 1 >= App.delivery.count()
	get_tree().create_timer(App.dur(0.45)).timeout.connect(func():
		if is_inside_tree():
			App.main.lock_input(450)
			App.main.show_overlay(SolvedPanel.create(self, level, res, index, last)))

func next_level() -> void:
	if index + 1 < App.delivery.count():
		App.main.replace("puzzle", {"id": App.delivery.id_at(index + 1)})
	else:
		App.main.goto("home", {"dl_finale": true}, false)

func replay() -> void:
	App.main.replace("puzzle", {"id": level_id})

# --------------------------------------------------------------- pause / leave

func _open_pause() -> void:
	if _won:
		return
	board.finish()
	var d := Dialog.make(Loc.t("paused"), "", [
		[Loc.t("resume"), func(): pass, ""],
		[Loc.t("restart"), _on_restart, "SecondaryButton"],
		[Loc.t("dl_puzzles"), func(): persist(); App.main.goto("home", {}, false); App.main.goto("puzzles"), "SecondaryButton"],
		[Loc.t("settings"), func(): App.main.goto("settings"), "SecondaryButton"],
		[Loc.t("quit_to_home"), func(): persist(); App.main.goto("home", {}, false), "SecondaryButton"],
	], null, "pause")
	App.main.show_overlay(d)

func on_back() -> bool:
	_open_pause()
	return true

func persist() -> void:
	if ps == null or _won:
		return
	DeliveryProgress.save_attempt(App.data, ps)
	App.save_soon()

func _exit_tree() -> void:
	_check = null

## Readouts: delivered x/y, pushes, steps. Pushes and steps are separate on
## purpose: pushes are what the puzzle is about.
class _Hud extends Control:
	var screen: Node

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if screen == null or screen.ps == null:
			return
		var s: DeliveryState = screen.ps.state
		var l: DeliveryLevel = screen.level
		var panel := Style.box(Color(Style.PAPER, 0.96), 20, Style.PAPER_EDGE, 2, false)
		draw_style_box(panel, Rect2(Vector2.ZERO, size))
		var rtl := Loc.is_rtl()
		var cw := size.x / 3.0
		var cols := [
			[Loc.t("dl_hud_delivered"), "%d/%d" % [DeliveryRules.delivered_count(l, s), l.crate_count()], Style.TEAL_DARK],
			[Loc.t("dl_hud_pushes"), str(s.pushes), Style.INK],
			[Loc.t("dl_hud_steps"), str(s.steps), Style.INK_SOFT],
		]
		for i in 3:
			var x := cw * (2 - i if rtl else i)
			if i > 0:
				var lx := x if not rtl else x + cw
				draw_line(Vector2(lx, 12), Vector2(lx, size.y - 12), Color(Style.INK_SOFT, 0.25), 2)
			draw_string(Style.font_regular, Vector2(x, 26), cols[i][0], HORIZONTAL_ALIGNMENT_CENTER, cw, Style.fs(19), Style.INK_SOFT)
			draw_string(Style.font_black, Vector2(x, size.y - 12), cols[i][1], HORIZONTAL_ALIGNMENT_CENTER, cw, Style.fs(32), cols[i][2])
