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
	# The engine's own licence and its third-party notices, from the engine
	# itself, so the text always matches the shipped build.
	v.add_child(UI.section(Loc.t("credits_licences"), "info"))
	var lic := UI.label(Engine.get_license_text(), "SoftLabel", UI.al())
	lic.custom_minimum_size = Vector2(560, 0)
	v.add_child(UI.card(lic))
	var parts := Engine.get_copyright_info()
	var names := PackedStringArray()
	for p in parts:
		names.append(str(p.name))
	var used := UI.label(Loc.t("credits_engine_parts", [", ".join(names)]), "SoftLabel", UI.al())
	used.custom_minimum_size = Vector2(560, 0)
	v.add_child(UI.card(used))
