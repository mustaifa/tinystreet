extends Control
## Campaign map. Chapters (from campaign.json) are cards with their progress
## and stars. The chapter you are playing is open; finished chapters fold away
## to one line (tap to open), and locked chapters say what opens them.
## Level cells have four clearly different states:
##   completed  paper key, number and three stars (gold = earned)
##   current    teal key with a play mark: the next level to play
##   locked     flat, faint number and a padlock; a tap explains the unlock
##   mastered   a teal rosette on a completed cell
## Levels that introduce a mechanic carry a "NEW" tag until cleared; special
## orders and the bell lesson carry a small gold bell.
## A sticky button at the bottom always plays the next level.

var _open := {}           # chapter index -> expanded (this visit only)
var _list: VBoxContainer
var _scroll: ScrollContainer

func setup(_p: Dictionary) -> void:
	var prog := App.progression
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var stars := UI.pill("star", "%d/%d" % [prog.total_stars(App.data), prog.campaign.size() * 3])
	root.add_child(UI.header(Loc.t("levels"), func(): App.main.back(), stars))
	_list = UI.vbox(16)
	_scroll = UI.scroll(_list)
	root.add_child(_scroll)
	var nxt := prog.next_level_index(App.data)
	for ci in prog.chapters.size():
		var r := prog.chapter_range(ci)
		var cleared := _cleared_in(r)
		_open[ci] = (nxt >= r.x and nxt < r.y) or (cleared < r.y - r.x and prog.is_unlocked(App.data, r.x))
	_fill()
	var all_done := prog.cleared_count(App.data) >= prog.campaign.size()
	var cur: Dictionary = App.data.current
	var play_id: String = prog.campaign[nxt].id
	var title := Loc.t("play_level", [nxt + 1])
	if cur.get("kind", "") == "campaign" and cur.has("id") and prog.campaign_index(cur.id) >= 0:
		play_id = cur.id
		title = Loc.t("continue_level", [prog.campaign_index(cur.id) + 1])
	if not all_done or cur.has("id"):
		var b := UI.icon_text_button("play", title, func(): App.main.goto("game", {"kind": "campaign", "id": play_id}), "", 104)
		root.add_child(b)

func _cleared_in(r: Vector2i) -> int:
	var n := 0
	for i in range(r.x, r.y):
		if Progression.is_cleared(App.data, App.progression.campaign[i].id):
			n += 1
	return n

func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var prog := App.progression
	var nxt := prog.next_level_index(App.data)
	var focus: Control
	for ci in prog.chapters.size():
		var r := prog.chapter_range(ci)
		var card := _chapter(ci, r)
		_list.add_child(card)
		if nxt >= r.x and nxt < r.y:
			focus = card
	if focus:
		(func():
			await get_tree().process_frame
			await get_tree().process_frame
			if is_instance_valid(focus) and is_instance_valid(_scroll):
				_scroll.scroll_vertical = int(maxf(0.0, focus.position.y - 12))).call_deferred()

func _chapter(ci: int, r: Vector2i) -> Control:
	var prog := App.progression
	var n := r.y - r.x
	var cleared := _cleared_in(r)
	var stars := 0
	for i in range(r.x, r.y):
		stars += int(App.data.campaign.stars.get(prog.campaign[i].id, 0))
	var unlocked := prog.is_unlocked(App.data, r.x)
	var done := cleared >= n
	var v := UI.vbox(12)
	# header: number medallion, title, counts; tap toggles the grid
	var head := Button.new()
	head.theme_type_variation = "GhostButton"
	head.custom_minimum_size = Vector2(0, 84)
	UI._wire(head, func():
		_open[ci] = not bool(_open.get(ci, false))
		_fill())
	var hr := UI.hbox(14)
	hr.set_anchors_preset(Control.PRESET_FULL_RECT)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var med := _ChapterBadge.new()
	med.n = ci + 1
	med.state = 2 if done else (1 if unlocked else 0)
	med.custom_minimum_size = Vector2(64, 64)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(med)
	var col := UI.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(Loc.t(str(prog.chapters[ci].title)), "HeaderLabel" if unlocked else "StrongLabel", UI.al(), false)
	t.add_theme_font_size_override("font_size", Style.fs(29))
	if not unlocked:
		t.add_theme_color_override("font_color", Style.INK_SOFT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var sub := ""
	if not unlocked:
		sub = Loc.t("chapter_locked", [r.x])
	elif done:
		sub = Loc.t("chapter_done", [n])
	else:
		sub = Loc.t("chapter_progress", [cleared, n])
	var sl := UI.label(sub, "CaptionLabel", UI.al(), false)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sl)
	hr.add_child(col)
	if unlocked:
		var sp := UI.hbox(4)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sg := Glyph.new()
		sg.kind = "star"
		sg.color = Style.GOLD
		sg.custom_minimum_size = Vector2(32, 32)
		sg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sp.add_child(sg)
		var stl := UI.label("%d/%d" % [stars, n * 3], "StrongLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
		stl.add_theme_font_size_override("font_size", Style.fs(24))
		stl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.add_child(stl)
		sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(sp)
	var chev := Glyph.new()
	chev.kind = "chevron"
	chev.color = Style.INK_SOFT
	chev.custom_minimum_size = Vector2(30, 30)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chev.rotation = PI / 2 if bool(_open.get(ci, false)) else 0.0
	chev.pivot_offset = Vector2(15, 15)
	hr.add_child(chev)
	head.add_child(hr)
	v.add_child(head)
	if unlocked:
		v.add_child(UI.progress(cleared, n, Style.TEAL, 12))
	if bool(_open.get(ci, false)):
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 12)
		for i in range(r.x, r.y):
			grid.add_child(_cell(i))
		v.add_child(grid)
	return UI.card(v, "CardPanel" if unlocked else "SoftPanel")

func _cell(i: int) -> Control:
	var prog := App.progression
	var lvl: Dictionary = prog.campaign[i]
	var id: String = lvl.id
	var b := LevelCell.new()
	b.number = i + 1
	b.unlocked = prog.is_unlocked(App.data, i)
	b.cleared = Progression.is_cleared(App.data, id)
	b.stars = int(App.data.campaign.stars.get(id, 0))
	b.current = i == prog.next_level_index(App.data) and not b.cleared
	b.mastered = Progression.has_mastery(App.data, id)
	var tut := str(lvl.get("meta", {}).get("tutorial", ""))
	b.is_new = tut in ["tut_fresh", "tut_bag", "tut_lock", "tut_two_stage", "tut_bell"] and b.unlocked and not b.cleared
	b.bell = tut == "tut_bell" or lvl.get("meta", {}).has("special")
	b.custom_minimum_size = Vector2(0, 116)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.apply_style()
	UI._wire(b, func():
		if not b.unlocked:
			App.main.toast(Loc.t("locked_hint", [_first_open_before(i) + 1]))
			return
		App.main.goto("game", {"kind": "campaign", "id": id}))
	return b

## The level a player must clear to open level i (the last uncleared before it).
func _first_open_before(i: int) -> int:
	var prog := App.progression
	for k in range(i - 1, -1, -1):
		if prog.is_unlocked(App.data, k) and not Progression.is_cleared(App.data, prog.campaign[k].id):
			return k
	return maxi(0, i - 1)

## Chapter number: teal with a tick when finished, ink when open, faint when locked.
class _ChapterBadge extends Control:
	var n := 1
	var state := 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var bg := Style.TEAL if state == 2 else (Style.GOLD_SOFT if state == 1 else Style.CREAM_DEEP)
		draw_circle(c, r, bg)
		if state == 2:
			Glyph.paint(self, "check", Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Color.WHITE)
		elif state == 0:
			Glyph.paint(self, "lock", Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), Style.INK_SOFT)
		else:
			draw_string(Style.font_black, Vector2(0, c.y + 11), str(n), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Style.GOLD_EDGE.darkened(0.2))
