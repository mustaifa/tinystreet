extends Control
## Campaign map as a scrolling grid grouped by chapter.

const CHAPTERS := [[1, "ch_intro"], [6, "ch_sequencing"], [16, "ch_pressure"], [31, "ch_two_stage"], [46, "ch_mastery"]]

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("levels"), func(): App.main.back()))
	root.add_child(UI.label(Loc.t("stars_total", [App.progression.total_stars(App.data), App.progression.campaign.size() * 3]), "SoftLabel"))
	var list := UI.vbox(18)
	var grid: GridContainer
	var focus_cell: Control
	var nxt := App.progression.next_level_index(App.data)
	for i in App.progression.campaign.size():
		for ch in CHAPTERS:
			if ch[0] == i + 1:
				list.add_child(UI.label(Loc.t(ch[1]), "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT))
				grid = GridContainer.new()
				grid.columns = 5
				grid.add_theme_constant_override("h_separation", 12)
				grid.add_theme_constant_override("v_separation", 12)
				list.add_child(grid)
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
	var stars := int(App.data.campaign.stars.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = "SecondaryButton" if Progression.is_cleared(App.data, id) or not unlocked else ""
	b.disabled = not unlocked
	b.text = str(i + 1) + "\n" + (UI.stars_text(stars) if Progression.is_cleared(App.data, id) else ("" if unlocked else "·"))
	b.add_theme_font_size_override("font_size", Style.fs(28))
	if not unlocked:
		b.tooltip_text = Loc.t("locked")
	b.pressed.connect(func():
		App.audio.play("tap")
		App.main.goto("game", {"kind": "campaign", "id": id}))
	return b
