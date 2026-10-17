extends Control
## Credits and licences: who made what, and the open-source licences used.

const ITEMS := [["credits_game", "heart"], ["credits_art", "brush"], ["credits_audio", "music"],
	["credits_fonts", "text"], ["credits_engine", "gear"], ["credits_plugins", "info"]]

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("credits"), func(): App.main.back()))
	var v := UI.vbox(14)
	root.add_child(UI.scroll(v))
	for it in ITEMS:
		var r := UI.row(UI.medallion(it[1], Style.LINEN, Style.TEAL_DARK, 56), Loc.t(it[0]), "", null, "")
		(r.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		v.add_child(UI.card(r))
