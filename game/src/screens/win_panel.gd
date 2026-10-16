class_name WinPanel
extends Dialog
## Level-complete card, short and satisfying: the stars land one by one, then
## three stat chips, one rewards line, the next café goal, and at most one
## highlighted notice. Next is the main action; Replay and Return share a row.

static func create(game: Node, kind: String, stars: int, res: Dictionary, ps: PuzzleSession) -> Dialog:
	var d := WinPanel.new()
	d.back_closes = false
	var extra := UI.vbox(16)
	# --- stars
	var star_row := UI.hbox(14)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var g := Glyph.new()
		g.kind = "star" if i < stars else "star_empty"
		g.color = Style.GOLD if i < stars else Color(Style.INK_SOFT, 0.35)
		g.custom_minimum_size = Vector2(112 if i == 1 else 96, 112 if i == 1 else 96)
		g.pivot_offset = g.custom_minimum_size / 2
		star_row.add_child(g)
		if i < stars and not App.reduced_motion():
			g.scale = Vector2.ZERO
			var tw := g.create_tween()
			tw.tween_interval(0.25 + i * 0.22)
			tw.tween_callback(func(): App.audio.play("star", 1.0 + i * 0.12))
			tw.tween_property(g, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(g, "scale", Vector2.ONE, 0.1)
	extra.add_child(star_row)
	# --- stats
	var stats := UI.hbox(10)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(_stat("tap", str(ps.state.moves), Loc.t("stat_moves")))
	stats.add_child(_stat("counter", str(ps.state.peak_counter), Loc.t("stat_peak")))
	stats.add_child(_stat("undo", str(ps.undo_count), Loc.t("stat_undos")))
	extra.add_child(stats)
	# --- rewards line
	var meta: Dictionary = res.get("meta", {})
	if kind in ["campaign", "bakery"]:
		var tok := int(res.get("tokens", 0)) + int(res.get("mastery_tokens", 0))
		var rw := UI.hbox(10)
		rw.alignment = BoxContainer.ALIGNMENT_CENTER
		if tok > 0:
			rw.add_child(UI.pill("coin", "+%d" % tok))
		if bool(res.get("mastery", false)):
			var mp := UI.pill("ribbon", Loc.t("win_mastery_short"), Style.TEAL)
			rw.add_child(mp)
		if rw.get_child_count() > 0:
			extra.add_child(rw)
		else:
			extra.add_child(UI.label(Loc.t("win_no_new_tokens"), "SoftLabel"))
	# --- one tip, the most useful
	var tip := ""
	if stars < 3:
		tip = Loc.t("win_star_tip", [Scoring.par_counter(ps.level)])
	elif kind in ["campaign", "bakery"] and not bool(res.get("mastery", false)):
		tip = Loc.t("win_mastery_tip", [Progression.mastery_target(ps.level)])
	if tip != "":
		var tl := UI.label(tip, "SoftLabel")
		tl.custom_minimum_size = Vector2(500, 0)
		extra.add_child(tl)
	# --- highlights: special reward, achievements, challenge result
	var sp: Dictionary = res.get("special", {})
	if bool(sp.get("new", false)):
		extra.add_child(_notice("spark", Loc.t("reward_" + str(sp.reward).replace(":", "_")), "WarmPanel"))
	if kind == "challenge":
		var met := bool(res.get("met", false))
		var txt := Loc.t("challenge_met") if met else Loc.t("challenge_missed")
		if int(res.get("tokens", 0)) > 0:
			txt += "  " + Loc.t("got_tokens", [int(res.tokens)])
		extra.add_child(_notice("trophy" if met else "info", txt, "TealPanel" if met else "SoftPanel"))
	var news: Array = meta.get("new_achievements", [])
	var tasks := int(meta.get("tasks_ready", 0))
	if not news.is_empty() or tasks > 0:
		var parts: Array = []
		if not news.is_empty():
			parts.append(Loc.t("ach_unlocked", [Loc.t("ach_" + str(news[0]))]) + (" " + Loc.t("win_and_more", [news.size() - 1]) if news.size() > 1 else ""))
		if tasks > 0:
			parts.append(Loc.t("tasks_ready_n", [tasks]))
		extra.add_child(_notice("journal", "\n".join(parts), "SoftPanel"))
	if kind in ["campaign", "bakery"]:
		extra.add_child(_goal())
	# --- actions
	var buttons: Array = []
	if kind in ["campaign", "bakery"]:
		var can_restore := Restoration.can_unlock(App.data)
		var first_restore := can_restore and Restoration.steps(App.data) == 0
		if first_restore:
			buttons.append([Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"])
			buttons.append([Loc.t("next_level"), func(): game.next_level(), ""])
		else:
			buttons.append([Loc.t("next_level"), func(): game.next_level(), ""])
			if can_restore:
				buttons.append([Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"])
		buttons.append([Loc.t("replay"), func(): game.replay(), "SecondaryButton"])
		if kind == "bakery":
			buttons.append([Loc.t("bakery_title"), func(): App.main.goto("home", {}, false); App.main.goto("bakery"), "SecondaryButton"])
		else:
			buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	elif kind == "challenge":
		buttons.append([Loc.t("challenges"), func(): App.main.goto("home", {}, false); App.main.goto("daily"), ""])
		buttons.append([Loc.t("replay"), func(): game.replay(), "SecondaryButton"])
	else:
		buttons.append([Loc.t("share_result"), func():
			App.share_text(Progression.share_text(game.date_key, stars, ps.state.moves))
			App.main.toast(Loc.t("share_copied")), ""])
		buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	var title := Loc.t("win_title")
	if kind == "daily":
		title = Loc.t("daily_done_title")
	elif kind == "challenge":
		title = Loc.t("challenge_done_title")
	d._build(title, "", buttons, extra)
	return d

static func _stat(glyph: String, value: String, caption: String) -> Control:
	var p := PanelContainer.new()
	var sb := Style.box(Style.LINEN, 20, Style.PAPER_EDGE, 2, false)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(150, 0)
	var v := UI.vbox(0)
	var h := UI.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var g := Glyph.new()
	g.kind = glyph
	g.color = Style.TEAL_DARK
	g.custom_minimum_size = Vector2(46, 46)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(g)
	var n := UI.label(value, "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	h.add_child(n)
	v.add_child(h)
	v.add_child(UI.label(caption, "CaptionLabel"))
	p.add_child(v)
	return p

static func _notice(glyph: String, text: String, panel: String) -> Control:
	var r := UI.hbox(12)
	r.add_child(UI.medallion(glyph, Style.PAPER, Style.TERRACOTTA if panel == "WarmPanel" else Style.TEAL_DARK, 52))
	var l := UI.label(text, "StrongLabel", UI.al())
	l.add_theme_font_size_override("font_size", Style.fs(24))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(380, 0)
	r.add_child(l)
	return UI.card(r, panel)

## The next café step, as one line with a bar.
static func _goal() -> Control:
	var i := Restoration.next_index(App.data)
	var have := int(App.data.tokens)
	var r := UI.hbox(12)
	if i < 0:
		r.add_child(UI.medallion("spark", Style.GOLD_SOFT, Style.GOLD_EDGE, 48))
		r.add_child(UI.label(Loc.t("cafe_complete_extras"), "SoftLabel", UI.al()))
		return r
	var st: Dictionary = Restoration.STEPS[i]
	var ready := have >= int(st.cost)
	r.add_child(UI.medallion("brush", Style.TERRA_SOFT if ready else Style.GOLD_SOFT, Style.TERRACOTTA if ready else Style.GOLD_EDGE, 48))
	var col := UI.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UI.label(Loc.t("next_step", [Loc.t("step_" + str(st.id))]), "StrongLabel", UI.al(), false)
	t.add_theme_font_size_override("font_size", Style.fs(24))
	col.add_child(t)
	col.add_child(UI.progress(mini(have, int(st.cost)), int(st.cost), Style.TERRACOTTA if ready else Style.GOLD, 14))
	r.add_child(col)
	r.add_child(UI.label(Loc.t("ready") if ready else "%d/%d" % [have, int(st.cost)], "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
	return r
