extends Control
## Delivery Logic puzzle list. Chapters are sections; each puzzle is a row
## with its number, title and state: solved (best pushes, medals), next (play
## mark) or locked (padlock; a tap says what opens it). A sticky button plays
## the next puzzle. QA builds (export feature "qa") open every puzzle and say
## so; player builds never do.

var default_focus: Control   # keyboard / pad players start on the play button

func setup(_p: Dictionary) -> void:
	var dp := App.delivery
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var done := UI.pill("check", Loc.t("dl_done_count", [dp.cleared_count(App.data), dp.count()]), Style.TEAL)
	root.add_child(UI.header(Loc.t("dl_puzzles_title"), func(): App.main.back(), done))
	if BuildConfig.qa_unlock_all():
		root.add_child(UI.card(UI.label(Loc.t("dl_qa_build"), "StrongLabel"), "WarmPanel"))
	var list := UI.vbox(14)
	root.add_child(UI.scroll(list))
	var nxt := dp.next_index(App.data)
	for ci in dp.chapters.size():
		var r := dp.chapter_range(ci)
		list.add_child(UI.section(Loc.t(str(dp.chapters[ci].title)), "levels"))
		for i in range(r.x, r.y):
			list.add_child(_row(i, i == nxt and not dp.all_cleared(App.data)))
	var cur := DeliveryProgress.current_id(App.data)
	var play_i := dp.index_of(cur) if cur != "" and dp.index_of(cur) >= 0 else nxt
	var txt := Loc.t("dl_continue_n", [play_i + 1]) if cur != "" and dp.index_of(cur) >= 0 else Loc.t("dl_play_n", [play_i + 1])
	var b := UI.icon_text_button("play", txt, func(): App.main.goto("puzzle", {"id": dp.id_at(play_i)}), "", 104)
	root.add_child(b)
	default_focus = b

func _row(i: int, is_next: bool) -> Control:
	var dp := App.delivery
	var id := dp.id_at(i)
	var l := dp.level(id)
	var open := dp.is_unlocked(App.data, i)
	var solved := DeliveryProgress.is_cleared(App.data, id)
	var b := Button.new()
	b.theme_type_variation = "TileButton" if open else "GhostButton"
	b.custom_minimum_size = Vector2(0, 104)
	b.name = "Puzzle_%s" % id
	UI._wire(b, func():
		if dp.is_unlocked(App.data, i):
			App.main.goto("puzzle", {"id": id})
		else:
			App.main.toast(Loc.t("dl_locked_tip", [i])))
	var r := UI.hbox(14)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 16
	r.offset_right = -16
	r.offset_bottom = -Style.EDGE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	var glyph := "check" if solved else ("play" if is_next else ("lock" if not open else "levels"))
	var bg := Style.TEAL_SOFT if solved else (Style.TEAL if is_next else Style.CREAM_DEEP)
	var fg := Style.TEAL_DARK if solved else (Color.WHITE if is_next else Style.INK_SOFT)
	r.add_child(UI.medallion(glyph, bg, fg, 64))
	var col := UI.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UI.label(Loc.t("dl_title_line", [i + 1, l.title()]), "StrongLabel", UI.al(), false)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_theme_color_override("font_color", Style.INK if open else Style.INK_SOFT)
	col.add_child(t)
	var sub := ""
	if solved:
		var best := DeliveryProgress.best(App.data, id)
		if not best.is_empty():
			sub = Loc.t("dl_res_best", [best.pushes, best.steps])
	elif not open:
		sub = Loc.t("dl_locked_tip", [i])
	if sub != "":
		col.add_child(UI.label(sub, "CaptionLabel", UI.al(), false))
	r.add_child(col)
	if DeliveryProgress.medal(App.data, id, "fewest"):
		r.add_child(_mini("trophy"))
	if DeliveryProgress.medal(App.data, id, "unassisted"):
		r.add_child(_mini("ribbon"))
	for c in r.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in col.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _mini(glyph: String) -> Control:
	var g := Glyph.new()
	g.kind = glyph
	g.color = Style.GOLD_EDGE
	g.custom_minimum_size = Vector2(40, 40)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return g
