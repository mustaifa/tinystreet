extends Control
## Daily challenge. Basis: the device's local calendar date (resets at local
## midnight). Same app version + date => same puzzle. Rewards are a cosmetic
## record + streak only (no tokens), since device clocks can be changed.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(18)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("daily"), func(): App.main.back()))
	var today := Progression.today_key()
	var id := App.progression.daily_level_id(today)
	root.add_child(UI.label(Loc.t("daily_date", [today]), "HeaderLabel"))
	root.add_child(UI.label(Loc.t("daily_basis"), "SoftLabel"))
	var done := Progression.is_daily_done(App.data, today)
	var streak := Progression.daily_streak(App.data, today)
	root.add_child(UI.label(Loc.t("daily_streak", [streak]), ""))
	if done:
		var rec: Dictionary = App.data.daily.completed[today]
		root.add_child(UI.label(Loc.t("daily_done", [UI.stars_text(int(rec.stars)), int(rec.moves)]), "HeaderLabel"))
		root.add_child(UI.button(Loc.t("share_result"), func():
			App.share_text(Progression.share_text(today, int(rec.stars), int(rec.moves)))
			App.main.toast(Loc.t("share_copied"))))
		root.add_child(UI.button(Loc.t("daily_replay"), func(): App.main.goto("game", {"kind": "daily", "id": id, "date": today}), "SecondaryButton"))
	elif id == "":
		root.add_child(UI.label(Loc.t("daily_unavailable")))
	else:
		root.add_child(UI.button(Loc.t("daily_play"), func(): App.main.goto("game", {"kind": "daily", "id": id, "date": today}), "", 112))
	root.add_child(UI.spacer(0, true))
	root.add_child(UI.label(Loc.t("daily_clock_note"), "SoftLabel"))
