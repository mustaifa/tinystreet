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
	v.position = Vector2(-300, -180)
	v.custom_minimum_size = Vector2(600, 0)
	var m := UI.medallion("cup", Style.TEAL, Color.WHITE, 132)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(m)
	v.add_child(UI.label(Loc.t("game_title"), "DisplayLabel"))
	v.add_child(UI.label(Loc.t("loading"), "SoftLabel"))
	add_child(v)
	await ProductArt.bake(self)
	App.consent.finished.connect(_on_consent, CONNECT_ONE_SHOT)
	App.consent.start()

func _on_consent(can_request_ads: bool) -> void:
	App.ads.initialize(can_request_ads)
	if App.load_notice != "":
		App.main.toast(Loc.t(App.load_notice), 3.5)
	# v8: first launch of Delivery Logic (no puzzle solved or started) goes
	# straight to puzzle 1 after two short lines; everyone else lands home.
	var first_time: bool = App.delivery.count() > 0 and App.delivery.cleared_count(App.data) == 0 \
		and DeliveryProgress.current_id(App.data) == "" and not Story.seen(App.data, "dl_intro")
	App.main.goto("home", {}, false)
	if first_time:
		Story.play("dl_intro", func(): App.main.goto("puzzle", {"id": App.delivery.id_at(0)}))
