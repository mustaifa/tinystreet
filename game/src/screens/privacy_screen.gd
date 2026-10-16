extends Control
## In-app privacy & support summary reflecting what THIS build actually does.

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("privacy"), func(): App.main.back()))
	var v := UI.vbox(14)
	root.add_child(UI.scroll(v))
	var ads_kind: String = App.ads.kind()
	var lines := [Loc.t("privacy_local"), Loc.t("privacy_no_account"), Loc.t("privacy_analytics_local")]
	match ads_kind:
		"admob": lines.append(Loc.t("privacy_ads_admob"))
		"simulated": lines.append(Loc.t("privacy_ads_sim"))
		_: lines.append(Loc.t("privacy_ads_none"))
	lines.append(Loc.t("privacy_purchases_" + App.billing.kind()))
	lines.append(Loc.t("privacy_permissions"))
	lines.append(Loc.t("privacy_contact_pending"))
	var icons := ["shield", "heart", "info", "info", "coin", "vibrate", "help"]
	for k in lines.size():
		var r := UI.row(UI.medallion(icons[mini(k, icons.size() - 1)], Style.LINEN, Style.TEAL_DARK, 52), lines[k], "", null, "")
		(r.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		v.add_child(UI.card(r))
	if App.consent.privacy_options_required:
		v.add_child(UI.button(Loc.t("privacy_choices"), func(): App.consent.show_privacy_options()))
