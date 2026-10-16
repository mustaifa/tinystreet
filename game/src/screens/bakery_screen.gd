extends Control
## Mira's Bakery (v3 second destination). Reached from Home once the special
## order in p12 has been served. Shows the bakery, its next restoration step,
## décor choices (switching owned choices is free), and its 8 levels.

var view: BakeryView
var panel: VBoxContainer
var _busy := false

func setup(_p: Dictionary) -> void:
	if not Bakery.is_unlocked(App.data):
		App.main.goto("home", {}, false)
		return
	_build()
	if not Story.seen(App.data, "bakery_open"):
		Story.play.call_deferred("bakery_open")

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("bakery_title"), func(): App.main.back()))
	view = BakeryView.new()
	view.custom_minimum_size = Vector2(0, 440)
	view.configure_state(Bakery.view_state(App.data))
	root.add_child(view)
	panel = UI.vbox(14)
	root.add_child(UI.scroll(panel))
	_fill()

func _al() -> int:
	return HORIZONTAL_ALIGNMENT_LEFT if not Loc.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT

func _fill() -> void:
	for c in panel.get_children():
		c.queue_free()
	var prog := App.progression
	# play
	var nb := prog.next_bakery_index(App.data)
	var all_done := prog.bakery_cleared_count(App.data) >= prog.bakery.size()
	var play := UI.button(Loc.t("bakery_play", [nb + 1]) if not all_done else Loc.t("bakery_all_done"),
		func(): App.main.goto("game", {"kind": "bakery", "id": prog.bakery[nb].id}), "", 104)
	play.add_theme_font_size_override("font_size", Style.fs(34))
	panel.add_child(play)
	# restoration
	var i := Bakery.next_index(App.data)
	var coin := UI.label(Loc.t("tokens_n", [App.data.tokens]), "SoftLabel")
	panel.add_child(coin)
	if i >= 0:
		var st: Dictionary = Bakery.STEPS[i]
		var card := UI.vbox(8)
		card.add_child(UI.label(Loc.t("step_n_of", [i + 1, Bakery.STEPS.size()]), "SoftLabel"))
		card.add_child(UI.label(Loc.t("bstep_" + str(st.id)), "HeaderLabel"))
		card.add_child(UI.label(Loc.t("bstep_desc_" + str(st.id)), "SoftLabel"))
		var b := UI.button(Loc.t("restore_cost", [st.cost]), _unlock, "WarmButton")
		b.disabled = not Bakery.can_unlock(App.data)
		card.add_child(b)
		if not Bakery.can_unlock(App.data):
			card.add_child(UI.label(Loc.t("tokens_how", [int(st.cost) - int(App.data.tokens)]), "SoftLabel"))
		panel.add_child(UI.card(card))
	else:
		panel.add_child(UI.card(UI.label(Loc.t("bakery_complete"), "HeaderLabel")))
	# décor
	for cat in Bakery.CHOICES:
		if Bakery.steps(App.data) < int(Bakery.CHOICES[cat].step):
			continue
		panel.add_child(UI.label(Loc.t("bcat_" + cat), "", _al()))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		var cur := Bakery.choice(App.data, cat)
		for o in Bakery.CHOICES[cat].options:
			var lb := Loc.t("bopt_" + str(o))
			if o == cur:
				lb = "✓ " + lb
			var ob := UI.button(lb, func():
				if Bakery.set_choice(App.data, cat, o):
					App.save_soon()
					App.audio.play("place")
					view.configure_state(Bakery.view_state(App.data))
					_fill(), "" if o == cur else "SecondaryButton")
			ob.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
			flow.add_child(ob)
		panel.add_child(flow)
	# levels
	panel.add_child(UI.label(Loc.t("bakery_levels", [prog.bakery_cleared_count(App.data), prog.bakery.size()]), "HeaderLabel", _al()))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for k in prog.bakery.size():
		var id: String = prog.bakery[k].id
		var cleared := Progression.is_cleared(App.data, id)
		var open := k == 0 or cleared or Progression.is_cleared(App.data, prog.bakery[k - 1].id)
		var lb := UI.button(str(k + 1) + "\n" + (UI.stars_text(int(App.data.campaign.stars.get(id, 0))) if cleared else ("" if open else "·")),
			func(): App.main.goto("game", {"kind": "bakery", "id": id}), "SecondaryButton" if cleared or not open else "", 110)
		lb.disabled = not open
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.add_theme_font_size_override("font_size", Style.fs(26))
		grid.add_child(lb)
	panel.add_child(grid)

func _unlock() -> void:
	if _busy:
		return
	_busy = true
	var id := Bakery.unlock_next(App.data)
	if id == "":
		_busy = false
		return
	App.save_now()
	App.audio.play("restore")
	App.haptic(40)
	App.analytics.event("bakery_step", {"step": id})
	view.configure_state(Bakery.view_state(App.data))
	_fill()
	await get_tree().process_frame
	if is_inside_tree():
		var layer := Control.new()
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		var r := view.get_global_rect()
		Fx.burst(layer, r.get_center() + Vector2(0, -r.size.y * 0.3), "confetti")
		Fx.float_text(layer, r.get_center(), Loc.t("restored"), Style.TERRACOTTA, 48)
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(layer.queue_free)
	_busy = false
