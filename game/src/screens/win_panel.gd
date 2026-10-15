class_name WinPanel
extends Dialog
## Level-complete card: animated stars, first-clear token, restoration nudge.

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
		g.custom_minimum_size = Vector2(96, 96)
		g.pivot_offset = Vector2(48, 48)
		star_row.add_child(g)
		if i < stars and not App.reduced_motion():
			g.scale = Vector2.ZERO
			var tw := g.create_tween()
			tw.tween_interval(0.25 + i * 0.22)
			tw.tween_callback(func(): App.audio.play("star", 1.0 + i * 0.12))
			tw.tween_property(g, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	extra.add_child(star_row)
	var lines: Array = []
	lines.append(Loc.t("win_stats", [ps.state.moves, ps.state.peak_counter, ps.undo_count]))
	if stars < 3:
		lines.append(Loc.t("win_star_tip", [Scoring.par_counter(ps.level)]))
	if kind == "campaign" and int(res.get("tokens", 0)) > 0:
		lines.append(Loc.t("win_token", [res.tokens]))
	elif kind == "campaign":
		lines.append(Loc.t("win_replay_no_token"))
	for t in lines:
		var l := UI.label(t, "SoftLabel")
		l.custom_minimum_size = Vector2(540, 0)
		extra.add_child(l)
	var buttons: Array = []
	if kind == "campaign":
		if Restoration.can_unlock(App.data):
			buttons.append([Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"])
		buttons.append([Loc.t("next_level"), func(): game.next_level(), ""])
		buttons.append([Loc.t("replay"), func(): game.replay(), "SecondaryButton"])
		buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	else:
		buttons.append([Loc.t("share_result"), func():
			App.share_text(Progression.share_text(game.date_key, stars, ps.state.moves))
			App.main.toast(Loc.t("share_copied")), ""])
		buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	d._build(Loc.t("win_title") if kind == "campaign" else Loc.t("daily_done_title"), "", buttons, extra)
	return d
