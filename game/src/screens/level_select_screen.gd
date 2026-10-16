extends Control
## Campaign map: a scrolling grid grouped by chapter (chapters come from
## campaign.json). Each chapter shows its progress; levels that introduce a
## mechanic carry a small marker so returning players can find them.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("levels"), func(): App.main.back()))
	var prog := App.progression
	root.add_child(UI.label(Loc.t("stars_total", [prog.total_stars(App.data), prog.campaign.size() * 3]), "SoftLabel"))
	var list := UI.vbox(18)
	var focus_cell: Control
	var nxt := prog.next_level_index(App.data)
	for ci in prog.chapters.size():
		var r := prog.chapter_range(ci)
		var cleared := 0
		for i in range(r.x, r.y):
			if Progression.is_cleared(App.data, prog.campaign[i].id):
				cleared += 1
		var head := UI.hbox(10)
		var t := UI.label(Loc.t(str(prog.chapters[ci].title)), "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT, false)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		head.add_child(UI.label("%d/%d" % [cleared, r.y - r.x], "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		list.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		list.add_child(grid)
		for i in range(r.x, r.y):
			var cell := _cell(i)
			grid.add_child(cell)
			if i == nxt:
				focus_cell = cell
	var sc := UI.scroll(list)
	root.add_child(sc)
	if focus_cell:
		(func(): await get_tree().process_frame; sc.ensure_control_visible(focus_cell)).call_deferred()

func _cell(i: int) -> Control:
	var id: String = App.progression.campaign[i].id
	var unlocked := App.progression.is_unlocked(App.data, i)
	var cleared := Progression.is_cleared(App.data, id)
	var stars := int(App.data.campaign.stars.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = "SecondaryButton" if cleared or not unlocked else ""
	b.disabled = not unlocked
	# Levels that introduce a mechanic say so until cleared.
	var tut := str(App.progression.campaign[i].get("meta", {}).get("tutorial", ""))
	var intro := tut in ["tut_fresh", "tut_bag", "tut_lock", "tut_two_stage"]
	var second := UI.stars_text(stars) if cleared else (Loc.t("new_mark") if intro and unlocked else ("" if unlocked else "·"))
	b.text = str(i + 1) + "\n" + second
	b.add_theme_font_size_override("font_size", Style.fs(28))
	if not unlocked:
		b.tooltip_text = Loc.t("locked")
	b.pressed.connect(func():
		App.audio.play("tap")
		App.main.goto("game", {"kind": "campaign", "id": id}))
	return b
