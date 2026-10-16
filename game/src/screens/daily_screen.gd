extends Control
## Challenges: challenge cards (v3), the Daily puzzle and the optional Café
## Rush. The Daily shows "days played" (never resets) instead of a streak, so
## missing a day is never punished.
## Daily basis: the device's local calendar date (resets at local midnight).
## Same app version + date => same puzzle. Rewards are a record, a streak and
## progress toward tasks/achievements; device clocks can be changed, so none
## of this is presented as a secure or competitive event.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(16)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("challenges"), func(): App.main.back()))
	var v := UI.vbox(16)
	root.add_child(UI.scroll(v))
	# --- challenge cards
	_cards(v)
	# --- daily
	var today := Progression.today_key()
	var id := App.progression.daily_level_id(today)
	var daily := UI.vbox(12)
	daily.add_child(UI.label(Loc.t("daily"), "TitleLabel"))
	daily.add_child(UI.label(Loc.t("daily_date", [today]), "HeaderLabel"))
	daily.add_child(UI.label(Loc.t("daily_basis"), "SoftLabel"))
	var done := Progression.is_daily_done(App.data, today)
	daily.add_child(UI.label(Loc.t("daily_days", [App.data.daily.completed.size()]), ""))
	if done:
		var rec: Dictionary = App.data.daily.completed[today]
		daily.add_child(UI.label(Loc.t("daily_done", [UI.stars_text(int(rec.stars)), int(rec.moves)]), "HeaderLabel"))
		daily.add_child(UI.button(Loc.t("share_result"), func():
			App.share_text(Progression.share_text(today, int(rec.stars), int(rec.moves)))
			App.main.toast(Loc.t("share_copied"))))
		daily.add_child(UI.button(Loc.t("daily_replay"), func(): App.main.goto("game", {"kind": "daily", "id": id, "date": today}), "SecondaryButton"))
	elif id == "":
		daily.add_child(UI.label(Loc.t("daily_unavailable")))
	else:
		daily.add_child(UI.button(Loc.t("daily_play"), func(): App.main.goto("game", {"kind": "daily", "id": id, "date": today}), "", 104))
	v.add_child(UI.card(daily))
	# --- rush
	var rush := UI.vbox(12)
	rush.add_child(UI.label(Loc.t("rush"), "TitleLabel"))
	rush.add_child(UI.label(Loc.t("rush_body", [RushRun.LENGTH]), "SoftLabel"))
	var best := int(App.data.stats.rush_best_ms)
	rush.add_child(UI.label(Loc.t("rush_best", [RushRun.fmt_time(best)]) if best > 0 else Loc.t("rush_no_best"), ""))
	rush.add_child(UI.button(Loc.t("rush_start"), _start_rush, "WarmButton", 104))
	v.add_child(UI.card(rush))
	v.add_child(UI.label(Loc.t("daily_clock_note"), "SoftLabel"))

func _start_rush() -> void:
	App.rush = RushRun.create(App.progression.daily_pool, int(Time.get_unix_time_from_system()))
	App.analytics.event("rush_start", {})
	App.goto_rush_level()

func _cards(v: VBoxContainer) -> void:
	var box := UI.vbox(12)
	box.add_child(UI.label(Loc.t("challenge_cards"), "TitleLabel"))
	if not Challenges.is_open(App.data):
		box.add_child(UI.label(Loc.t("challenge_locked", [App.progression.campaign_index(Challenges.UNLOCK_LEVEL) + 1]), "SoftLabel"))
		v.add_child(UI.card(box))
		return
	box.add_child(UI.label(Loc.t("challenge_intro", [Challenges.done_count(App.data), Challenges.LIST.size()]), "SoftLabel"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for c in Challenges.LIST:
		var done := Challenges.is_done(App.data, c.id)
		var lvl := App.progression.def_for(str(c.level))
		var txt := "%s\n%s\n%s" % [Loc.t("challenge_n", [int(str(c.id).substr(2))]),
			Challenges.goal_text(c, lvl),
			Loc.t("claimed") if done else Loc.t("reward_tokens", [c.reward])]
		var b := UI.button(txt, func(): App.main.goto("game", {"kind": "challenge", "id": c.level, "challenge": c.id}),
			"SecondaryButton" if done else "", 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", Style.fs(22))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if done:
			var g := Glyph.new()
			g.kind = "check"
			g.color = Style.TEAL
			g.anchor_left = 1.0
			g.anchor_right = 1.0
			g.offset_left = -46
			g.offset_right = -6
			g.offset_top = 6
			g.offset_bottom = 46
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(g)
		grid.add_child(b)
	box.add_child(grid)
	v.add_child(UI.card(box))
