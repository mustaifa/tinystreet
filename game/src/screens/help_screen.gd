extends Control
## How to play. Reachable from home, gameplay and settings at any time. Each
## topic is a card led by the same icon the game uses for that idea.

const TOPICS := [
	["help_goal", "cup"], ["help_tap", "tap"], ["help_badges", "info"], ["help_priority", "levels"],
	["help_bell", "bell"], ["help_counter", "counter"], ["help_auto", "spark"], ["help_fresh", "timer"],
	["help_bag", "help"], ["help_lock", "lock"], ["help_two_stage", "flag"], ["help_lose", "close"],
	["help_undo", "undo"], ["help_hint", "hint"], ["help_stars", "star"], ["help_tokens", "coin"], ["help_tasks", "journal"],
]

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("help"), func(): App.main.back()))
	var v := UI.vbox(14)
	root.add_child(UI.scroll(v))
	# the products, so every item can be named
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for p in Products.COUNT:
		var item := UI.vbox(2)
		var sp := ProductSprite.new(p, 84)
		sp.custom_minimum_size = Vector2(84, 84)
		item.add_child(sp)
		var l := UI.label(Loc.t("p_" + Products.IDS[p]), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
		UI.fit_font(l, 116, Style.T_CAPTION, 16)
		item.add_child(l)
		item.custom_minimum_size = Vector2(118, 0)
		row.add_child(item)
	v.add_child(UI.card(row))
	for t in TOPICS:
		var k: String = t[0]
		var card := UI.row(UI.medallion(t[1], Style.TEAL_SOFT, Style.TEAL_DARK, 64), Loc.t(k + "_t"), Loc.t(k + "_b"), null, "HeaderLabel", "")
		card.alignment = BoxContainer.ALIGNMENT_BEGIN
		(card.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		v.add_child(UI.card(card))
	v.add_child(UI.icon_text_button("restart", Loc.t("replay_tips"), func():
		App.data.tutorial.done = {}
		App.save_soon()
		App.main.toast(Loc.t("tips_reset")), "SecondaryButton"))
