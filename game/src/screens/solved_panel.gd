class_name SolvedPanel
extends Dialog
## "Puzzle Solved!" card for Delivery Logic. The level title, pushes and
## steps (clearly separate), the completion reward actually paid (or that it
## was already collected), the personal best and the medals. "Next Puzzle" is
## the only primary action; Replay and Home share a row underneath.
## Medals are records only: the fewest-pushes medal compares against the
## level's PROVED minimum (data/delivery/proofs.json), never a target.

static func create(game: Node, l: DeliveryLevel, res: Dictionary, index: int, last: bool) -> Dialog:
	var d := SolvedPanel.new()
	d.back_closes = false
	var extra := UI.vbox(12)
	var sub := UI.label(Loc.t("dl_title_line", [index + 1, l.title()]), "SoftLabel")
	extra.add_child(sub)
	# pushes and steps, side by side
	var stats := UI.hbox(14)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(_stat(str(res.pushes), Loc.t("dl_res_pushes"), Style.TEAL_DARK))
	stats.add_child(_stat(str(res.steps), Loc.t("dl_res_steps"), Style.INK_SOFT))
	extra.add_child(stats)
	# personal best
	if bool(res.get("new_best", false)):
		var t := UI.tag(Loc.t("dl_res_new_best"), Style.GOLD_SOFT, Style.INK)
		t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		extra.add_child(t)
	elif bool(res.get("had_best", false)):
		extra.add_child(UI.label(Loc.t("dl_res_best", [res.best_pushes, res.best_steps]), "CaptionLabel"))
	# completion reward, paid once per level
	var tok := int(res.get("tokens", 0))
	if tok > 0:
		var rw := UI.hbox(12)
		rw.alignment = BoxContainer.ALIGNMENT_CENTER
		rw.add_child(UI.label(Loc.t("dl_res_reward"), "StrongLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		var pill := UI.pill("coin", "+%d" % tok)
		pill.name = "RewardPill"
		rw.add_child(pill)
		if not App.reduced_motion():
			pill.pivot_offset = Vector2(60, 28)
			pill.scale = Vector2(0.6, 0.6)
			var tw := pill.create_tween()
			tw.tween_interval(0.35)
			tw.tween_callback(func(): App.audio.play("coin"))
			tw.tween_property(pill, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(pill, "scale", Vector2.ONE, 0.1)
		extra.add_child(rw)
	else:
		var nl := UI.label(Loc.t("dl_res_reward_done"), "CaptionLabel")
		nl.custom_minimum_size = Vector2(500, 0)
		extra.add_child(nl)
	# medals: proven fewest pushes, unassisted
	var mp := int(res.get("min_pushes", -1))
	if bool(res.get("fewest", false)):
		extra.add_child(_medal("trophy", Loc.t("dl_medal_fewest", [mp]), true))
	elif mp > 0:
		extra.add_child(_medal("target", Loc.t("dl_medal_fewest_try", [mp]), false))
	if bool(res.get("unassisted", false)):
		extra.add_child(_medal("ribbon", Loc.t("dl_medal_unassisted"), true))
	var buttons: Array = [
		[Loc.t("dl_finish") if last else Loc.t("dl_next_puzzle"), func(): game.next_level(), ""],
		[Loc.t("replay"), func(): game.replay(), "SecondaryButton"],
		[Loc.t("dl_home"), func(): App.main.goto("home", {}, false), "SecondaryButton"],
	]
	d._build(Loc.t("dl_solved_title"), "", buttons, extra)
	return d

static func _stat(value: String, caption: String, color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := Style.box(Style.LINEN, 20, Style.PAPER_EDGE, 2, false)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(190, 0)
	var v := UI.vbox(0)
	var n := UI.label(value, "DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	n.add_theme_color_override("font_color", color)
	v.add_child(n)
	v.add_child(UI.label(caption, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
	p.add_child(v)
	return p

static func _medal(glyph: String, text: String, earned: bool) -> Control:
	var r := UI.hbox(12)
	r.add_child(UI.medallion(glyph, Style.GOLD_SOFT if earned else Style.CREAM_DEEP, Style.GOLD_EDGE if earned else Style.INK_SOFT, 48))
	var l := UI.label(text, "StrongLabel" if earned else "SoftLabel", UI.al())
	l.add_theme_font_size_override("font_size", Style.fs(23))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(380, 0)
	r.add_child(l)
	return r
