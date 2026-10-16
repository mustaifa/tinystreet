extends Control
## The Midnight Ledger: optional expert puzzles (v4). Lists the pages with
## their stamp and badges, explains the mode, and states plainly that the
## difficulty labels are provisional until people have played them.

func setup(_p: Dictionary) -> void:
	if not bool(App.data.ledger.offer_seen):
		App.data.ledger.offer_seen = true
		App.save_soon()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("ledger_title"), func(): App.main.back()))
	var v := UI.vbox(14)
	root.add_child(UI.scroll(v))
	var intro := UI.vbox(8)
	intro.add_child(UI.label(Loc.t("ledger_intro"), ""))
	intro.add_child(UI.label(Loc.t("ledger_notice"), "SoftLabel"))
	intro.add_child(UI.label(Loc.t("ledger_progress", [Ledger.done_count(App.data), Ledger.pages().size()]), "HeaderLabel"))
	v.add_child(UI.card(intro, "SoftPanel"))
	if not Ledger.is_open(App.data):
		v.add_child(UI.label(Loc.t("ledger_locked", [App.progression.campaign_index(Ledger.UNLOCK_LEVEL) + 1]), "HeaderLabel"))
		return
	var last_group := ""
	for p in Ledger.pages():
		var grp := Ledger.group(p)
		if grp != last_group:
			last_group = grp
			v.add_child(UI.label(Loc.t("ledger_group_" + grp), "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(_row(p))

func _row(p: Dictionary) -> Control:
	var id: String = p.id
	var i := Ledger.info(p)
	var open := Ledger.is_unlocked(App.data, id)
	var done := Ledger.is_done(App.data, id)
	var row := UI.hbox(12)
	var g := Glyph.new()
	g.kind = "check" if done else ("book" if open else "lock")
	g.color = Style.TEAL if done else (Style.INK if open else Style.INK_SOFT)
	g.custom_minimum_size = Vector2(56, 56)
	row.add_child(g)
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var al := HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(UI.label(Loc.t(str(i.get("name", ""))), "HeaderLabel" if open else "SoftLabel", al, false))
	var tags: Array = [Loc.t(str(i.get("tagline", "")))]
	if done:
		var badges: Array = []
		if bool(App.data.ledger.nohint.get(id, false)):
			badges.append(Loc.t("ledger_badge_nohint"))
		if bool(App.data.ledger.precision.get(id, false)):
			badges.append(Loc.t("ledger_badge_precision"))
		if not badges.is_empty():
			tags.append(" · ".join(badges))
	elif not open:
		tags.append(Loc.t("ledger_locked_final", [Ledger.FINAL_NEEDS]) if Ledger.group(p) == "final" else Loc.t("ledger_locked_page"))
	col.add_child(UI.label(" — ".join(tags), "SoftLabel", al))
	row.add_child(col)
	var b := UI.button(Loc.t("replay") if done else Loc.t("ledger_open"), func(): App.main.goto("game", {"kind": "ledger", "id": id}),
		"SecondaryButton" if done else "", 80)
	b.custom_minimum_size = Vector2(150, 80)
	b.disabled = not open
	row.add_child(b)
	return UI.card(row, "CardPanel" if open else "SoftPanel")
