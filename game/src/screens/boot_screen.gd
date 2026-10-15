extends Control
## Boot: load save + levels, run consent if an ad SDK is present, then go
## straight to play for first-time players (no account, no long intro).

func setup(_p: Dictionary) -> void:
	var save_path := "user://save.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save-path="):
			save_path = a.split("=")[1]
	if App.store == null:
		App.boot(save_path)
	var v := UI.vbox(18)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-300, -120)
	v.custom_minimum_size = Vector2(600, 0)
	v.add_child(UI.label(Loc.t("game_title"), "TitleLabel"))
	v.add_child(UI.label(Loc.t("loading"), "SoftLabel"))
	add_child(v)
	await ProductArt.bake(self)
	App.consent.finished.connect(_on_consent, CONNECT_ONE_SHOT)
	App.consent.start()

func _on_consent(can_request_ads: bool) -> void:
	App.ads.initialize(can_request_ads)
	if App.load_notice != "":
		App.main.toast(Loc.t(App.load_notice), 3.5)
	var first_time: bool = not Progression.is_cleared(App.data, App.progression.campaign[0].id) \
		and App.data.current.is_empty()
	if first_time:
		App.main.goto("home", {}, false)
		App.main.goto("game", {"kind": "campaign", "id": App.progression.campaign[0].id})
	else:
		App.main.goto("home", {}, false)
