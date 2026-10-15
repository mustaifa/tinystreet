extends Control
## Café home: the restored café, progress, and the main actions.

var cafe: CafeView

func setup(params: Dictionary) -> void:
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := UI.hbox(12)
	var tok := UI.label(Loc.t("tokens_n", [App.data.tokens]), "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	tok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tok)
	if App.billing.is_available():
		top.add_child(UI.icon_button("plus", "", func(): App.main.goto("shop"), "SecondaryButton", 88))
	top.add_child(UI.icon_button("help", "", func(): App.main.goto("help"), "SecondaryButton", 88))
	top.add_child(UI.icon_button("gear", "", func(): App.main.goto("settings"), "SecondaryButton", 88))
	root.add_child(top)
	root.add_child(UI.label(Loc.t("game_title"), "TitleLabel"))
	cafe = CafeView.new()
	cafe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cafe.custom_minimum_size = Vector2(0, 420)
	cafe.configure(int(App.data.restoration.milestones), _choices())
	root.add_child(cafe)
	root.add_child(UI.label(_progress_text(), "SoftLabel"))
	var nxt := App.progression.next_level_index(App.data)
	var all_done := App.progression.cleared_count(App.data) >= App.progression.campaign.size()
	var cur: Dictionary = App.data.current
	var play_id: String = App.progression.campaign[nxt].id
	var play_text := Loc.t("play_level", [nxt + 1])
	if cur.get("kind", "") == "campaign" and cur.has("id"):
		play_id = cur.id
		play_text = Loc.t("continue_level", [App.progression.campaign_index(cur.id) + 1])
	elif all_done:
		play_text = Loc.t("play_level", [nxt + 1])
	var play := UI.button(play_text, func(): App.main.goto("game", {"kind": "campaign", "id": play_id}), "", 112)
	play.add_theme_font_size_override("font_size", Style.fs(38))
	root.add_child(play)
	var row := UI.hbox(14)
	var lv := UI.button(Loc.t("levels"), func(): App.main.goto("levels"), "SecondaryButton")
	var rs := UI.button(Loc.t("restore") + (" •" if Restoration.can_unlock(App.data) else ""), func(): App.main.goto("restore"),
		"WarmButton" if Restoration.can_unlock(App.data) else "SecondaryButton")
	var dy := UI.button(Loc.t("daily") + ("" if Progression.is_daily_done(App.data, Progression.today_key()) else " •"), func(): App.main.goto("daily"), "SecondaryButton")
	for b in [lv, rs, dy]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	root.add_child(row)
	if params.get("finale", false) or (all_done and int(App.data.restoration.milestones) >= 5 and not App.data.tutorial.done.has("finale_seen")):
		_finale.call_deferred()

func _choices() -> Dictionary:
	var c := {}
	for k in Restoration.DEFAULTS:
		c[k] = Restoration.effective_choice(App.data, k)
	return c

func _progress_text() -> String:
	var i := Restoration.next_index(App.data)
	if i < 0:
		return Loc.t("cafe_complete")
	var m: Dictionary = Restoration.MILESTONES[i]
	return Loc.t("next_restore", [Loc.t("ms_" + m.id), App.data.tokens, m.cost])

func _finale() -> void:
	if int(App.data.restoration.milestones) < 5:
		if Restoration.can_unlock(App.data):
			App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_restore_body"),
				[[Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"]]))
		return
	App.data.tutorial.done["finale_seen"] = true
	App.save_soon()
	App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_body"), [[Loc.t("close"), func(): pass, ""]]))
