extends Control
## How to play. Reachable from home, gameplay and settings at any time. Each
## topic is a card led by the same icon the game uses for that idea.

## v8: Delivery Logic. (The sorting game's help topics, help_* keys, are
## kept in the string tables with the retired mode.)
const TOPICS := [
	["dl_help_goal", "target"], ["dl_help_move", "tap"], ["dl_help_push", "crate"], ["dl_help_pads", "check"],
	["dl_help_stuck", "lock"], ["dl_help_undo", "undo"], ["dl_help_hint", "hint"], ["dl_help_reward", "coin"],
	["dl_help_keys", "arrow_right"],
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
	for s in DeliveryLevel.SYMBOLS:
		var p: int = DeliveryLevel.SYMBOL_PRODUCT[s]
		var item := UI.vbox(2)
		var sp := ProductSprite.new(p, 84)
		sp.custom_minimum_size = Vector2(84, 84)
		item.add_child(sp)
		var l := UI.label(Loc.t("dl_sym_name_" + DeliveryLevel.SYMBOL_IDS[s]), "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
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
		# v8 lessons: their coach lines show again until each is solved again
		for i in App.delivery.count():
			var id := App.delivery.id_at(i)
			if App.delivery.level(id).meta.get("coach") is Dictionary:
				App.data.tutorial.done["dl_tips:" + id] = true
		App.save_soon()
		App.main.toast(Loc.t("tips_reset")), "SecondaryButton"))
