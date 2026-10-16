extends Control
## How to play. Reachable from home, gameplay and settings at any time.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("help"), func(): App.main.back()))
	var v := UI.vbox(16)
	root.add_child(UI.scroll(v))
	for k in ["help_goal", "help_tap", "help_badges", "help_priority", "help_bell", "help_counter", "help_auto", "help_fresh", "help_bag", "help_lock", "help_two_stage", "help_lose", "help_undo", "help_hint", "help_stars", "help_tokens", "help_tasks"]:
		var card := UI.vbox(6)
		card.add_child(UI.label(Loc.t(k + "_t"), "HeaderLabel", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT))
		card.add_child(UI.label(Loc.t(k + "_b"), "", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(UI.card(card))
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in Products.COUNT:
		var item := UI.vbox(2)
		var sp := ProductSprite.new(p, 84)
		sp.custom_minimum_size = Vector2(84, 84)
		item.add_child(sp)
		var l := UI.label(Loc.t("p_" + Products.IDS[p]), "SoftLabel")
		l.add_theme_font_size_override("font_size", Style.fs(20))
		item.add_child(l)
		row.add_child(item)
	v.add_child(UI.card(row))
	v.add_child(UI.button(Loc.t("replay_tips"), func():
		App.data.tutorial.done = {}
		App.save_soon()
		App.main.toast(Loc.t("tips_reset")), "SecondaryButton"))
