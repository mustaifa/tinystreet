extends Control
## Café home. The café, framed as a little shop front on the street, is the
## centrepiece. One clear primary action (Play / Continue the next Delivery
## Logic puzzle) sits in the thumb zone; the next restoration goal is a single
## tappable card; the three main destinations are illustrated tiles.
## v8: the sorting campaign, bakery, ledger and daily challenges are retired
## from the primary flow (their code and the player's records are kept).
## Badges and dots point to anything ready to claim, never to payment.

var cafe: CafeView
var play_btn: Button
var default_focus: Control   # keyboard / pad players start on Play

func setup(params: Dictionary) -> void:
	Tasks.refresh(App.data, Progression.today_key(), Meta.seen_mechanics(App.data, App.progression))
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_top_bar())
	# --- the café, centre stage
	cafe = CafeView.new()
	cafe.configure_state(Restoration.view_state(App.data))
	var front := Storefront.new(cafe)
	front.size_flags_vertical = Control.SIZE_EXPAND_FILL
	front.custom_minimum_size = Vector2(0, 380)
	root.add_child(front)
	root.add_child(_goal_card())
	root.add_child(_play_button())
	root.add_child(_tiles())
	if params.get("dl_finale", false):
		_dl_finale.call_deferred()

func _all_done() -> bool:
	return App.delivery.all_cleared(App.data)

func _dl_finale() -> void:
	App.main.show_overlay(Dialog.make(Loc.t("dl_finale_title"), Loc.t("dl_finale_body"), [[Loc.t("close"), func(): pass, ""]], null, "star"))

func _top_bar() -> Control:
	var top := UI.hbox(12)
	var coins := UI.pill("coin", str(App.data.tokens))
	coins.tooltip_text = Loc.t("tokens_n", [App.data.tokens])
	top.add_child(coins)
	top.add_child(UI.spacer(0, true))
	# The journal's tasks and awards belong to the retired sorting game: the
	# chip stays only while something there is still ready to claim.
	var ready := Tasks.ready_count(App.data) + Achievements.claimable_count(App.data)
	if ready > 0:
		top.add_child(UI.chip("journal", func(): App.main.goto("journal"), "ChipButton", Style.CHIP, ready, Loc.t("journal")))
	if App.billing.is_available():
		top.add_child(UI.chip("plus", func(): App.main.goto("shop"), "ChipButton", Style.CHIP, 0, Loc.t("shop")))
	# Help lives in Settings and on every puzzle screen (v6: a calmer top bar).
	top.add_child(UI.chip("gear", func(): App.main.goto("settings"), "ChipButton", Style.CHIP, 0, Loc.t("settings")))
	return top

## The next restoration step as one card: tap it to go and restore.
func _goal_card() -> Control:
	var i := Restoration.next_index(App.data)
	var have := int(App.data.tokens)
	var b := Button.new()
	b.theme_type_variation = "TileButton"
	b.custom_minimum_size = Vector2(0, 104)
	UI._wire(b, func(): App.main.goto("restore"))
	var r := UI.hbox(16)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 18
	r.offset_right = -18
	r.offset_bottom = -Style.EDGE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	var ready := i >= 0 and have >= int(Restoration.STEPS[i].cost)
	var med := UI.medallion("brush" if i >= 0 else "spark", Style.TERRA_SOFT if ready else Style.GOLD_SOFT, Style.TERRACOTTA if ready else Style.GOLD_EDGE, 68)
	r.add_child(med)
	var col := UI.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(col)
	if i < 0:
		col.add_child(UI.label(Loc.t("cafe_complete_extras"), "StrongLabel", UI.al()))
	else:
		var st: Dictionary = Restoration.STEPS[i]
		var t := UI.label(Loc.t("next_step", [Loc.t("step_" + str(st.id))]), "StrongLabel", UI.al(), false)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.add_theme_font_size_override("font_size", Style.fs(27))
		col.add_child(t)
		var pr := UI.hbox(10)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_child(UI.progress(mini(have, int(st.cost)), int(st.cost), Style.TERRACOTTA if ready else Style.GOLD, 16))
		var cap := UI.label("%d / %d" % [mini(have, int(st.cost)), int(st.cost)], "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
		pr.add_child(cap)
		col.add_child(pr)
	if ready:
		r.add_child(UI.tag(Loc.t("ready"), Style.TERRACOTTA, Color.WHITE))
	var chev := Glyph.new()
	chev.kind = "chevron"
	chev.color = Style.INK_SOFT
	chev.custom_minimum_size = Vector2(32, 32)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(chev)
	for c in r.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _doors() -> Control:
	var cards: Array = []
	if Bakery.is_unlocked(App.data):
		var prog := App.progression
		var sub := Loc.t("ready") if Bakery.can_unlock(App.data) else Loc.t("door_progress", [prog.bakery_cleared_count(App.data), prog.bakery.size()])
		cards.append(_door("p_croissant", Loc.t("bakery_title"), sub, func(): App.main.goto("bakery"), false,
			Bakery.can_unlock(App.data) or not Story.seen(App.data, "bakery_open")))
	if Ledger.is_open(App.data):
		var sub2 := Loc.t("door_progress", [Ledger.done_count(App.data), Ledger.pages().size()])
		cards.append(_door("moon", Loc.t("ledger_title"), sub2, func(): App.main.goto("ledger"), true,
			not bool(App.data.ledger.offer_seen)))
	if cards.is_empty():
		return null
	var row := UI.hbox(12)
	for c in cards:
		row.add_child(c)
	return row

## A compact "next door" card. Night cards use the ledger palette.
func _door(glyph: String, title: String, sub: String, cb: Callable, night: bool, flag: bool) -> Control:
	var b := Button.new()
	b.theme_type_variation = "NightButton" if night else "TileButton"
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI._wire(b, cb)
	var r := UI.hbox(12)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 14
	r.offset_right = -12
	r.offset_bottom = -Style.EDGE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	r.add_child(UI.medallion(glyph, Style.NIGHT if night else Style.ROSE_SOFT, Style.LANTERN if night else Style.TERRACOTTA, 60))
	var col := UI.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UI.label(title, "StrongLabel", UI.al(), false)
	t.add_theme_color_override("font_color", Style.MOON if night else Style.INK)
	UI.fit_font(t, 200 if (Bakery.is_unlocked(App.data) and Ledger.is_open(App.data)) else 480, 25, 19)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	col.add_child(t)
	var s := UI.label(sub, "CaptionLabel", UI.al(), false)
	s.add_theme_color_override("font_color", Style.LANTERN if night else Style.INK_SOFT)
	col.add_child(s)
	r.add_child(col)
	for c in r.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in col.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if flag:
		UI.badge(b, -1)
	return b

## The primary action: continue the puzzle in progress, or play the next one.
func _play_button() -> Control:
	var dp := App.delivery
	var nxt := dp.next_index(App.data)
	var cur := DeliveryProgress.current_id(App.data)
	var play_id := dp.id_at(nxt)
	var verb := Loc.t("home_play")
	if cur != "" and dp.index_of(cur) >= 0:
		play_id = cur
		verb = Loc.t("home_continue")
	var i := dp.index_of(play_id)
	var ci := dp.chapter_index(i)
	# The puzzle number is the headline; the verb and chapter are the line under it.
	var sub := verb + ((" · " + Loc.t(str(dp.chapters[ci].title))) if ci >= 0 else "")
	if _all_done() and verb == Loc.t("home_play"):
		sub = Loc.t("dl_all_solved", [i + 1])
	play_btn = UI.icon_text_button("play", Loc.t("dl_puzzle_n", [i + 1]), func(): App.main.goto("puzzle", {"id": play_id}), "", 132, sub, 56)
	play_btn.name = "PlayButton"
	default_focus = play_btn
	_breathe(play_btn)
	return play_btn

## A slow, limited "breathing" emphasis on the next useful action. Stops on
## its own; reduced motion turns it off.
func _breathe(b: Control) -> void:
	if App.reduced_motion():
		return
	var tw := b.create_tween().set_loops(3)
	tw.tween_interval(1.2)
	tw.tween_callback(func(): b.pivot_offset = b.size / 2)
	tw.tween_property(b, "scale", Vector2(1.025, 1.025), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)

func _tiles() -> Control:
	var row := UI.hbox(12)
	var can_restore := Restoration.can_unlock(App.data)
	row.add_child(_tile("levels", Loc.t("dl_puzzles"), func(): App.main.goto("puzzles"), false))
	row.add_child(_tile("brush", Loc.t("restore"), func(): App.main.goto("restore"), can_restore))
	row.add_child(_tile("help", Loc.t("help"), func(): App.main.goto("help"), false))
	return row

func _tile(glyph: String, text: String, cb: Callable, dot: bool) -> Control:
	var b := Button.new()
	b.theme_type_variation = "TileButton"
	b.custom_minimum_size = Vector2(0, 116)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI._wire(b, cb)
	var v := UI.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 8
	v.offset_bottom = -Style.EDGE - 4
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Glyph.new()
	g.kind = glyph
	g.color = Style.TEAL_DARK
	g.custom_minimum_size = Vector2(68, 64)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(g)
	var l := UI.label(text, "StrongLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	l.add_theme_font_size_override("font_size", Style.fs(25))
	l.add_theme_color_override("font_color", Style.TEAL_DARK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	b.add_child(v)
	if dot:
		UI.badge(b, -1)
	return b

func _finale() -> void:
	if not Restoration.is_complete(App.data):
		if Restoration.can_unlock(App.data):
			App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_restore_body"),
				[[Loc.t("restore_now"), func(): App.main.goto("restore"), "WarmButton"]], null, "brush"))
		return
	App.data.tutorial.done["finale_seen"] = true
	App.save_soon()
	App.main.show_overlay(Dialog.make(Loc.t("finale_title"), Loc.t("finale_campaign_body"), [[Loc.t("close"), func(): pass, ""]], null, "star"))
