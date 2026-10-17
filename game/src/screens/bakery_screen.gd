extends Control
## Mira's Bakery (v3 second destination). Reached from Home once the special
## order in p12 has been served. Shows the bakery, its next restoration step,
## décor choices (switching owned choices is free), and its 8 levels.

var screen_mode := "bakery"
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
	root.add_child(UI.header(Loc.t("bakery_title"), func(): App.main.back(), UI.pill("coin", str(App.data.tokens))))
	view = BakeryView.new()
	view.configure_state(Bakery.view_state(App.data))
	var front := Storefront.new(view, true)
	front.custom_minimum_size = Vector2(0, 380)
	root.add_child(front)
	panel = UI.vbox(16)
	root.add_child(UI.scroll(panel))
	_fill()

func _al() -> int:
	return UI.al()

func _fill() -> void:
	for c in panel.get_children():
		c.queue_free()
	var prog := App.progression
	# play
	var nb := prog.next_bakery_index(App.data)
	var all_done := prog.bakery_cleared_count(App.data) >= prog.bakery.size()
	var play := UI.icon_text_button("p_croissant", Loc.t("bakery_play", [nb + 1]) if not all_done else Loc.t("bakery_all_done"),
		func(): App.main.goto("game", {"kind": "bakery", "id": prog.bakery[nb].id}), "WarmButton", 112,
		Loc.t("bakery_levels", [prog.bakery_cleared_count(App.data), prog.bakery.size()]), 44)
	panel.add_child(play)
	# restoration
	var i := Bakery.next_index(App.data)
	if i >= 0:
		var st: Dictionary = Bakery.STEPS[i]
		var card := UI.vbox(12)
		var top := UI.hbox(10)
		var cap := UI.label(Loc.t("step_n_of", [i + 1, Bakery.STEPS.size()]), "CaptionLabel", UI.al(), false)
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(cap)
		card.add_child(top)
		card.add_child(UI.label(Loc.t("bstep_" + str(st.id)), "HeaderLabel", UI.al()))
		card.add_child(UI.label(Loc.t("bstep_desc_" + str(st.id)), "SoftLabel", UI.al()))
		var have := int(App.data.tokens)
		card.add_child(UI.progress_row(mini(have, int(st.cost)), int(st.cost), Style.TERRACOTTA if have >= int(st.cost) else Style.GOLD))
		var b := UI.icon_text_button("coin", Loc.t("restore_cost", [st.cost]), _unlock, "WarmButton")
		b.disabled = not Bakery.can_unlock(App.data)
		card.add_child(b)
		if not Bakery.can_unlock(App.data):
			card.add_child(UI.label(Loc.t("tokens_how", [int(st.cost) - have]), "SoftLabel", UI.al()))
		panel.add_child(UI.card(card))
	else:
		panel.add_child(UI.card(UI.row(UI.medallion("spark", Style.ROSE_SOFT, Style.TERRACOTTA, 64), Loc.t("bakery_complete"), "", null, "HeaderLabel")))
	# décor
	var any := false
	for cat in Bakery.CHOICES:
		if Bakery.steps(App.data) < int(Bakery.CHOICES[cat].step):
			continue
		if not any:
			panel.add_child(UI.section(Loc.t("decor"), "paint", "HeaderLabel", Style.TERRACOTTA))
			any = true
		panel.add_child(UI.label(Loc.t("bcat_" + cat), "StrongLabel", _al()))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		var cur := Bakery.choice(App.data, cat)
		for o in Bakery.CHOICES[cat].options:
			var ob := UI.icon_text_button("check" if o == cur else "", Loc.t("bopt_" + str(o)), func():
				if Bakery.set_choice(App.data, cat, o):
					App.save_soon()
					App.audio.play("place")
					view.configure_state(Bakery.view_state(App.data))
					_fill(), "Button" if o == cur else "SecondaryButton")
			ob.custom_minimum_size = Vector2(190, Style.MIN_TOUCH)
			flow.add_child(ob)
		panel.add_child(flow)
	# levels
	panel.add_child(UI.section(Loc.t("bakery_levels", [prog.bakery_cleared_count(App.data), prog.bakery.size()]), "p_croissant", "HeaderLabel", Style.TERRACOTTA))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for k in prog.bakery.size():
		var id: String = prog.bakery[k].id
		var cleared := Progression.is_cleared(App.data, id)
		var open := k == 0 or cleared or Progression.is_cleared(App.data, prog.bakery[k - 1].id)
		var cell := LevelCell.new()
		cell.number = k + 1
		cell.unlocked = open
		cell.cleared = cleared
		cell.stars = int(App.data.campaign.stars.get(id, 0))
		cell.current = k == nb and not cleared
		cell.mastered = Progression.has_mastery(App.data, id)
		cell.custom_minimum_size = Vector2(0, 116)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.apply_style()
		UI._wire(cell, func():
			if not open:
				App.main.toast(Loc.t("locked_hint_bakery", [k]))
				return
			App.main.goto("game", {"kind": "bakery", "id": id}))
		grid.add_child(cell)
	panel.add_child(grid)
	panel.add_child(UI.spacer(8))

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
