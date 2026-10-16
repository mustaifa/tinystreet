extends Control
## Journal: today's café tasks, the achievement collection, and an overview
## of campaign, café and collection progress (with story replays).

const TABS := ["tasks", "achievements", "progress"]

var tab := "tasks"
var body: VBoxContainer

func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "tasks"))
	Tasks.refresh(App.data, Progression.today_key(), Meta.seen_mechanics(App.data, App.progression))
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("journal"), func(): App.main.back()))
	var tabs := UI.hbox(10)
	for t in TABS:
		var n := 0
		if t == "tasks":
			n = Tasks.ready_count(App.data)
		elif t == "achievements":
			n = Achievements.claimable_count(App.data)
		var b := UI.button(Loc.t("tab_" + t) + (" (%d)" % n if n > 0 else ""), func():
			tab = t
			_build(), "" if t == tab else "SecondaryButton", 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", Style.fs(26))
		tabs.add_child(b)
	root.add_child(tabs)
	var coin_row := UI.hbox(8)
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var coin := Glyph.new()
	coin.kind = "coin"
	coin.color = Style.GOLD
	coin.custom_minimum_size = Vector2(44, 44)
	coin_row.add_child(coin)
	coin_row.add_child(UI.label(Loc.t("tokens_n", [App.data.tokens]), "", HORIZONTAL_ALIGNMENT_CENTER, false))
	root.add_child(coin_row)
	body = UI.vbox(14)
	root.add_child(UI.scroll(body))
	match tab:
		"tasks": _tasks()
		"achievements": _achievements()
		_: _progress()

func _al() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT

# --------------------------------------------------------------------- tasks

func _tasks() -> void:
	body.add_child(UI.label(Loc.t("tasks_intro"), "SoftLabel"))
	for id in App.data.tasks.list:
		var t := Tasks.def(id)
		var card := UI.vbox(8)
		card.add_child(UI.label(Loc.t("task_" + str(id), [t.goal]), "HeaderLabel", _al()))
		var prog := Tasks.progress(App.data, id)
		card.add_child(_bar(prog, int(t.goal)))
		var row := UI.hbox(12)
		var rl := UI.label(Loc.t("reward_tokens", [t.reward]), "SoftLabel", _al(), false)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rl)
		if Tasks.is_claimed(App.data, id):
			row.add_child(UI.label(Loc.t("claimed"), "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		else:
			var b := UI.button(Loc.t("claim"), func(): _claim_task(id), "WarmButton")
			b.disabled = not Tasks.is_done(App.data, id)
			b.custom_minimum_size = Vector2(180, Style.MIN_TOUCH)
			row.add_child(b)
		card.add_child(row)
		body.add_child(UI.card(card))
	body.add_child(UI.label(Loc.t("tasks_clock_note"), "SoftLabel"))

func _claim_task(id: String) -> void:
	var got := Tasks.claim(App.data, id)
	if got > 0:
		App.save_now()
		App.audio.play("coin")
		App.main.toast(Loc.t("got_tokens", [got]))
	_build()

# --------------------------------------------------------------------- achievements

func _achievements() -> void:
	var n := Achievements.unlocked_ids(App.data).size()
	body.add_child(UI.label(Loc.t("ach_count", [n, Achievements.LIST.size()]), "SoftLabel"))
	for a in Achievements.LIST:
		var unlocked := Achievements.is_unlocked(App.data, a.id)
		var row := UI.hbox(14)
		var g := Glyph.new()
		g.kind = "trophy" if unlocked else "lock"
		g.color = Style.GOLD if unlocked else Color(Style.INK_SOFT, 0.5)
		g.custom_minimum_size = Vector2(64, 64)
		row.add_child(g)
		var v := UI.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(Loc.t("ach_" + str(a.id)), "HeaderLabel" if unlocked else "", _al(), false))
		v.add_child(UI.label(Loc.t("achd_" + str(a.id), [a.goal]), "SoftLabel", _al()))
		var val := mini(Achievements.value(App.data, a.stat), int(a.goal))
		if not unlocked:
			v.add_child(_bar(val, int(a.goal)))
		var reward := Loc.t("reward_tokens", [a.reward])
		if a.has("unlocks"):
			reward += " · " + Loc.t("unlock_" + str(a.unlocks))
		v.add_child(UI.label(reward, "SoftLabel", _al()))
		row.add_child(v)
		if unlocked and not Achievements.is_claimed(App.data, a.id):
			var b := UI.button(Loc.t("claim"), func():
				var got := Achievements.claim(App.data, a.id)
				if got > 0:
					App.save_now()
					App.audio.play("coin")
					App.main.toast(Loc.t("got_tokens", [got]))
				_build(), "WarmButton")
			b.custom_minimum_size = Vector2(160, Style.MIN_TOUCH)
			row.add_child(b)
		elif unlocked:
			var c := Glyph.new()
			c.kind = "check"
			c.color = Style.TEAL
			c.custom_minimum_size = Vector2(56, 56)
			row.add_child(c)
		body.add_child(UI.card(row, "CardPanel" if unlocked else "SoftPanel"))

# --------------------------------------------------------------------- progress

func _progress() -> void:
	var prog := App.progression
	var card := UI.vbox(10)
	card.add_child(UI.label(Loc.t("campaign_progress", [prog.cleared_count(App.data), prog.campaign.size()]), "HeaderLabel", _al()))
	for ci in prog.chapters.size():
		var r := prog.chapter_range(ci)
		var cleared := 0
		var stars := 0
		for i in range(r.x, r.y):
			var id: String = prog.campaign[i].id
			if Progression.is_cleared(App.data, id):
				cleared += 1
			stars += int(App.data.campaign.stars.get(id, 0))
		card.add_child(UI.label("%s  ·  %d/%d  ·  ★ %d/%d" % [Loc.t(str(prog.chapters[ci].title)), cleared, r.y - r.x, stars, (r.y - r.x) * 3], "", _al()))
		card.add_child(_bar(cleared, r.y - r.x))
	body.add_child(UI.card(card))
	var cafe := UI.vbox(8)
	cafe.add_child(UI.label(Loc.t("cafe_progress", [Restoration.steps(App.data), Restoration.STEPS.size()]), "HeaderLabel", _al()))
	cafe.add_child(_bar(Restoration.steps(App.data), Restoration.STEPS.size()))
	var owned := 0
	for e in Restoration.EXTRAS:
		if Restoration.owns_extra(App.data, e.id):
			owned += 1
	cafe.add_child(UI.label(Loc.t("extras_progress", [owned, Restoration.EXTRAS.size()]), "", _al()))
	cafe.add_child(UI.label(Loc.t("ach_count", [Achievements.unlocked_ids(App.data).size(), Achievements.LIST.size()]), "", _al()))
	cafe.add_child(UI.label(Loc.t("daily_days", [App.data.daily.completed.size()]), "", _al()))
	cafe.add_child(UI.label(Loc.t("challenge_intro", [Challenges.done_count(App.data), Challenges.LIST.size()]), "", _al()))
	var best := int(App.data.stats.rush_best_ms)
	if best > 0:
		cafe.add_child(UI.label(Loc.t("rush_best", [RushRun.fmt_time(best)]), "", _al()))
	body.add_child(UI.card(cafe))
	if Restoration.is_complete(App.data):
		body.add_child(UI.card(UI.label(Loc.t("street_teaser"), "SoftLabel"), "SoftPanel"))
	# story replays (only beats already seen)
	body.add_child(UI.label(Loc.t("story_replay"), "HeaderLabel", _al()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var any := false
	for id in Story.JOURNAL:
		if Story.seen(App.data, id):
			any = true
			var b := UI.button(Loc.t("beat_" + id.replace(":", "_")), func(): Story.play(id, Callable(), true), "SecondaryButton", 72)
			b.add_theme_font_size_override("font_size", Style.fs(24))
			flow.add_child(b)
	if any:
		body.add_child(flow)
	else:
		body.add_child(UI.label(Loc.t("story_none"), "SoftLabel"))

func _bar(v: int, goal: int) -> Control:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = maxi(1, goal)
	b.value = v
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 22)
	b.add_theme_stylebox_override("background", Style.box(Color(Style.INK_SOFT, 0.15), 11, Color.TRANSPARENT, 0, false))
	b.add_theme_stylebox_override("fill", Style.box(Style.TEAL, 11, Color.TRANSPARENT, 0, false))
	for sb in [b.get_theme_stylebox("background"), b.get_theme_stylebox("fill")]:
		(sb as StyleBoxFlat).content_margin_top = 0
		(sb as StyleBoxFlat).content_margin_bottom = 0
	var wrap := UI.hbox(10)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.add_child(b)
	wrap.add_child(UI.label("%d/%d" % [v, goal], "SoftLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
	return wrap
