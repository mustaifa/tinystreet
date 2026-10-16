extends Control
## Challenges: the Daily puzzle and the optional Café Rush.
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
	# --- daily
	var today := Progression.today_key()
	var id := App.progression.daily_level_id(today)
	var daily := UI.vbox(12)
	daily.add_child(UI.label(Loc.t("daily"), "TitleLabel"))
	daily.add_child(UI.label(Loc.t("daily_date", [today]), "HeaderLabel"))
	daily.add_child(UI.label(Loc.t("daily_basis"), "SoftLabel"))
	var done := Progression.is_daily_done(App.data, today)
	daily.add_child(UI.label(Loc.t("daily_streak", [Progression.daily_streak(App.data, today)]), ""))
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
