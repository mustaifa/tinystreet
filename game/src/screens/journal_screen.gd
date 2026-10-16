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
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("journal"), func(): App.main.back(), UI.pill("coin", str(App.data.tokens))))
	var opts: Array = []
	for t in TABS:
		var n := 0
		if t == "tasks":
			n = Tasks.ready_count(App.data)
		elif t == "achievements":
			n = Achievements.claimable_count(App.data)
		opts.append([t, Loc.t("tab_" + t) + (" · %d" % n if n > 0 else "")])
	root.add_child(UI.segmented(opts, tab, func(t: String):
		tab = t
		_build()))
	body = UI.vbox(14)
	root.add_child(UI.scroll(body))
	match tab:
		"tasks": _tasks()
		"achievements": _achievements()
		_: _progress()

func _al() -> int:
	return UI.al()

# --------------------------------------------------------------------- tasks

func _tasks() -> void:
	body.add_child(UI.label(Loc.t("tasks_intro"), "SoftLabel", _al()))
	for id in App.data.tasks.list:
		var t := Tasks.def(id)
		var done := Tasks.is_done(App.data, id)
		var claimed := Tasks.is_claimed(App.data, id)
		var card := UI.vbox(10)
		var lead := UI.medallion("check" if claimed else "cup", Style.TEAL_SOFT if done else Style.GOLD_SOFT,
			Style.TEAL_DARK if done else Style.GOLD_EDGE, 60)
		card.add_child(UI.row(lead, Loc.t("task_" + str(id), [t.goal]), "", null, "StrongLabel"))
		var prog := Tasks.progress(App.data, id)
		card.add_child(UI.progress_row(mini(prog, int(t.goal)), int(t.goal), Style.TEAL if done else Style.GOLD))
		var row := UI.hbox(12)
		var rp := UI.pill("coin", "+%d" % int(t.reward))
		row.add_child(rp)
		row.add_child(UI.spacer(0, true))
		if claimed:
			row.add_child(UI.tag(Loc.t("claimed"), Style.TEAL_SOFT, Style.TEAL_DARK))
		else:
			var b := UI.button(Loc.t("claim"), func(): _claim_task(id), "GoldButton")
			b.disabled = not done
			b.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
			row.add_child(b)
		card.add_child(row)
		body.add_child(UI.card(card, "CardPanel" if not claimed else "SoftPanel"))
	body.add_child(UI.label(Loc.t("tasks_clock_note"), "SoftLabel", _al()))

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
	body.add_child(UI.label(Loc.t("ach_count", [n, Achievements.LIST.size()]), "CaptionLabel", _al()))
	body.add_child(UI.progress(n, Achievements.LIST.size(), Style.GOLD, 12))
	for a in Achievements.LIST:
		var unlocked := Achievements.is_unlocked(App.data, a.id)
		var claimed := unlocked and Achievements.is_claimed(App.data, a.id)
		var lead := UI.medallion("trophy" if unlocked else "lock", Style.GOLD_SOFT if unlocked else Style.CREAM_DEEP,
			Style.GOLD_EDGE if unlocked else Style.INK_SOFT, 64)
		var v := UI.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(Loc.t("ach_" + str(a.id)), "StrongLabel", _al()))
		v.add_child(UI.label(Loc.t("achd_" + str(a.id), [a.goal]), "SoftLabel", _al()))
		var val := mini(Achievements.value(App.data, a.stat), int(a.goal))
		if not unlocked:
			v.add_child(UI.progress_row(val, int(a.goal), Style.GOLD))
		var reward := Loc.t("reward_tokens", [a.reward])
		if a.has("unlocks"):
			reward += " · " + Loc.t("unlock_" + str(a.unlocks))
		v.add_child(UI.label(reward, "CaptionLabel", _al()))
		var row := UI.hbox(14)
		row.add_child(lead)
		row.add_child(v)
		if unlocked and not claimed:
			var b := UI.button(Loc.t("claim"), func():
				var got := Achievements.claim(App.data, a.id)
				if got > 0:
					App.save_now()
					App.audio.play("coin")
					App.main.toast(Loc.t("got_tokens", [got]))
				_build(), "GoldButton")
			b.custom_minimum_size = Vector2(140, Style.MIN_TOUCH)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		elif claimed:
			var c := UI.medallion("check", Style.TEAL, Color.WHITE, 44)
			row.add_child(c)
		body.add_child(UI.card(row, "CardPanel" if unlocked else "SoftPanel"))

# --------------------------------------------------------------------- progress

func _progress() -> void:
	var prog := App.progression
	var card := UI.vbox(12)
	card.add_child(UI.section(Loc.t("campaign_progress", [prog.cleared_count(App.data), prog.campaign.size()]), "levels"))
	for ci in prog.chapters.size():
		var r := prog.chapter_range(ci)
		var cleared := 0
		var stars := 0
		for i in range(r.x, r.y):
			var id: String = prog.campaign[i].id
			if Progression.is_cleared(App.data, id):
				cleared += 1
			stars += int(App.data.campaign.stars.get(id, 0))
		var head := UI.hbox(8)
		var tl := UI.label(Loc.t(str(prog.chapters[ci].title)), "StrongLabel", _al(), false)
		tl.add_theme_font_size_override("font_size", Style.fs(25))
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(tl)
		head.add_child(UI.label("★ %d/%d" % [stars, (r.y - r.x) * 3], "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false))
		card.add_child(head)
		card.add_child(UI.progress_row(cleared, r.y - r.x))
	body.add_child(UI.card(card))
	var cafe := UI.vbox(12)
	cafe.add_child(UI.section(Loc.t("cafe_progress", [Restoration.steps(App.data), Restoration.STEPS.size()]), "brush"))
	cafe.add_child(UI.progress_row(Restoration.steps(App.data), Restoration.STEPS.size(), Style.TERRACOTTA))
	var owned := 0
	for e in Restoration.EXTRAS:
		if Restoration.owns_extra(App.data, e.id):
			owned += 1
	var facts: Array = [
		["heart", Loc.t("extras_progress", [owned, Restoration.EXTRAS.size()])],
		["trophy", Loc.t("ach_count", [Achievements.unlocked_ids(App.data).size(), Achievements.LIST.size()])],
		["calendar", Loc.t("daily_days", [App.data.daily.completed.size()])],
		["flag", Loc.t("challenge_intro", [Challenges.done_count(App.data), Challenges.LIST.size()])],
		["stamp", Loc.t("ledger_progress", [Ledger.done_count(App.data), Ledger.pages().size()])],
	]
	var best := int(App.data.stats.rush_best_ms)
	if best > 0:
		facts.append(["bolt", Loc.t("rush_best", [RushRun.fmt_time(best)])])
	for f in facts:
		cafe.add_child(UI.row(UI.medallion(f[0], Style.LINEN, Style.TEAL_DARK, 44), f[1], "", null, "SoftLabel"))
	body.add_child(UI.card(cafe))
	if Restoration.is_complete(App.data):
		body.add_child(UI.card(UI.label(Loc.t("street_teaser"), "SoftLabel"), "SoftPanel"))
	# story replays (only beats already seen)
	body.add_child(UI.section(Loc.t("story_replay"), "book"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var any := false
	for id in Story.JOURNAL:
		if Story.seen(App.data, id):
			any = true
			var b := UI.button(Loc.t("beat_" + id.replace(":", "_")), func(): Story.play(id, Callable(), true), "SecondaryButton", 72)
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
			b.add_theme_font_size_override("font_size", Style.fs(24))
			flow.add_child(b)
	if any:
		body.add_child(flow)
	else:
		body.add_child(UI.label(Loc.t("story_none"), "SoftLabel", _al()))

func _bar(v: int, goal: int) -> Control:
	return UI.progress_row(v, goal)
