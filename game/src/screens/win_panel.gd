class_name WinPanel
extends Dialog
## Level-complete card (v7): the result first, then the way on. The title,
## stars and a counting score land together; a breakdown line explains the
## points, then the tokens actually paid and the next café goal. "Next level"
## is the only primary action; Replay and Café share a row underneath.
## A story beat earned by this win plays after the card, when the player
## moves on (never before the result).

static func create(game: Node, kind: String, stars: int, res: Dictionary, ps: PuzzleSession, beat: String = "") -> Dialog:
	var d := WinPanel.new()
	d.back_closes = false
	var then := func(cb: Callable) -> Callable:
		return cb if beat == "" else func(): Story.play(beat, cb)
	var extra := UI.vbox(10)
	# --- stars
	var star_row := UI.hbox(14)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var g := Glyph.new()
		g.kind = "star" if i < stars else "star_empty"
		g.color = Style.GOLD if i < stars else Color(Style.INK_SOFT, 0.35)
		g.custom_minimum_size = Vector2(88 if i == 1 else 74, 88 if i == 1 else 74)
		g.pivot_offset = g.custom_minimum_size / 2
		star_row.add_child(g)
		if i < stars and not App.reduced_motion():
			g.scale = Vector2.ZERO
			var tw := g.create_tween()
			tw.tween_interval(0.2 + i * 0.2)
			tw.tween_callback(func(): App.audio.play("star", 1.0 + i * 0.12))
			tw.tween_property(g, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(g, "scale", Vector2.ONE, 0.1)
	extra.add_child(star_row)
	# --- score: the number, personal best, and where it came from
	var b := Scoring.breakdown(ps.state)
	extra.add_child(_score_row(int(b.total), res, kind in ["campaign", "bakery"]))
	var why := Loc.t("win_breakdown", [b.direct, b.via_counter, b.orders])
	if int(b.tidy) > 0:
		why += " · " + Loc.t("win_tidy", [b.tidy])
	var wl := UI.label(why, "CaptionLabel")
	wl.custom_minimum_size = Vector2(520, 0)
	extra.add_child(wl)
	# --- tokens actually paid (campaign and bakery)
	if kind in ["campaign", "bakery"]:
		var tok := int(res.get("tokens", 0)) + int(res.get("mastery_tokens", 0))
		var rw := UI.hbox(10)
		rw.alignment = BoxContainer.ALIGNMENT_CENTER
		if tok > 0:
			rw.add_child(_coin_reward(tok))
		if bool(res.get("mastery", false)):
			rw.add_child(UI.pill("ribbon", Loc.t("win_mastery_short"), Style.TEAL))
		if rw.get_child_count() > 0:
			extra.add_child(rw)
		if tok > 0:
			extra.add_child(UI.label(Loc.t("win_tokens_caption"), "CaptionLabel"))
		else:
			var nl := UI.label(Loc.t("win_no_new_tokens"), "SoftLabel")
			nl.custom_minimum_size = Vector2(500, 0)
			extra.add_child(nl)
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
	# --- highlights: special reward, challenge result
	var sp: Dictionary = res.get("special", {})
	if bool(sp.get("new", false)):
		extra.add_child(_notice("spark", Loc.t("reward_" + str(sp.reward).replace(":", "_")), "WarmPanel"))
	if kind == "challenge":
		var met := bool(res.get("met", false))
		var txt := Loc.t("challenge_met") if met else Loc.t("challenge_missed")
		if int(res.get("tokens", 0)) > 0:
			txt += "  " + Loc.t("got_tokens", [int(res.tokens)])
		extra.add_child(_notice("trophy" if met else "info", txt, "TealPanel" if met else "SoftPanel"))
	# Awards and café tasks are not repeated here: the home screen badges them.
	if kind in ["campaign", "bakery"]:
		extra.add_child(_goal(then.call(func(): d.close(); App.main.goto("restore"))))
	# --- actions: one primary
	var buttons: Array = []
	if kind in ["campaign", "bakery"]:
		buttons.append([_next_text(kind, ps.level.id), then.call(func(): game.next_level()), ""])
		buttons.append([Loc.t("replay"), then.call(func(): game.replay()), "SecondaryButton"])
		if kind == "bakery":
			buttons.append([Loc.t("bakery_title"), then.call(func(): App.main.goto("home", {}, false); App.main.goto("bakery")), "SecondaryButton"])
		else:
			buttons.append([Loc.t("to_cafe"), then.call(func(): App.main.goto("home", {}, false)), "SecondaryButton"])
	elif kind == "challenge":
		buttons.append([Loc.t("challenges"), func(): App.main.goto("home", {}, false); App.main.goto("daily"), ""])
		buttons.append([Loc.t("replay"), func(): game.replay(), "SecondaryButton"])
	else:
		buttons.append([Loc.t("share_result"), func():
			App.share_text(Progression.share_text(game.date_key, stars, ps.state.moves))
			App.main.toast(Loc.t("share_copied")), ""])
		buttons.append([Loc.t("to_cafe"), func(): App.main.goto("home", {}, false), "SecondaryButton"])
	var title := Loc.t("win_level_complete")
	if kind == "daily":
		title = Loc.t("daily_done_title")
	elif kind == "challenge":
		title = Loc.t("challenge_done_title")
	d._build(title, "", buttons, extra)
	return d

## The main action's wording: the last level leads to the finale, not to a
## level that doesn't exist.
static func _next_text(kind: String, id: String) -> String:
	if kind == "bakery":
		var bi := App.progression.bakery_index(id)
		return Loc.t("next_level") if bi + 1 < App.progression.bakery.size() else Loc.t("bakery_finish")
	var i := App.progression.campaign_index(id)
	return Loc.t("next_level") if i + 1 < App.progression.campaign.size() else Loc.t("campaign_finish")

## The score counts up while the stars land; then "New best!" or the best.
static func _score_row(total: int, res: Dictionary, with_best: bool) -> Control:
	var col := UI.hbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap := UI.label(Loc.t("hud_score"), "StrongLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(cap)
	var n := UI.label(str(total), "DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	n.add_theme_color_override("font_color", Style.TEAL_DARK)
	col.add_child(n)
	if with_best:
		if bool(res.get("new_best", false)):
			var t := UI.tag(Loc.t("win_new_best"), Style.GOLD_SOFT, Style.INK)
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			col.add_child(t)
		elif int(res.get("best", 0)) > total:
			var bl := UI.label(Loc.t("win_score_best", [int(res.best)]), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
			bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			col.add_child(bl)
	if not App.reduced_motion() and total > 0:
		n.text = "0"
		var tw := n.create_tween()
		tw.tween_interval(0.2)
		tw.tween_method(func(v: float): n.text = str(int(round(v))), 0.0, float(total), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(func(): App.audio.play("stage"))
	return col

## A large coin pill whose number counts up after the stars have landed.
static func _coin_reward(n: int) -> Control:
	var p := UI.pill("coin", "+0")
	p.scale = Vector2(1.25, 1.25)
	p.custom_minimum_size = Vector2(150, 0)
	var l: Label = null
	for c in p.find_children("*", "Label", true, false):
		l = c
	if l == null or App.reduced_motion():
		if l:
			l.text = "+%d" % n
		return p
	var tw := p.create_tween()
	tw.tween_interval(0.95)
	tw.tween_method(func(v: float):
		var t := "+%d" % int(round(v))
		if l.text != t:
			l.text = t
			App.audio.play("coin", 1.0 + v * 0.02), 0.0, float(n), minf(0.9, 0.12 * n))
	tw.tween_callback(func(): p.pivot_offset = p.size / 2)
	tw.tween_property(p, "scale", Vector2(1.4, 1.4), 0.1)
	tw.tween_property(p, "scale", Vector2(1.25, 1.25), 0.12)
	return p

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
static func _goal(restore: Callable) -> Control:
	var i := Restoration.next_index(App.data)
	var have := int(App.data.tokens)
	var r := UI.hbox(12)
	if i < 0:
		r.add_child(UI.medallion("spark", Style.GOLD_SOFT, Style.GOLD_EDGE, 48))
		var done := UI.label(Loc.t("cafe_complete_extras"), "SoftLabel", UI.al())
		done.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # a wrapping label in a row needs width
		r.add_child(done)
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
	if ready and Restoration.can_unlock(App.data):
		var b := UI.button(Loc.t("restore_short"), restore, "WarmButton", 64)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF   # one word: size to it, never break it
		b.custom_minimum_size.x = 150
		r.add_child(b)
	else:
		r.add_child(UI.label("%d/%d" % [have, int(st.cost)], "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
	return r
