class_name WinPanel
extends Dialog
## Level-complete card: animated stars, tokens earned (one per new star), the
## next restoration goal with progress, new achievements and ready tasks.

static func create(game: Node, kind: String, stars: int, res: Dictionary, ps: PuzzleSession) -> Dialog:
	var d := WinPanel.new()
	d.back_closes = false
	var extra := UI.vbox(12)
	var star_row := UI.hbox(18)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var g := Glyph.new()
		g.kind = "star"
		g.color = Style.GOLD if i < stars else Color(Style.INK_SOFT, 0.25)
		g.custom_minimum_size = Vector2(100, 100)
		g.pivot_offset = Vector2(50, 50)
		star_row.add_child(g)
		if i < stars and not App.reduced_motion():
			g.scale = Vector2.ZERO
			var tw := g.create_tween()
			tw.tween_interval(0.2 + i * 0.22)
			tw.tween_callback(func(): App.audio.play("star", 1.0 + i * 0.12))
			tw.tween_property(g, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(g, "scale", Vector2.ONE, 0.1)
	extra.add_child(star_row)
	var stats := UI.label(Loc.t("win_stats", [ps.state.moves, ps.state.peak_counter, ps.undo_count]), "SoftLabel")
	stats.custom_minimum_size = Vector2(540, 0)
	extra.add_child(stats)
	if stars < 3:
		var tip := UI.label(Loc.t("win_star_tip", [Scoring.par_counter(ps.level)]), "SoftLabel")
		tip.custom_minimum_size = Vector2(540, 0)
		extra.add_child(tip)
	var meta: Dictionary = res.get("meta", {})
	if kind == "campaign":
		var tok := int(res.get("tokens", 0))
		var row := UI.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var coin := Glyph.new()
		coin.kind = "coin"
		coin.color = Style.GOLD
		coin.custom_minimum_size = Vector2(52, 52)
		row.add_child(coin)
		var tl := UI.label(Loc.t("win_tokens", [tok]) if tok > 0 else Loc.t("win_no_new_tokens"), "HeaderLabel" if tok > 0 else "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, tok <= 0)
		if tok <= 0:
			tl.custom_minimum_size = Vector2(460, 0)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		extra.add_child(row)
		extra.add_child(GoalBar.make(App.data))
	var news: Array = meta.get("new_achievements", [])
	for i in mini(news.size(), 2):
		var a: String = news[i]
		var txt := Loc.t("ach_unlocked", [Loc.t("ach_" + a)])
		if i == 1 and news.size() > 2:
			txt = Loc.t("ach_more", [news.size() - 1])
		var al := UI.label(txt, "")
		al.add_theme_color_override("font_color", Style.TERRACOTTA)
		al.custom_minimum_size = Vector2(540, 0)
		extra.add_child(al)
	if int(meta.get("tasks_ready", 0)) > 0:
		extra.add_child(UI.label(Loc.t("tasks_ready_n", [int(meta.tasks_ready)]), "SoftLabel"))
	var buttons: Array = []
	if kind == "campaign":
		var can_restore := Restoration.can_unlock(App.data)
		var first_restore := can_restore and Restoration.steps(App.data) == 0
		if first_restore:
			buttons.append([Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"])
			buttons.append([Loc.t("next_level"), func(): game.next_level(), "SecondaryButton"])
		else:
			buttons.append([Loc.t("next_level"), func(): game.next_level(), ""])
			if can_restore:
				buttons.append([Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"])
		buttons.append([Loc.t("replay"), func(): game.replay(), "SecondaryButton"])
		buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	else:
		buttons.append([Loc.t("share_result"), func():
			App.share_text(Progression.share_text(game.date_key, stars, ps.state.moves))
			App.main.toast(Loc.t("share_copied")), ""])
		buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	d._build(Loc.t("win_title") if kind == "campaign" else Loc.t("daily_done_title"), "", buttons, extra)
	return d
