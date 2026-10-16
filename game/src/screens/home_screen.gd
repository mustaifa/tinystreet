extends Control
## Café home: the café as it stands, the next restoration goal, and the main
## actions. Badges point to anything ready to claim or buy.

var cafe: CafeView

func setup(params: Dictionary) -> void:
	Tasks.refresh(App.data, Progression.today_key(), Meta.seen_mechanics(App.data, App.progression))
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := UI.hbox(10)
	var pill := UI.hbox(6)
	var coin := Glyph.new()
	coin.kind = "coin"
	coin.color = Style.GOLD
	coin.custom_minimum_size = Vector2(56, 56)
	pill.add_child(coin)
	pill.add_child(UI.label(str(App.data.tokens), "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT, false))
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pill)
	var journal := UI.icon_button("book", "", func(): App.main.goto("journal"), "SecondaryButton", 88)
	var ready := Tasks.ready_count(App.data) + Achievements.claimable_count(App.data)
	if ready > 0:
		_badge(journal, ready)
	top.add_child(journal)
	if App.billing.is_available():
		top.add_child(UI.icon_button("plus", "", func(): App.main.goto("shop"), "SecondaryButton", 88))
	top.add_child(UI.icon_button("help", "", func(): App.main.goto("help"), "SecondaryButton", 88))
	top.add_child(UI.icon_button("gear", "", func(): App.main.goto("settings"), "SecondaryButton", 88))
	root.add_child(top)
	cafe = CafeView.new()
	cafe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cafe.custom_minimum_size = Vector2(0, 460)
	cafe.configure_state(Restoration.view_state(App.data))
	root.add_child(cafe)
	var goal := GoalBar.make(App.data)
	goal.custom_minimum_size = Vector2(0, 92)
	root.add_child(goal)
	var nxt := App.progression.next_level_index(App.data)
	var all_done := App.progression.cleared_count(App.data) >= App.progression.campaign.size()
	var cur: Dictionary = App.data.current
	var play_id: String = App.progression.campaign[nxt].id
	var play_text := Loc.t("play_level", [nxt + 1])
	if cur.get("kind", "") == "campaign" and cur.has("id") and App.progression.campaign_index(cur.id) >= 0:
		play_id = cur.id
		play_text = Loc.t("continue_level", [App.progression.campaign_index(cur.id) + 1])
	var play := UI.button(play_text, func(): App.main.goto("game", {"kind": "campaign", "id": play_id}), "", 112)
	play.add_theme_font_size_override("font_size", Style.fs(38))
	root.add_child(play)
	var ch := App.progression.chapter_of(App.progression.campaign_index(play_id))
	if ch != "" and not all_done:
		var cl := UI.label(Loc.t(ch), "SoftLabel")
		root.add_child(cl)
	var row := UI.hbox(14)
	var can_restore := Restoration.can_unlock(App.data)
	var lv := UI.button(Loc.t("levels"), func(): App.main.goto("levels"), "SecondaryButton")
	var rs := UI.button(Loc.t("restore") + (" •" if can_restore else ""), func(): App.main.goto("restore"),
		"WarmButton" if can_restore else "SecondaryButton")
	var dy := UI.button(Loc.t("challenges") + ("" if Progression.is_daily_done(App.data, Progression.today_key()) else " •"), func(): App.main.goto("daily"), "SecondaryButton")
	for b in [lv, rs, dy]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	root.add_child(row)
	if can_restore and not App.reduced_motion():
		var tw := rs.create_tween().set_loops(3)
		rs.pivot_offset = Vector2(110, 44)
		tw.tween_property(rs, "scale", Vector2(1.05, 1.05), 0.35)
		tw.tween_property(rs, "scale", Vector2.ONE, 0.35)
	if params.get("finale", false) or (all_done and Restoration.is_complete(App.data) and not App.data.tutorial.done.has("finale_seen")):
		_finale.call_deferred()

## Small count bubble on an icon button.
func _badge(btn: Control, n: int) -> void:
	var b := Label.new()
	b.text = str(n)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", Style.font_bold)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", Style.box(Style.TERRACOTTA, 18, Color.TRANSPARENT, 0, false))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	b.position = Vector2(56, -8)
	b.size = Vector2(36, 36)
	(btn.get_meta("button") as Control).add_child(b)

func _finale() -> void:
	if not Restoration.is_complete(App.data):
		if Restoration.can_unlock(App.data):
			App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_restore_body"),
				[[Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"]]))
		return
	App.data.tutorial.done["finale_seen"] = true
	App.save_soon()
	App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_campaign_body"), [[Loc.t("close"), func(): pass, ""]]))
