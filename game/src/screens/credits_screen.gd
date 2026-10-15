extends Control

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("credits"), func(): App.main.back()))
	var v := UI.vbox(14)
	root.add_child(UI.scroll(v))
	for k in ["credits_game", "credits_art", "credits_audio", "credits_fonts", "credits_engine", "credits_plugins"]:
		v.add_child(UI.card(UI.label(Loc.t(k), "", HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT)))
