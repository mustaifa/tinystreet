extends Control
## Challenges: the Midnight Ledger (v4), challenge cards (v3), the Daily
## puzzle and the optional Café Rush, each as its own illustrated card with a
## clear objective, reward and completion status. The Daily shows "days
## played" (never resets) instead of a streak, so missing a day is never
## punished.
## Daily basis: the device's local calendar date (resets at local midnight).
## Same app version + date => same puzzle. Rewards are a record, a streak and
## progress toward tasks/achievements; device clocks can be changed, so none
## of this is presented as a secure or competitive event.

const GOAL_ICON := {"win": "flag", "three": "star", "no_hint": "hint", "no_undo": "undo", "tidy": "counter"}

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("challenges"), func(): App.main.back(), UI.pill("coin", str(App.data.tokens))))
	var v := UI.vbox(18)
	root.add_child(UI.scroll(v))
	v.add_child(_daily())
	v.add_child(_ledger())
	_cards(v)
	v.add_child(_rush())
	v.add_child(UI.label(Loc.t("daily_clock_note"), "SoftLabel"))

# --------------------------------------------------------------------- daily

func _daily() -> Control:
	var today := Progression.today_key()
	var id := App.progression.daily_level_id(today)
	var done := Progression.is_daily_done(App.data, today)
	var col := UI.vbox(12)
	var head := UI.hbox(16)
	var cal := _CalendarArt.new()
	cal.day = today.substr(8, 2).lstrip("0")
	cal.custom_minimum_size = Vector2(92, 92)
	cal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cal)
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label(Loc.t("daily"), "TitleLabel", UI.al(), false))
	hv.add_child(UI.label(Loc.t("daily_date", [today]), "StrongLabel", UI.al(), false))
	hv.add_child(UI.label(Loc.t("daily_days", [App.data.daily.completed.size()]), "CaptionLabel", UI.al(), false))
	head.add_child(hv)
	if done:
		head.add_child(UI.tag(Loc.t("done_tag"), Style.TEAL, Color.WHITE))
	col.add_child(head)
	col.add_child(UI.label(Loc.t("daily_basis"), "SoftLabel", UI.al()))
	if done:
		var rec: Dictionary = App.data.daily.completed[today]
		var r := UI.hbox(12)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_child(UI.star_row(int(rec.stars), 44))
		r.add_child(UI.label(Loc.t("daily_moves", [int(rec.moves)]), "StrongLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		col.add_child(r)
		var br := UI.hbox(12)
		var sh := UI.icon_text_button("share", Loc.t("share_result"), func():
			App.share_text(Progression.share_text(today, int(rec.stars), int(rec.moves)))
			App.main.toast(Loc.t("share_copied")), "")
		sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(sh)
		var rp := UI.icon_text_button("restart", Loc.t("daily_replay"), func(): App.main.goto("game", {"kind": "daily", "id": id, "date": today}), "SecondaryButton")
		rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(rp)
		col.add_child(br)
	elif id == "":
		col.add_child(UI.label(Loc.t("daily_unavailable")))
	else:
		col.add_child(UI.icon_text_button("play", Loc.t("daily_play"), func(): App.main.goto("game", {"kind": "daily", "id": id, "date": today}), "", 100))
	return UI.card(col)

# --------------------------------------------------------------------- ledger

func _ledger() -> Control:
	var col := UI.vbox(12)
	var head := UI.hbox(16)
	head.add_child(UI.medallion("moon", Style.NIGHT, Style.LANTERN, 84))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label(Loc.t("ledger_title"), "NightHeader", UI.al()))
	if Ledger.is_open(App.data):
		hv.add_child(UI.label(Loc.t("ledger_progress", [Ledger.done_count(App.data), Ledger.pages().size()]), "NightCaption", UI.al(), false))
	head.add_child(hv)
	col.add_child(head)
	col.add_child(UI.label(Loc.t("ledger_card"), "NightSoft", UI.al()))
	if Ledger.is_open(App.data):
		col.add_child(UI.icon_text_button("book", Loc.t("ledger_enter"), func(): App.main.goto("ledger"), "LanternButton", 92))
	else:
		col.add_child(UI.row(UI.medallion("lock", Style.NIGHT_3, Style.MOON_SOFT, 48),
			Loc.t("ledger_locked", [App.progression.campaign_index(Ledger.UNLOCK_LEVEL) + 1]), "", null, "NightLabel"))
	return UI.card(col, "NightCard")

# --------------------------------------------------------------------- rush

func _rush() -> Control:
	var col := UI.vbox(12)
	var best := int(App.data.stats.rush_best_ms)
	var lead := UI.medallion("bolt", Style.TERRA_SOFT, Style.TERRACOTTA, 84)
	col.add_child(UI.row(lead, Loc.t("rush"), Loc.t("rush_best", [RushRun.fmt_time(best)]) if best > 0 else Loc.t("rush_no_best"), null, "TitleLabel"))
	col.add_child(UI.label(Loc.t("rush_body", [RushRun.LENGTH]), "SoftLabel", UI.al()))
	col.add_child(UI.icon_text_button("bolt", Loc.t("rush_start"), _start_rush, "WarmButton", 92))
	return UI.card(col)

func _start_rush() -> void:
	App.rush = RushRun.create(App.progression.daily_pool, int(Time.get_unix_time_from_system()))
	App.analytics.event("rush_start", {})
	App.goto_rush_level()

# --------------------------------------------------------------------- cards

func _cards(v: VBoxContainer) -> void:
	var box := UI.vbox(14)
	var head := UI.hbox(12)
	head.add_child(UI.medallion("trophy", Style.GOLD_SOFT, Style.GOLD_EDGE, 72))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label(Loc.t("challenge_cards"), "TitleLabel", UI.al()))
	head.add_child(hv)
	box.add_child(head)
	if not Challenges.is_open(App.data):
		box.add_child(UI.label(Loc.t("challenge_locked", [App.progression.campaign_index(Challenges.UNLOCK_LEVEL) + 1]), "SoftLabel", UI.al()))
		v.add_child(UI.card(box))
		return
	var n := Challenges.done_count(App.data)
	hv.add_child(UI.label(Loc.t("challenge_done_n", [n, Challenges.LIST.size()]), "CaptionLabel", UI.al(), false))
	box.add_child(UI.progress(n, Challenges.LIST.size(), Style.GOLD, 12))
	box.add_child(UI.label(Loc.t("challenge_intro_short"), "SoftLabel", UI.al()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for c in Challenges.LIST:
		grid.add_child(_card(c))
	box.add_child(grid)
	v.add_child(UI.card(box))

func _card(c: Dictionary) -> Control:
	var done := Challenges.is_done(App.data, c.id)
	var lvl := App.progression.def_for(str(c.level))
	var b := Button.new()
	b.theme_type_variation = "TileButton"
	b.custom_minimum_size = Vector2(0, 168)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI._wire(b, func(): App.main.goto("game", {"kind": "challenge", "id": c.level, "challenge": c.id}))
	var v := UI.vbox(6)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -Style.EDGE - 10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UI.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := UI.label(Loc.t("challenge_n", [int(str(c.id).substr(2))]), "CaptionLabel", UI.al(), false)
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(num)
	if done:
		top.add_child(UI.tag(Loc.t("done_tag"), Style.TEAL, Color.WHITE))
	else:
		top.add_child(UI.tag("+%d" % int(c.reward), Style.GOLD_SOFT, Style.INK))
	v.add_child(top)
	var gr := UI.hbox(10)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m := UI.medallion(str(GOAL_ICON.get(str(c.goal), "flag")), Style.TEAL_SOFT if done else Style.GOLD_SOFT,
		Style.TEAL_DARK if done else Style.GOLD_EDGE, 56)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gr.add_child(m)
	var gl := UI.label(Challenges.goal_text(c, lvl), "StrongLabel", UI.al())
	gl.add_theme_font_size_override("font_size", Style.fs(24))
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gr.add_child(gl)
	v.add_child(gr)
	b.add_child(v)
	return b

## A tear-off calendar page with today's day number.
class _CalendarArt extends Control:
	var day := "1"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(4, 8), size - Vector2(8, 12))
		draw_style_box(Style.box(Style.PAPER, 16, Style.PAPER_EDGE, 2, true), r)
		var top := StyleBoxFlat.new()
		top.bg_color = Style.TERRACOTTA
		top.corner_radius_top_left = 16
		top.corner_radius_top_right = 16
		draw_style_box(top, Rect2(r.position, Vector2(r.size.x, 24)))
		for x in [r.position.x + 22, r.end.x - 22]:
			draw_line(Vector2(x, 2), Vector2(x, 18), Style.INK_SOFT, 5, true)
		draw_string(Style.font_black, Vector2(r.position.x, r.end.y - 14), day, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, Style.INK)
